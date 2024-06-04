//
//  OverflowDepthCodecAlgorithm.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/31/24.
//

import Foundation
import CoreVideo
import Accelerate

class OverflowDepthCodecAlgorithm : PixelBufferCodecAlgorithm, ObservableObject  {
    
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
            
            
            //let encoded = encodeDepthToRGBA(depth: depth, minDepth: minDepth, maxDepth: maxDepth)
            let normalizedDepth = (depth - minDepth) / (maxDepth - minDepth)
            let encoded = encodeFloatTo3Channels(value: normalizedDepth)
            
            //let normalizedDepth = UInt16(((depth - minDepth) / (maxDepth - minDepth)) * 65514.0)
            //let highByte = UInt8((normalizedDepth & 0xFF00) >> 8)
            //let lowByte = UInt8(normalizedDepth & 0x00FF)
            outputPointer[i * 4] = encoded.b
            outputPointer[i * 4 + 1] = encoded.g
            outputPointer[i * 4 + 2] = encoded.r
            outputPointer[i * 4 + 3] = 255
            

//            outputPointer[i * 4]     = highByte     // Blue
//            outputPointer[i * 4 + 1] = lowByte  // Green
//            outputPointer[i * 4 + 2] = 0  // Red (unused)
//            outputPointer[i * 4 + 3] = 0  // Alpha
            
//            let normalizedValue = ((depth - minDepth) / (maxDepth - minDepth))
//            let fixedValue = Float(normalizedValue) * toFixed
//            outputPointer[i * 4]     = UInt8(frac(fixedValue) * 255.0)    // Red
//            outputPointer[i * 4 + 1] = UInt8(frac(fixedValue * 255.0) * 255.0)  // Green
//            outputPointer[i * 4 + 2] = UInt8(frac(fixedValue * 65025.0) * 255.0) // Blue
//            outputPointer[i * 4 + 3] = 255
//            let channels = encodeFloatTo3Channels(value: normalizedValue)
//            outputPointer[i * 4] = channels.0 // Red
//            outputPointer[i * 4 + 1] = channels.1 // Green
//            outputPointer[i * 4 + 2] = channels.2 // Blue
//            outputPointer[i * 4 + 3] = 255
        }
        
        return true
    }
    
    func encodeDepthToRGBA(depth: Float16, minDepth: Float16, maxDepth: Float16) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        // Normalize depth to range [0, 1]
        let normalizedDepth = (depth - minDepth) / (maxDepth - minDepth)

        // Convert to range [0, 65535] for 16-bit depth
        let depth16 = UInt16(normalizedDepth * 65504.0)

        // Split the 16-bit depth into four 4-bit values
        let r = UInt8((depth16 >> 12) & 0x0F)
        let g = UInt8((depth16 >> 8) & 0x0F)
        let b = UInt8((depth16 >> 4) & 0x0F)
        let a = UInt8(depth16 & 0x0F)

        // Encode into RGBA
        return (r, g, b, a)
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
//
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
