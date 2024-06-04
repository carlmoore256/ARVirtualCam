//
//  EncodeDepth.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/31/24.
//

import Foundation
import VideoToolbox
import Accelerate
import CoreVideo




protocol PixelBufferCodecAlgorithm {
    // kCVPixelFormatType_DepthFloat16 -> kCVPixelFormatType_32BGRA
    func encode(inputBuffer: CVPixelBuffer, outputBuffer: CVPixelBuffer) -> Bool
    // kCVPixelFormatType_32BGRA -> kCVPixelFormatType_DepthFloat16
    func decode(inputBuffer: CVPixelBuffer, outputBuffer: CVPixelBuffer) -> Bool
}

// sole purpose is to encode double values into RGBA 8-bit
// takes a 16bit pixel buffer, kCVPixelFormatType_DepthFloat16, and outputs it as kCVPixelFormatType_32BGRA
class DepthDataCodec {
    
    var cachedEncodeBuff: CVPixelBuffer?
    var cachedDecodeBuff: CVPixelBuffer?
    var algorithm: PixelBufferCodecAlgorithm
    
    init(algorithm: PixelBufferCodecAlgorithm) {
        self.algorithm = algorithm
    }
    
    func create8BitRBGABuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let pixelBufferAttributes: NSDictionary = [
            kCVPixelBufferWidthKey: Int32(width),
            kCVPixelBufferHeightKey: Int32(height),
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, pixelBufferAttributes as CFDictionary, &pixelBuffer)
        return status == kCVReturnSuccess ? pixelBuffer : nil
    }
    
    func create16BitDepthBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let pixelBufferAttributes: NSDictionary = [
            kCVPixelBufferWidthKey: Int32(width),
            kCVPixelBufferHeightKey: Int32(height),
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_DepthFloat16,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_DepthFloat16, pixelBufferAttributes as CFDictionary, &pixelBuffer)
        return status == kCVReturnSuccess ? pixelBuffer : nil
    }
    
    func getCachedEncodeBuff(reference buffer16Bit: CVPixelBuffer) -> CVPixelBuffer? {
        if buffer16Bit.type != kCVPixelFormatType_DepthFloat16 {
            print("Error - buffer input is incorrect type \(buffer16Bit.type) | expected \(kCVPixelFormatType_DepthFloat16)")
            return nil
        }
        
        let width = buffer16Bit.width
        let height = buffer16Bit.height
        
        if cachedEncodeBuff == nil {
            cachedEncodeBuff = self.create8BitRBGABuffer(width: width, height: height)
        } else if cachedEncodeBuff?.width != width || cachedEncodeBuff?.height != height {
            print("Rebuilding cached encode buff because it received a different size! If this is happening frequently, something is wrong")
            cachedEncodeBuff = self.create8BitRBGABuffer(width: width, height: height)
        }
        return cachedEncodeBuff
    }
    
    func getCachedDecodeBuff(reference buffer8Bit: CVPixelBuffer) -> CVPixelBuffer? {
        if buffer8Bit.type != kCVPixelFormatType_32BGRA {
            print("Error - buffer input is incorrect type \(buffer8Bit.type) | expected \(kCVPixelFormatType_32BGRA)")
            return nil
        }
        let width = buffer8Bit.width
        let height = buffer8Bit.height
        
        if cachedDecodeBuff == nil {
            cachedDecodeBuff = self.create16BitDepthBuffer(width: width, height: height)
        } else if cachedDecodeBuff?.width != width || cachedDecodeBuff?.height != height {
            print("Rebuilding cached decode buff because it received a different size! If this is happening frequently, something is wrong")
            cachedDecodeBuff = self.create16BitDepthBuffer(width: width, height: height)
        }
        return cachedDecodeBuff
    }
    
    func encode(buffer16Bit: CVPixelBuffer) -> CVPixelBuffer? {
        guard let outputBuff = getCachedEncodeBuff(reference: buffer16Bit) else {
            return nil
        }
        let success = self.algorithm.encode(inputBuffer: buffer16Bit, outputBuffer: outputBuff)
        if !success {
            print("Error encoding buffer with algorithm \(self.algorithm)")
        }
        return outputBuff
    }
    
    func decode(buffer8Bit: CVPixelBuffer) -> CVPixelBuffer? {
        guard let outputBuff = getCachedDecodeBuff(reference: buffer8Bit) else {
            return nil
        }
        let success = self.algorithm.decode(inputBuffer: buffer8Bit, outputBuffer: outputBuff)
        if !success {
            print("Error decoding buffer with algorithm \(self.algorithm)")
        }
        return outputBuff
    }
    
    
}
