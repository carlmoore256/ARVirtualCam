//
//  CameraProvierSource.swift
//  ARVirtualCamExtension
//
//  Created by Carl Moore on 5/25/24.
//

import Foundation
import CoreMediaIO
import os.log

class CameraProviderSource: NSObject, CMIOExtensionProviderSource {
    
    private(set) var provider: CMIOExtensionProvider!
    
    private var deviceSource: CameraDeviceSource!
    
    init(clientQueue: DispatchQueue?) {
        super.init()
        provider = CMIOExtensionProvider(source: self, clientQueue: clientQueue)
        deviceSource = CameraDeviceSource(localizedName: cameraName)
        
        do {
            try provider.addDevice(deviceSource.device)
        } catch let error {
            fatalError("Failed to add device: \(error.localizedDescription)")
        }
    }
    
    func connect(to client: CMIOExtensionClient) throws {
        
    }
    
    func disconnect(from client: CMIOExtensionClient) {
        
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        
        // See full list of CMIOExtensionProperty choices in CMIOExtensionProperties.h
        return [.providerManufacturer]
    }
    
    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        
        let providerProperties = CMIOExtensionProviderProperties(dictionary: [:])
        if properties.contains(.providerManufacturer) {
            providerProperties.manufacturer = "Sample Camera Manufacturer"
        }
        return providerProperties
    }
    
    func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {
        // Handle settable properties here.
    }
}
