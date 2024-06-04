//
//  OverflowDepthCodecAlgorithm.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/31/24.
//

import Foundation
import CoreVideo
import Accelerate

class LogDepthCodecAlgorithm : PixelBufferCodecAlgorithm, ObservableObject  {
    
    var minDepth: Float16 = 0.0
    var maxDepth: Float16 = 6.0 // camera rated to ~5 meters
    
    private var maxBound: Float16 = 65504.0
    private let toFixed: Float = 255.0 / 256.0
    private let fromFixed: Float = 256.0 / 255.0
    
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
            let encoded = encodeDepthToRGBLogarithmic(value: normalizedDepth)
            outputPointer[i * 4] = encoded.b
            outputPointer[i * 4 + 1] = encoded.g
            outputPointer[i * 4 + 2] = encoded.r
            outputPointer[i * 4 + 3] = 255
        }
        
        return true
    }
    
    func encodeDepthToRGBLogarithmic(value: Float16) -> (r: UInt8, g: UInt8, b: UInt8) {
        // Normalize depth to range [0, 1]

        // Apply logarithmic transformation
        let logDepth = log2(Double(value) + 1.0) / log2(2.0)

        // Convert to range [0, 16777215] for 24-bit depth (3 x 8 bits)
        let depth24 = UInt32(logDepth * 16777215.0)

        // Split the 24-bit depth into three 8-bit values
        let r = UInt8((depth24 >> 16) & 0xFF) // Most significant 8 bits
        let g = UInt8((depth24 >> 8) & 0xFF)  // Middle 8 bits
        let b = UInt8(depth24 & 0xFF)         // Least significant 8 bits

        // Encode into RGB
        return (r, g, b)
    }
  
    
    func decode(inputBuffer: CVPixelBuffer, outputBuffer: CVPixelBuffer) -> Bool {
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
            let red = Float(inputPointer[i * 4]) * fromFixed / 1.0
            let green = Float(inputPointer[i * 4 + 1]) * fromFixed / 255.0
            let blue = Float(inputPointer[i * 4 + 2]) * fromFixed / 65025.0
            let depth = red + green + blue
            outputPointer[i] = UInt8(Float16(depth) * (maxDepth - minDepth) + minDepth)
        }
        
        return true
    }
    
    
    private func frac(_ x: Float) -> Float {
        return x - floor(x)
    }
    
    func encodeFloatTo3Channels(value: Float16) -> (r: UInt8, g: UInt8, b: UInt8) {
        let normalizedValue = UInt16(value * maxBound)
        // Split the 16-bit depth into three 5, 6, and 5-bit values (total 16 bits)
         let r = UInt8((normalizedValue >> 11) & 0x1F)    // Most significant 5 bits
         let g = UInt8((normalizedValue >> 5) & 0x3F)     // Middle 6 bits
         let b = UInt8(normalizedValue & 0x1F)            // Least significant 5 bits
        
        // Scale to the full 8-bit range for RGB
        let rScaled = r << 3
        let gScaled = g << 2
        let bScaled = b << 3
        return (rScaled, gScaled, bScaled)
    }
    
    func decode3ChannelsToFloat(red: UInt8, green: UInt8, blue: UInt8) -> Float16 {
        let uint16Value = (UInt16(red) << 8) | (UInt16(green) << 4) | UInt16(blue)
        let scalar = (maxDepth - minDepth) / maxBound + minDepth
        return Float16(uint16Value) * scalar
    }
}
// Shader
//
//const float fromFixed = 256.0 / 255.0;
//const float minDepth = 0.0;             // Minimum depth value (adjust as needed)
//const float maxDepth = 7.0;             // Maximum depth value (adjust as needed)
//const float scalar = 0.50;
//void main()
//{
//    vec4 rgba = texture(sTD2DInputs[0], vUV.st);
//    
//    // Extract the 4-bit segments from the rgba texture
//    float r = rgba.r * 31.0; // Red channel (scaled by 31 for 5 bits)
//    float g = rgba.g * 63.0; // Green channel (scaled by 63 for 6 bits)
//    float b = rgba.b * 31.0; // Blue channel (scaled by 31 for 5 bits)
//
//    // Reconstruct the normalized depth value
//    float normalizedDepth = (r * 2048.0) + (g * 32.0) + b;
//
//    // Normalize the value back to the range 0-1
//    normalizedDepth /= 65514.0;
//    
//    float depth = normalizedDepth;
//
//    
//    fragColor = vec4(depth, depth, depth, 1.0);
