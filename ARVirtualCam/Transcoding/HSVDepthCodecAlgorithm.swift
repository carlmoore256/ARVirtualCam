//
//  HSLDepthCodecAlgorithm.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 6/2/24.
//

import Foundation
import CoreVideo
import Accelerate

class HSVDepthCodecAlgorithm : PixelBufferCodecAlgorithm, ObservableObject {
    
    var minDepth: Float16 = 0.0
    var maxDepth: Float16 = 6.0 // camera rated to ~5 meters
    @Published var depthScalar = 1.0
    
    init(minDepth: Float16 = 0.0, maxDepth: Float16 = 6.0) {
        self.minDepth = minDepth
        self.maxDepth = maxDepth
    }
    
    func encode(inputBuffer: CVPixelBuffer, outputBuffer: CVPixelBuffer) -> Bool {
        CVPixelBufferLockBaseAddress(inputBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(inputBuffer, .readOnly) }
        CVPixelBufferLockBaseAddress(outputBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(outputBuffer, []) }
        let buffLength = inputBuffer.length
        guard let inputPointer = inputBuffer.pointer?.assumingMemoryBound(to: Float16.self),
              let outputPointer = outputBuffer.pointer?.assumingMemoryBound(to: UInt8.self)
        else {
            return false
        }
        for i in 0..<buffLength {
            var depth = inputPointer[i]
            if depth.isNaN || depth.isInfinite {
                depth = 0
            }
            if depth > maxDepth {
                depth = minDepth
            }
            if depth < minDepth {
                depth = minDepth
            }
            let normalizedDepth = (depth - minDepth) / (maxDepth - minDepth)
            let encoded = ColorUtils.HSVtoRGB(h: normalizedDepth * 360, s: 1.0, v: 1.0)
            outputPointer[i * 4] = encoded.b
            outputPointer[i * 4 + 1] = encoded.g
            outputPointer[i * 4 + 2] = encoded.r
            outputPointer[i * 4 + 3] = 255
        }
        return true
    }
  
    
    func decode(inputBuffer: CVPixelBuffer, outputBuffer: CVPixelBuffer) -> Bool {
        return true
    }
}
