//
//  FrameHandler.swift
//  CameraTestApp
//
//  Created by Gokul Murugan on 19/02/24.
//

import SwiftUI
import AVFoundation
import CoreImage

class FrameHandler:NSObject,ObservableObject{
    @Published var frame:CGImage?
    private var permissionGranted:Bool = false
    private var captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private let context = CIContext()
    
    override init() {
        super.init()
        checkPermission()
        sessionQueue.async { [unowned self] in
            self.setupCaptureSession()
            self.captureSession.startRunning()
        }
    }
    
    func checkPermission(){
        switch AVCaptureDevice.authorizationStatus(for: .video){
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
            
        default:
            permissionGranted = false
        }
    }
    
    
    func requestPermission(){
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
        }
    }
    
    func setupCaptureSession() {
        let videOutput = AVCaptureVideoDataOutput()
        guard permissionGranted else {return}
        guard let videDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)  else {return}
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videDevice) else {return}
        guard captureSession.canAddInput(videoDeviceInput) else {return}
        captureSession.addInput(videoDeviceInput)
        
        videOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferQueue"))
        captureSession.addOutput(videOutput)
        videOutput.connection(with: .video)?.videoOrientation = .portrait
    }
    
}

extension FrameHandler:AVCaptureVideoDataOutputSampleBufferDelegate{
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let image = imageFromSampleBufferImage(sampleBuffer:sampleBuffer) else {return}
        
        DispatchQueue.main.async {
            self.frame = image
        }
    }
    
    func imageFromSampleBufferImage(sampleBuffer:CMSampleBuffer) -> CGImage?{
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return nil}
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let CGImage = context.createCGImage(ciImage, from: ciImage.extent) else {return nil}
        return CGImage
    }
    
}
