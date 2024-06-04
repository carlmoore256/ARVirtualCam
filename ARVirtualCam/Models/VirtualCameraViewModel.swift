//
//  CameraViewModel.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/25/24.
//

import Foundation
import Combine
import CoreMediaIO

enum DepthEncodingMethod {
    case hsv, rgb, grayscale
}

// stateful model for the virtual camera
class VirtualCameraViewModel: ObservableObject {
    @Published var debugMessage: String = ""
    @Published var mirrorCamera: Bool = true {
        didSet {
            virtualCamera.mirrorCamera = mirrorCamera
        }
    }
    @Published var needToStream: Bool = false {
        didSet {
            virtualCamera.needToStream = needToStream
        }
    }
    
    @Published var depthEncodingMethod: DepthEncodingMethod = .hsv
    
    private var virtualCamera = CMIOVirutalCameraSource(width: fixedCamWidth, height: fixedCamHeight, pixelFormat: kCVPixelFormatType_32BGRA)
    private var timer: Timer?
    private var propTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var virtualCameraBuffer: CVPixelBuffer?

    
    init() {
        registerForDeviceNotifications()
        print("made devices visible and attempted to connect to camera")
        
        timer = Timer.scheduledTimer(withTimeInterval: 1/30.0, repeats: true) { [weak self] _ in
            self?.fireTimer()
        }
        
        propTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.propertyTimer()
        }
        
        $mirrorCamera.sink { [weak self] value in
            self?.virtualCamera.mirrorCamera = value
        }.store(in: &cancellables)
        
        $needToStream.sink { [weak self] value in
            self?.virtualCamera.needToStream = value
        }.store(in: &cancellables)
    }
    
    func sendPixelBuffer(pixelBuffer: CVPixelBuffer) {
        self.virtualCamera.setPixelBuffer(newPixelBuffer: pixelBuffer)
        virtualCamera.fireTimer()
    }
    
    private func registerForDeviceNotifications() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasConnected, object: nil, queue: nil) { [weak self] (notif) in
            if self?.virtualCamera.sourceStream == nil {
                self?.virtualCamera.connectToCamera()
            }
        }
    }
    
    private func fireTimer() {
        // Call the handler's fireTimer method
        // virtualCamera.fireTimer()
    }
    
    private func propertyTimer() {
        // Call the handler's propertyTimer method
        virtualCamera.propertyTimer()
    }
    
    func showMessage(_ text: String) {
        debugMessage += "\(text)\n"
    }
}
