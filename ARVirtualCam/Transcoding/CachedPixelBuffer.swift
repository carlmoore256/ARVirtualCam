//
//  CachedPixelBuffer.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 6/3/24.
//

import Foundation
import CoreVideo

class CachedPixelBuffer {
    var buffer: CVPixelBuffer?
    let bufferAttributes: NSDictionary
    let formatType: OSType
    let width: Int
    let height: Int
    
    init(width: Int, height: Int, formatType: OSType = kCVPixelFormatType_32BGRA) {
        self.bufferAttributes = [
            kCVPixelBufferWidthKey: Int32(width),
            kCVPixelBufferHeightKey: Int32(height),
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        self.formatType = formatType
        self.width = width
        self.height = height
        self.allocateBuffer()
    }
    
    func allocateBuffer() {
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, self.formatType, self.bufferAttributes as CFDictionary, &self.buffer)
        if status != kCVReturnSuccess {
            print("Error allocating buffer!")
        }
    }
}
