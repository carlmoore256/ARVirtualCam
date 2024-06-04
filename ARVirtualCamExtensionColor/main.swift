//
//  main.swift
//  ARVirtualCamExtensionColor
//
//  Created by Carl Moore on 6/4/24.
//

import Foundation
import CoreMediaIO

let providerSource = CameraProviderSource(cameraName: colorCameraName, clientQueue: nil)
CMIOExtensionProvider.startService(provider: providerSource.provider)

CFRunLoopRun()
