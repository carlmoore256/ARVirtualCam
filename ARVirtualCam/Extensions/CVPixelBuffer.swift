//
//  CVPixelBuffer.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/27/24.
//

import Foundation
import VideoToolbox
import Accelerate
import CoreVideo

extension CVPixelBuffer {
    func toCGImage() -> CGImage? {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(self, options: nil, imageOut: &cgImage)
        return cgImage
    }
}

func create8Bit3ChannelPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    let pixelBufferAttributes: [String: Any] = [
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_24RGB
    ]
    let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_24RGB, pixelBufferAttributes as CFDictionary, &pixelBuffer)
    return status == kCVReturnSuccess ? pixelBuffer : nil
}

func convert32BitTo8Bit3Channel(pixelBuffer: CVPixelBuffer, outputPixelBuffer: CVPixelBuffer, min: Float, max: Float) -> Bool {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        return false
    }
    
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bufferLength = width * height
    
    // Create float buffer from base address
    let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
    
    // Prepare the output buffer
    CVPixelBufferLockBaseAddress(outputPixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(outputPixelBuffer, []) }
    
    guard let outputBaseAddress = CVPixelBufferGetBaseAddress(outputPixelBuffer) else {
        return false
    }
    let rgbBuffer = outputBaseAddress.assumingMemoryBound(to: UInt8.self)
    
    // Prepare scaling factor
    let scale = 16777215.0 / (max - min) // 16777215 is 2^24 - 1
    
    // Create an intermediate buffer to hold the scaled values
    var scaledBuffer = [Float](repeating: 0.0, count: bufferLength)
    
    // Scale and shift the float buffer
    vDSP_vsmsa(floatBuffer, 1, [scale], [-min * scale], &scaledBuffer, 1, vDSP_Length(bufferLength))
    
    // Process the buffer using a single loop to extract the RGB components
    scaledBuffer.withUnsafeBytes { scaledBytes in
        let scaledBufferPointer = scaledBytes.bindMemory(to: UInt32.self)
        for i in 0..<bufferLength {
            let intValue = scaledBufferPointer[i]
            rgbBuffer[i * 3] = UInt8((intValue >> 16) & 0xFF)
            rgbBuffer[i * 3 + 1] = UInt8((intValue >> 8) & 0xFF)
            rgbBuffer[i * 3 + 2] = UInt8(intValue & 0xFF)
        }
    }
    
    return true
}

func convertDepthBufferToHSV(pixelBuffer: CVPixelBuffer, outputPixelBuffer: CVPixelBuffer, minDepth: Float, maxDepth: Float) -> Bool {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        return false
    }
    
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bufferLength = width * height
    
    // Create float buffer from base address
    let depthBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
    
    // Prepare the output buffer
    CVPixelBufferLockBaseAddress(outputPixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(outputPixelBuffer, []) }
    
    guard let outputBaseAddress = CVPixelBufferGetBaseAddress(outputPixelBuffer) else {
        return false
    }
    let rgbBuffer = outputBaseAddress.assumingMemoryBound(to: UInt8.self)
    
    // Iterate over each pixel, convert depth to hue, and set RGB values
    for i in 0..<bufferLength {
        let depth = depthBuffer[i]
        let rgb = normalizedValueToHSVRGB(value: depth, min: minDepth, max: maxDepth)
        
        rgbBuffer[i * 3] = rgb.0 // Red
        rgbBuffer[i * 3 + 1] = rgb.1 // Green
        rgbBuffer[i * 3 + 2] = rgb.2 // Blue
    }
    
    return true
}

func normalizedValueToHSVRGB(value: Float, min: Float = 0.0, max: Float = 1.0) -> (r: UInt8, g: UInt8, b: UInt8) {
    guard value >= min, value <= max else { return (0, 0, 0) } // Range check

    // Normalize the value to a 0-1 range
    let normalizedValue = (value - min) / (max - min)

    // Define the HSV values
    let h = normalizedValue * 360.0 // Hue range from 0 to 360 degrees
    let s: Float = 1.0 // Full saturation
    let v: Float = 1.0 // Full brightness

    // Optimized HSV to RGB conversion
    let c = v * s
    let x = c * (1 - abs((h / 60.0).truncatingRemainder(dividingBy: 2) - 1))
    let m = v - c

    var r: Float = 0, g: Float = 0, b: Float = 0

    let hSegment = Int(h / 60.0) % 6

    switch hSegment {
    case 0:
        r = c; g = x; b = 0
    case 1:
        r = x; g = c; b = 0
    case 2:
        r = 0; g = c; b = x
    case 3:
        r = 0; g = x; b = c
    case 4:
        r = x; g = 0; b = c
    case 5:
        r = c; g = 0; b = x
    default:
        break
    }

    r += m
    g += m
    b += m

    return (
        r: UInt8(r * 255.0),
        g: UInt8(g * 255.0),
        b: UInt8(b * 255.0)
    )
}

func floatToRGB(value: Float, minRange: Float, maxRange: Float) -> (red: UInt8, green: UInt8, blue: UInt8) {
    let hue = (value - minRange) / (maxRange - minRange) * 360
    
    // Basic HSV to RGB conversion (assumes saturation = 1, value = 1)
    var r, g, b: Float
    let i = Int(hue * 6)
    let f = Float(hue) * 6 - Float(i)
    let p: Float = 0
    let q = 1 - f
    let t = f
    
    switch i % 6 {
    case 0: (r, g, b) = (1, t, p)
    case 1: (r, g, b) = (q, 1, p)
    case 2: (r, g, b) = (p, 1, t)
    case 3: (r, g, b) = (p, q, 1)
    case 4: (r, g, b) = (t, p, 1)
    case 5: (r, g, b) = (1, p, q)
    default: (r, g, b) = (0, 0, 0) // Should never happen
    }
    
    return (
        min(UInt8(r * 255), 255),
        min(UInt8(g * 255), 255),
        min(UInt8(b * 255), 255)
    )
}

func HSVtoRGB(h: CGFloat, s: CGFloat, v: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
    let i = Int(h / 60) % 6
    let f = h / 60 - CGFloat(i)
    let p = v * (1 - s)
    let q = v * (1 - f * s)
    let t = v * (1 - (1 - f) * s)
    
    switch i {
    case 0: (r, g, b) = (v, t, p)
    case 1: (r, g, b) = (q, v, p)
    case 2: (r, g, b) = (p, v, t)
    case 3: (r, g, b) = (p, q, v)
    case 4: (r, g, b) = (t, p, v)
    case 5: (r, g, b) = (v, p, q)
    default: break // Unreachable
    }
    
    return (r, g, b)
}


func convertDepthBufferToRGB(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    
    guard let depthBufferPointer = CVPixelBufferGetBaseAddress(pixelBuffer)?.bindMemory(to: Float32.self, capacity: width * height) else {
        return nil // Handle the error if the base address is invalid
    }
    
    // Precalculate depth range (5 meters)
    //    var depthMin: Float32 = 0.0
    //    var depthMax: Float32 = 6.0
    
    // Use vImage for potential performance gains
    do {
        var srcBuffer = vImage_Buffer(data: depthBufferPointer, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * MemoryLayout<Float32>.size)
        var dstBuffer = try vImage_Buffer(width: Int(vImagePixelCount(Int(width))), height: Int(vImagePixelCount(height)), bitsPerPixel: 32)
        
        vImageConvert_PlanarFtoRGBFFF(&srcBuffer, &srcBuffer, &srcBuffer, &dstBuffer, vImage_Flags(kvImageNoFlags))
        
        // optimized to interleave 4 32bit planar buffers into an 8-bits-per-channel, 4 channel interleaved buffer
        //        vImageConvert_PlanarFToARGB8888(&srcBuffer, &srcBuffer, &srcBuffer, &srcBuffer, &dstBuffer, &depthMax, &depthMin, vImage_Flags(kvImageNoFlags))
        
        // Wrap dstBuffer in a CVPixelBuffer
        var outputPixelBuffer: CVPixelBuffer?
        CVPixelBufferCreateWithBytes(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, dstBuffer.data, dstBuffer.rowBytes, nil, nil, nil, &outputPixelBuffer)
        
        // Cleanup
        dstBuffer.free() // Deallocate memory used by vImage
        
        return outputPixelBuffer
    } catch {
        return nil
    }
    
}

//func convertDepthBufferToRGB(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
//    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
//
//    let width = CVPixelBufferGetWidth(pixelBuffer)
//    let height = CVPixelBufferGetHeight(pixelBuffer)
//    let depthBufferPointer = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: Float32.self)
//
//    // Assume known or calculated maximum and minimum values for depth
//    let depthMax: Float32 = 4.0  // maximum expected depth in meters
//    let depthMin: Float32 = 0.0  // minimum expected depth in meters
//
//    // Prepare output buffer with RGB format
//    let rgbBytesPerRow = width * 4
//    let rgbData = UnsafeMutablePointer<UInt8>.allocate(capacity: height * rgbBytesPerRow)
//    rgbData.initialize(repeating: 0, count: height * rgbBytesPerRow)
//
//    // Fill RGB buffer
//    for row in 0..<height {
//        for column in 0..<width {
//            let depthIndex = row * width + column
//            let rgbIndex = row * rgbBytesPerRow + column * 4
//
//            // Extract and normalize the depth value
//            let depthValue = depthBufferPointer[depthIndex]
//            let normalizedDepth = (depthValue - depthMin) / (depthMax - depthMin)
//            let scaledDepth = UInt32(normalizedDepth * Float(UInt32.max))
//
//            rgbData[rgbIndex + 0] = UInt8(truncatingIfNeeded: scaledDepth >> 16) // Red
//            rgbData[rgbIndex + 1] = UInt8(truncatingIfNeeded: scaledDepth >> 8)  // Green
//            rgbData[rgbIndex + 2] = UInt8(truncatingIfNeeded: scaledDepth)       // Blue
//            rgbData[rgbIndex + 3] = 255                                         // Alpha
//        }
//    }
//
//    // Create an output pixel buffer
//    var outputPixelBuffer: CVPixelBuffer?
//    let status = CVPixelBufferCreateWithBytes(nil, width, height, kCVPixelFormatType_32BGRA, rgbData,
//                                              rgbBytesPerRow, nil, nil, nil, &outputPixelBuffer)
//
//    // Cleanup
//    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
//
//    if status != kCVReturnSuccess {
//        print("Failed to create RGB pixel buffer")
//        return nil
//    }
//
//    return outputPixelBuffer
//}
