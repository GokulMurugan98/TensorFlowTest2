//
//  HostedViewController.swift
//  CameraTestApp
//
//  Created by Gokul Murugan on 19/02/24.
//

import UIKit
import SwiftUI
import AVFoundation

class ViewController:UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject{
    
    var viewModel: ViewModel?
    private var permissionGranted = false
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    
    private var previewLayer = AVCaptureVideoPreviewLayer()
    var screenRect:CGRect! = nil

    private let delayBetweenInferencesMs = 3000.0
    
    private let inferenceQueue = DispatchQueue(label: "org.tensorflow.lite.inferencequeue")
    private var previousInferenceTimeMs = Date.distantPast.timeIntervalSince1970 * 3000
    private var isInferenceQueueBusy = false
    private var threadCount = DefaultConstants.threadCount
    private var scoreThreshold = DefaultConstants.scoreThreshold
    private var model: ModelType = .efficientnetLite0

    
    private var imageClassificationHelper: ImageClassificationHelper? =
      ImageClassificationHelper(
        modelFileInfo: DefaultConstants.model.modelFileInfo,
        threadCount: DefaultConstants.threadCount,
        resultCount: DefaultConstants.maxResults,
        scoreThreshold: DefaultConstants.scoreThreshold)
    // Detector
       private var videoOutput = AVCaptureVideoDataOutput()
       var detectionLayer: CALayer! = nil
    
    override func viewDidLoad() {
        checkPermission()
        sessionQueue.async {
            guard self.permissionGranted else {return}
            self.setupCaptureSession()
            self.captureSession.startRunning()
        }
    }
    
    func requestPermission() {
           sessionQueue.suspend()
           AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
               self.permissionGranted = granted
               self.sessionQueue.resume()
           }
       }
       
    func setupCaptureSession() {
            // Camera input
            guard let videoDevice = AVCaptureDevice.default(.builtInDualWideCamera,for: .video, position: .back) else { return }
            guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
               
            guard captureSession.canAddInput(videoDeviceInput) else { return }
            captureSession.addInput(videoDeviceInput)
                             
            // Preview layer
            screenRect = UIScreen.main.bounds
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
            previewLayer.connection?.videoOrientation = .portrait
            
            // Detector
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferQueue"))
            captureSession.addOutput(videoOutput)
            
            videoOutput.connection(with: .video)?.videoOrientation = .portrait
            // Updates to UI must be on main queue
            DispatchQueue.main.async { [weak self] in
                self!.view.layer.addSublayer(self!.previewLayer)
            }
        }
    
    func checkPermission(){
        switch AVCaptureDevice.authorizationStatus(for: .video){
        case .authorized:
            permissionGranted = true
            
        case .notDetermined:
            requestPermission()
            
        default :
            permissionGranted = false
            
        }
    }
    
    func stopSession() {
        captureSession.stopRunning()
    }
}

extension ViewController {
    
    func convertTo32BGRA(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        var newPixelBuffer: CVPixelBuffer?
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         CVPixelBufferGetWidth(pixelBuffer),
                                         CVPixelBufferGetHeight(pixelBuffer),
                                         kCVPixelFormatType_32BGRA,
                                         options as CFDictionary,
                                         &newPixelBuffer)

        guard status == kCVReturnSuccess, let unwrappedNewPixelBuffer = newPixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(unwrappedNewPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let newBaseAddress = CVPixelBufferGetBaseAddress(unwrappedNewPixelBuffer)

        memcpy(newBaseAddress, baseAddress, CVPixelBufferGetDataSize(pixelBuffer))

        CVPixelBufferLockBaseAddress(unwrappedNewPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)


        return unwrappedNewPixelBuffer
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let unConvertedBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let pixelBuffer = convertTo32BGRA(pixelBuffer: unConvertedBuffer) else {return}
        let currentTimeMs = Date().timeIntervalSince1970 * 1000
        guard (currentTimeMs - previousInferenceTimeMs) >= delayBetweenInferencesMs else { return }
        previousInferenceTimeMs = currentTimeMs
        
        // Drop this frame if the model is still busy classifying a previous frame.
        guard !isInferenceQueueBusy else { return }
        
        inferenceQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.isInferenceQueueBusy = true
            
            
            // Pass the pixel buffer to TensorFlow Lite to perform inference.
            let result = self.imageClassificationHelper?.classify(frame: pixelBuffer)
            
            self.isInferenceQueueBusy = false
            
            // Display results by handing off to the InferenceViewController.
            DispatchQueue.main.async {
                _ = CGSize(
                    width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
                self.viewModel?.result = result
                print(result?.classifications.categories.first?.label)
            }
        }
    }
}


struct HostedViewController: UIViewControllerRepresentable {
    @ObservedObject var viewModel:ViewModel
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = ViewController()
        viewController.viewModel = viewModel
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if viewModel.stopSession{
            let viewController = ViewController()
            viewController.stopSession()
        }
    }
}


enum DefaultConstants {
  static let threadCount = 4
  static let maxResults = 5
  static let scoreThreshold: Float = 0.1
  static let model: ModelType = .efficientnetLite1
}

/// TFLite model types
enum ModelType: CaseIterable {
  case efficientnetLite0
  case efficientnetLite1
  case efficientnetLite2
  case efficientnetLite3
  case efficientnetLite4

  var modelFileInfo: FileInfo {
    switch self {
    case .efficientnetLite0:
      return FileInfo("efficientnet_lite0", "tflite")
    case .efficientnetLite1:
      return FileInfo("efficientnet_lite1", "tflite")
    case .efficientnetLite2:
      return FileInfo("efficientnet_lite2", "tflite")
    case .efficientnetLite3:
      return FileInfo("efficientnet_lite3", "tflite")
    case .efficientnetLite4:
      return FileInfo("efficientnet_lite4", "tflite")
    }
  }

  var title: String {
    switch self {
    case .efficientnetLite0:
      return "EfficientNet-Lite0"
    case .efficientnetLite1:
      return "EfficientNet-Lite1"
    case .efficientnetLite2:
      return "EfficientNet-Lite2"
    case .efficientnetLite3:
      return "EfficientNet-Lite3"
    case .efficientnetLite4:
      return "EfficientNet-Lite4"
    }
  }
}
