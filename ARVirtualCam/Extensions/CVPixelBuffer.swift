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
    
    
    func searchTopPoint() -> CGPoint? {
        // Get width and height of buffer
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        
        // Lock buffer
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        
        // Unlock buffer upon exiting
        defer {
            CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        var returnPoint: CGPoint?
        
        var whitePixelsCount = 0
        
        if let baseAddress = CVPixelBufferGetBaseAddress(self) {
            let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
            
            // we look at pixels from bottom to top
            for y in (0 ..< height).reversed() {
                for x in (0 ..< width).reversed() {
                    // We look at top groups of 5 non black pixels
                    let pixel = buffer[y * bytesPerRow + x * 4]
                    let abovePixel = buffer[min(y + 1, height) * bytesPerRow + x * 4]
                    let belowPixel = buffer[max(y - 1, 0) * bytesPerRow + x * 4]
                    let rightPixel = buffer[y * bytesPerRow + min(x + 1, width) * 4]
                    let leftPixel = buffer[y * bytesPerRow + max(x - 1, 0) * 4]
                    
                    if pixel > 0 && abovePixel > 0 && belowPixel > 0 && rightPixel > 0 && leftPixel > 0 {
                        let newPoint = CGPoint(x: x, y: y)
                        // we return a normalized point (0-1)
                        returnPoint = CGPoint(x: newPoint.x / CGFloat(width), y: newPoint.y / CGFloat(height))
                        whitePixelsCount += 1
                    }
                }
            }
        }
        
        // We count the number of pixels in our frame. If the number is too low then we return nil because it means it's detecting a false positive
        if whitePixelsCount < 10 {
            returnPoint = nil
        }
        
        return returnPoint
    }
    
    func minimum() -> Float? {
        CVPixelBufferLockBaseAddress(self, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(self, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(self) else { return nil }
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        let pixelFormat = CVPixelBufferGetPixelFormatType(self)
        
        var minValue: Float = .nan
        var numNans = 0
        
        let buffer = baseAddress.assumingMemoryBound(to: Float.self)
        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = y * bytesPerRow / MemoryLayout<Float>.size + x
                let pixelValue = buffer[pixelOffset]
                
                if pixelValue.isNaN || pixelValue.isInfinite {
                    numNans += 1
                    continue
                }
                if pixelValue < minValue || minValue.isNaN {
                    minValue = pixelValue
                }
            }
        }
        
        print("Num nans: \(numNans)")
        
        return minValue.isFinite ? minValue : nil
    }

    
    func maximum() -> Float? {
        CVPixelBufferLockBaseAddress(self, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(self, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(self) else { return nil }
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        let pixelFormat = CVPixelBufferGetPixelFormatType(self)
        
        var maxValue: Float = .nan
        
        let buffer = baseAddress.assumingMemoryBound(to: Float.self)
        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = y * bytesPerRow / MemoryLayout<Float>.size + x
                let pixelValue = buffer[pixelOffset]
                if pixelValue.isNaN || pixelValue.isInfinite {
                    continue
                }
                if pixelValue > maxValue || maxValue.isNaN {
                    maxValue = pixelValue
                }
            }
        }
        
        return maxValue.isFinite ? maxValue : nil
    }
    
    func multiply(by scalar: Float) {
        CVPixelBufferLockBaseAddress(self, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(self, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(self) else { return }
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        let pixelFormat = CVPixelBufferGetPixelFormatType(self)
        
        switch pixelFormat {
        case 1717855600:
            let buffer = baseAddress.assumingMemoryBound(to: Float.self)
            for y in 0..<height {
                for x in 0..<width {
                    let pixelOffset = y * bytesPerRow / MemoryLayout<Float>.size + x
                    buffer[pixelOffset] *= scalar
                }
            }
            
        default:
            print("Unsupported pixel format: \(pixelFormat)")
        }
    }
    
    func convertToFloat32DepthBuffer() -> CVPixelBuffer? {
        CVPixelBufferLockBaseAddress(self, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(self, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(self) else { return nil }
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let pixelFormat = CVPixelBufferGetPixelFormatType(self)
        
        guard pixelFormat == kCVPixelFormatType_DepthFloat16 else {
            print("Unsupported pixel format: \(pixelFormat)")
            return nil
        }
        
        // Create a new pixel buffer for Float32
        var float32PixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, 1717855600, attributes as CFDictionary, &float32PixelBuffer)
        
        guard status == kCVReturnSuccess, let newBuffer = float32PixelBuffer else {
            print("Failed to create Float32 pixel buffer")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(newBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(newBuffer, []) }
        
        guard let newBaseAddress = CVPixelBufferGetBaseAddress(newBuffer) else { return nil }
        
        let float16Buffer = baseAddress.assumingMemoryBound(to: UInt16.self)
        let float32Buffer = newBaseAddress.assumingMemoryBound(to: Float.self)
        
        var srcBuffer = vImage_Buffer(data: float16Buffer, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: CVPixelBufferGetBytesPerRow(self))
        var dstBuffer = vImage_Buffer(data: float32Buffer, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: CVPixelBufferGetBytesPerRow(newBuffer))
        
        // Convert from Float16 to Float32
        vImageConvert_Planar16FtoPlanarF(&srcBuffer, &dstBuffer, 0)
        
        // Normalize the float32 data to fit the range 0.0 to 1.0
        let minRange: Float = 0.0
        let maxRange: Float = 1.0
        
        var minPixelValue: Float = 0
        var maxPixelValue: Float = 0
        
        vDSP_minv(float32Buffer, 1, &minPixelValue, vDSP_Length(width * height))
        vDSP_maxv(float32Buffer, 1, &maxPixelValue, vDSP_Length(width * height))
        
        let scale = (maxRange - minRange) / (maxPixelValue - minPixelValue)
        let offset = minRange - minPixelValue * scale
        
        vDSP_vsmsa(float32Buffer, 1, [scale], [offset], float32Buffer, 1, vDSP_Length(width * height))
        
        return newBuffer
    }
    
    func copy(to destinationBuffer: CVPixelBuffer) {
        precondition(self.width == destinationBuffer.width,
                     "Source and destination buffers must have the same width.")
        precondition(self.height == destinationBuffer.height,
                     "Source and destination buffers must have the same height.")
        precondition(self.type == destinationBuffer.type,
                     "Source and destination buffers must have the same pixel format.")
        precondition(self.numChannels >= destinationBuffer.numChannels,
                     "Destination buffer must have the same number of channels or greater. Source: \(self.numChannels) Destination: \(destinationBuffer.numChannels)")
    
        CVPixelBufferLockBaseAddress(self, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(self, .readOnly) }
        CVPixelBufferLockBaseAddress(destinationBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(destinationBuffer, []) }

        if self.numChannels > 0 {
            for plane in 0..<self.numChannels {
               let srcAddr = CVPixelBufferGetBaseAddressOfPlane(self, plane)
               let dstAddr = CVPixelBufferGetBaseAddressOfPlane(destinationBuffer, plane)
               let height = CVPixelBufferGetHeightOfPlane(self, plane)
               let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(self, plane)
               memcpy(dstAddr, srcAddr, height * bytesPerRow)
           }
        } else {
            let srcAddr = self.pointer
            let dstAddr = destinationBuffer.pointer
            let height = CVPixelBufferGetHeight(self)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
            memcpy(dstAddr, srcAddr, height * bytesPerRow)
        }
    }
    
    
    var width: Int { return CVPixelBufferGetWidth(self) }
    var height: Int { return CVPixelBufferGetHeight(self) }
    var type: OSType { return CVPixelBufferGetPixelFormatType(self) }
    var bytesPerRow: Int { return CVPixelBufferGetBytesPerRow(self) }
    var length: Int { return self.width * self.height }
    var pointer: UnsafeMutableRawPointer? { return CVPixelBufferGetBaseAddress(self) }
    var numChannels: Int { return CVPixelBufferGetPlaneCount(self) }
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

func convertDepthBufferToHSV(pixelBuffer: CVPixelBuffer, outputPixelBuffer: CVPixelBuffer, minDepth: Float16, maxDepth: Float16, hueScalar: Float16 = 180) -> Bool {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        return false
    }
    
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bufferLength = width * height
    
    // Create float buffer from base address
    // MUST be of type kCVPixelBuffer... 16
    let depthBuffer = baseAddress.assumingMemoryBound(to: Float16.self)
    
    // Prepare the output buffer
    CVPixelBufferLockBaseAddress(outputPixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(outputPixelBuffer, []) }
    
    guard let outputBaseAddress = CVPixelBufferGetBaseAddress(outputPixelBuffer) else {
        return false
    }
    let rgbBuffer = outputBaseAddress.assumingMemoryBound(to: UInt8.self)
    
    // Iterate over each pixel, convert depth to hue, and set RGB values
    for i in 0..<bufferLength {
        var depth = depthBuffer[i]
        if depth.isNaN || depth.isInfinite {
            depth = 0
        }
        //let rgb = normalizedValueToHSVRGB(value: depth, min: minDepth, max: maxDepth)
        if depth > maxDepth {
            depth = minDepth
        }
        if depth < minDepth {
            depth = minDepth
        }
        
        let normalizedValue = ((depth - minDepth) / (maxDepth - minDepth))
        
        let channels = encodeFloatTo3Channels(value: normalizedValue)
        
        
        //let h = (Float16(channels.0) / 255) * hueScalar
        //let s: Float16 = (Float16(channels.1) / 255)
        //let v: Float16 = (Float16(channels.2) / 255)
        

        //        let h = normalizedValue * hueScalar
        //        let s: Float = 1.0
        //        let v: Float = 1.0
        //        let rgb = HSVtoRGB(h: Float(h), s: s, v: v)

        //let rgb = HSVtoRGB(h: h, s: s, v: v)
        
        rgbBuffer[i * 3] = channels.0 // Red
        rgbBuffer[i * 3 + 1] = channels.1 // Green
        rgbBuffer[i * 3 + 2] = channels.2 // Blue
    }
    
    return true
}


func encodeFloatTo3Channels(value: Float16) -> (r: UInt8, g: UInt8, b: UInt8) {

    // Normalize to 0-255 range
    let normalizedValue = UInt16(value * 65504.0)

    // Extract 8 bits each for red, green, and blue channels
//    let red = UInt8((normalizedValue & 0b1111111100000000) >> 8)   // Most significant 8 bits
//    let green = UInt8((normalizedValue & 0b0000000011111100) >> 4)  // Middle 4 bits
//    let blue = UInt8(normalizedValue & 0b0000000000001111)         // Least significant 4 bits
    let red = UInt8((normalizedValue & 0xFF00) >> 8)   // Most significant 8 bits
    let green = UInt8((normalizedValue & 0x00F0) >> 4) // Middle 4 bits shifted
    let blue = UInt8(normalizedValue & 0x000F)         // Least significant 4 bits

    return (red, green, blue)
}

func decode3ChannelsToFloat(red: UInt8, green: UInt8, blue: UInt8, min: Float = 0.0, max: Float = 7.0) -> Float {
    // Combine the channels back into a UInt16
    let uint16Value = (UInt16(red) << 8) | (UInt16(green) << 4) | UInt16(blue)
    
    // Convert back to Float, scaling and adjusting for the original min/max range
    return Float(uint16Value) * (max - min) / 65535.0 + min
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

func floatToRGB(value: Float16, minRange: Float16, maxRange: Float16) -> (red: UInt8, green: UInt8, blue: UInt8) {
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

func HSVtoRGB(h: Float16, s: Float16, v: Float16) -> (r: UInt8, g: UInt8, b: UInt8) {
    // Optimized HSV to RGB conversion
    let c = v * s
    let x = c * (1 - abs((h / 60.0).truncatingRemainder(dividingBy: 2) - 1))
    let m = v - c
    
    var r: Float16 = 0, g: Float16 = 0, b: Float16 = 0
    
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

extension StringProtocol {
    subscript(_ offset: Int)                     -> Element     { self[index(startIndex, offsetBy: offset)] }
    subscript(_ range: Range<Int>)               -> SubSequence { prefix(range.lowerBound+range.count).suffix(range.count) }
    subscript(_ range: ClosedRange<Int>)         -> SubSequence { prefix(range.lowerBound+range.count).suffix(range.count) }
    subscript(_ range: PartialRangeThrough<Int>) -> SubSequence { prefix(range.upperBound.advanced(by: 1)) }
    subscript(_ range: PartialRangeUpTo<Int>)    -> SubSequence { prefix(range.upperBound) }
    subscript(_ range: PartialRangeFrom<Int>)    -> SubSequence { suffix(Swift.max(0, count-range.lowerBound)) }
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
