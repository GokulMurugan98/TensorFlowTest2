//
//  ViewModel.swift
//  CameraTestApp
//
//  Created by Gokul Murugan on 19/02/24.
//

import Foundation

class ViewModel:ObservableObject{
    @Published var result:ImageClassificationResult?
    @Published var stopSession:Bool = false
    
}
