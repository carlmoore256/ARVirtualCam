//
//  CameraViewModel.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/25/24.
//

import Foundation
import Combine
import CoreMediaIO

class VirtualCameraPluginViewModel: ObservableObject {
    @Published var debugMessage: String = ""
    @Published var mirrorCamera: Bool = true {
        didSet {
            cmioHandler.mirrorCamera = mirrorCamera
        }
    }
    @Published var needToStream: Bool = false {
        didSet {
            cmioHandler.needToStream = needToStream
        }
    }
    
    private var cmioHandler = CMIOSourceHandler()
    private var timer: Timer?
    private var propTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var depthBuffer8Bit: CVPixelBuffer?
    
    init() {
        registerForDeviceNotifications()
        cmioHandler.makeDevicesVisible()
        cmioHandler.connectToCamera()
        print("made devices visible and attempted to connect to camera")
        
        timer = Timer.scheduledTimer(withTimeInterval: 1/30.0, repeats: true) { [weak self] _ in
            self?.fireTimer()
        }
        
        propTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.propertyTimer()
        }
        
        $mirrorCamera.sink { [weak self] value in
            self?.cmioHandler.mirrorCamera = value
        }.store(in: &cancellables)
        
        $needToStream.sink { [weak self] value in
            self?.cmioHandler.needToStream = value
        }.store(in: &cancellables)
    }
    
    func activateCamera() {
        //        cmioHandler.activateCamera()
    }
    
    func deactivateCamera() {
        //        cmioHandler.deactivateCamera()
    }
    
    func sendDepthPixelBuffer(pixelBuffer: CVPixelBuffer) {
        if self.depthBuffer8Bit == nil {
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            self.depthBuffer8Bit = create8Bit3ChannelPixelBuffer(width: width, height: height)
        }
        guard let depthBuffer8Bit = self.depthBuffer8Bit else {
            print("8 bit buffer is not initialized!")
            return
        }
        
//        let success = convert32BitTo8Bit3Channel(pixelBuffer: pixelBuffer, outputPixelBuffer: depthBuffer8Bit, min: 0.0, max: 6.0)
        let success = convertDepthBufferToHSV(pixelBuffer: pixelBuffer, outputPixelBuffer: depthBuffer8Bit, minDepth: 0.0, maxDepth: 8.0)
        
        if !success {
            print("Error converting 32Bit data to 8 bit")
            return
        }
        self.cmioHandler.setPixelBuffer(newPixelBuffer: depthBuffer8Bit)
    }
    
    private func registerForDeviceNotifications() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasConnected, object: nil, queue: nil) { [weak self] (notif) in
            if self?.cmioHandler.sourceStream == nil {
                self?.cmioHandler.connectToCamera()
            }
        }
    }
    
    func connectToCamera() {
        self.cmioHandler.connectToCamera()
    }
    
    private func fireTimer() {
        // Call the handler's fireTimer method
        cmioHandler.fireTimer()
    }
    
    private func propertyTimer() {
        // Call the handler's propertyTimer method
        cmioHandler.propertyTimer()
    }
    
    func showMessage(_ text: String) {
        debugMessage += "\(text)\n"
    }
}
