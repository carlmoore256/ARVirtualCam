//
//  CameraProvider.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/25/24.
//

import Foundation
import AVFoundation
import Cocoa
import CoreMediaIO
import SystemExtensions

class CameraProvider {
    
    // get Core Media IO device by a device name, such as "Sample Camera"
    static func getCMIODevice(name: String) -> AVCaptureDevice? {
        print("getDevice name=",name)
        var devices: [AVCaptureDevice]?
        if #available(macOS 10.15, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.external],
                                                                    mediaType: .video,
                                                                    position: .unspecified)
            devices = discoverySession.devices
        } else {
            // Fallback on earlier versions
            devices = AVCaptureDevice.devices(for: .video)
        }
        guard let devices = devices else { return nil }
        return devices.first { $0.localizedName == name}
    }
    
    // get the object id for the CoreMediaIO device
    static func getCMIODeviceObjectId(deviceUniqueId: String) -> CMIOObjectID? {
        var dataSize: UInt32 = 0
        var devices = [CMIOObjectID]()
        var dataUsed: UInt32 = 0
        var opa = CMIOObjectPropertyAddress(CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices), .global, .main)
        CMIOObjectGetPropertyDataSize(CMIOObjectPropertySelector(kCMIOObjectSystemObject), &opa, 0, nil, &dataSize);
        let nDevices = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        devices = [CMIOObjectID](repeating: 0, count: Int(nDevices))
        CMIOObjectGetPropertyData(CMIOObjectPropertySelector(kCMIOObjectSystemObject), &opa, 0, nil, dataSize, &dataUsed, &devices);
        for deviceObjectID in devices {
            opa.mSelector = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceUID)
            CMIOObjectGetPropertyDataSize(deviceObjectID, &opa, 0, nil, &dataSize)
            var name: CFString = "" as NSString
            //CMIOObjectGetPropertyData(deviceObjectID, &opa, 0, nil, UInt32(MemoryLayout<CFString>.size), &dataSize, &name);
            CMIOObjectGetPropertyData(deviceObjectID, &opa, 0, nil, dataSize, &dataUsed, &name);
            if String(name) == deviceUniqueId {
                return deviceObjectID
            }
        }
        return nil
    }
    
    // get the input streams for a CoreMediaIO deviceId, these are streams that it will accept
    static func getInputStreams(deviceId: CMIODeviceID) -> [CMIOStreamID]
    {
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        var opa = CMIOObjectPropertyAddress(CMIOObjectPropertySelector(kCMIODevicePropertyStreams), .global, .main)
        CMIOObjectGetPropertyDataSize(deviceId, &opa, 0, nil, &dataSize);
        let numberStreams = Int(dataSize) / MemoryLayout<CMIOStreamID>.size
        var streamIds = [CMIOStreamID](repeating: 0, count: numberStreams)
        CMIOObjectGetPropertyData(deviceId, &opa, 0, nil, dataSize, &dataUsed, &streamIds)
        return streamIds
    }
}
