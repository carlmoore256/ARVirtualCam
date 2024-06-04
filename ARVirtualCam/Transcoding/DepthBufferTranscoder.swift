//
//  DepthBufferTranscoder.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 6/3/24.
//
import Foundation
import VideoToolbox
import Accelerate
import CoreVideo

protocol PixelBufferTranscoder {
    var inputPixelFormat: OSType { get }
    var outputPixelFormat: OSType { get }
    var cachedBuffer: CachedPixelBuffer { get }
    func transcode(_ inputBuffer: CVPixelBuffer) -> CVPixelBuffer?
}

protocol PixelBufferTransform {
    func apply(inputBuffer: CVPixelBuffer, destBuffer: CVPixelBuffer) -> Bool
}

class DepthBufferTranscoder : PixelBufferTranscoder, ObservableObject {
    var inputPixelFormat: OSType = kCVPixelFormatType_DepthFloat16
    var outputPixelFormat: OSType = kCVPixelFormatType_32BGRA
    let cachedBuffer: CachedPixelBuffer
    let transform: PixelBufferTransform
    
    init(width: Int, height: Int, transform: PixelBufferTransform) {
        self.cachedBuffer = CachedPixelBuffer(width: width, height: height, formatType: self.outputPixelFormat)
        self.transform = transform
    }
    
    func transcode(_ inputBuffer: CVPixelBuffer ) -> CVPixelBuffer? {
        guard let destBuffer = self.cachedBuffer.buffer else {
            print("Destination buffer is nil!")
            return nil
        }
        let res = self.transform.apply(inputBuffer: inputBuffer, destBuffer: destBuffer)
        if res == false {
            print("Failed to apply transform in depth buffer transcoder!")
        }
        return destBuffer
    }
}

class Truncate16Bit : PixelBufferTransform, ObservableObject {
    @Published var rangeMin: Float
    @Published var rangeMax: Float
    
    init(rangeMin: Float, rangeMax: Float) {
        self.rangeMin = rangeMin
        self.rangeMax = rangeMax
    }
    
    func apply(inputBuffer: CVPixelBuffer, destBuffer: CVPixelBuffer) -> Bool {
        CVPixelBufferLockBaseAddress(inputBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(inputBuffer, .readOnly) }
        CVPixelBufferLockBaseAddress(destBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(destBuffer, []) }
        guard let inputPointer = inputBuffer.pointer?.assumingMemoryBound(to: Float16.self),
              let outputPointer = destBuffer.pointer?.assumingMemoryBound(to: UInt8.self)
        else {
            return false
        }
        
        // prevent value from changing in the middle of calculating buffer
        let _rangeMin = self.rangeMin
        let _rangeMax = self.rangeMax
        
        let buffLength = inputBuffer.length
        for i in 0..<buffLength {
            var depth = (Float(inputPointer[i]) - _rangeMin) / (_rangeMax - _rangeMin)
            depth = depth.clamped(to: 0...1)
            let grayValue = UInt8(depth * 255.0)
            outputPointer[i * 4] = grayValue
            outputPointer[i * 4 + 1] = grayValue
            outputPointer[i * 4 + 2] = grayValue
            outputPointer[i * 4 + 3] = grayValue
        }
        return true
    }
}
