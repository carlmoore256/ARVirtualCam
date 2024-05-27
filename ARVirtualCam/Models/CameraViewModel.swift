//
//  CameraViewModel.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/25/24.
//

import Foundation
import Combine

class CameraViewModel: ObservableObject {
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
