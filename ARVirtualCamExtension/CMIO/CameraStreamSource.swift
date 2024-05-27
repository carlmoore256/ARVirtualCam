//
//  CameraStreamSource.swift
//  ARVirtualCamExtension
//
//  Created by Carl Moore on 5/25/24.
//

import Foundation
import CoreMediaIO
import os.log

class CameraStreamSource: NSObject, CMIOExtensionStreamSource {
    
    private(set) var stream: CMIOExtensionStream!
    
    let device: CMIOExtensionDevice
    //public var nConnectedClients = 0
    private let _streamFormat: CMIOExtensionStreamFormat
    
    init(localizedName: String, streamID: UUID, streamFormat: CMIOExtensionStreamFormat, device: CMIOExtensionDevice) {
        
        self.device = device
        self._streamFormat = streamFormat
        super.init()
        self.stream = CMIOExtensionStream(localizedName: localizedName, streamID: streamID, direction: .source, clockType: .hostTime, source: self)
    }
    
    var formats: [CMIOExtensionStreamFormat] {
        
        return [_streamFormat]
    }
    
    var activeFormatIndex: Int = 0 {
        
        didSet {
            if activeFormatIndex >= 1 {
                os_log(.error, "Invalid index")
            }
        }
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        
        return [.streamActiveFormatIndex, .streamFrameDuration, CMIOExtensionPropertyCustomPropertyData_just]
    }
    
    public var just: String = "toto"
    public var rust: String = "0"
    var count = 0
    
    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        let streamProperties = CMIOExtensionStreamProperties(dictionary: [:])
        if properties.contains(.streamActiveFormatIndex) {
            streamProperties.activeFormatIndex = 0
        }
        if properties.contains(.streamFrameDuration) {
            let frameDuration = CMTime(value: 1, timescale: Int32(kFrameRate))
            streamProperties.frameDuration = frameDuration
        }
        if properties.contains(CMIOExtensionPropertyCustomPropertyData_just) {
            streamProperties.setPropertyState(CMIOExtensionPropertyState(value: self.just as NSString), forProperty: CMIOExtensionPropertyCustomPropertyData_just)
            
        }
        return streamProperties
    }
    
    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        
        if let activeFormatIndex = streamProperties.activeFormatIndex {
            self.activeFormatIndex = activeFormatIndex
        }
        
        if let state = streamProperties.propertiesDictionary[CMIOExtensionPropertyCustomPropertyData_just] {
            if let newValue = state.value as? String {
                self.just = newValue
                if let deviceSource = device.source as? CameraDeviceSource {
                    self.just = deviceSource.myStreamingCounter()
                }
            }
        }
    }
    
    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
        
        // An opportunity to inspect the client info and decide if it should be allowed to start the stream.
        return true
    }
    
    func startStream() throws {
        
        guard let deviceSource = device.source as? CameraDeviceSource else {
            fatalError("Unexpected source type \(String(describing: device.source))")
        }
        self.rust = "1"
        deviceSource.startStreaming()
    }
    
    func stopStream() throws {
        
        guard let deviceSource = device.source as? CameraDeviceSource else {
            fatalError("Unexpected source type \(String(describing: device.source))")
        }
        self.rust = "0"
        deviceSource.stopStreaming()
    }
}
