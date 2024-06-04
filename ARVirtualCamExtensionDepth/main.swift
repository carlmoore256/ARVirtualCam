//
//  main.swift
//  ARVirtualCamExtension
//
//  Created by Carl Moore on 5/24/24.
//

import Foundation
import CoreMediaIO
import os.log

let providerSource = CameraProviderSource(cameraName: depthCameraName, clientQueue: nil)
CMIOExtensionProvider.startService(provider: providerSource.provider)

CFRunLoopRun()
