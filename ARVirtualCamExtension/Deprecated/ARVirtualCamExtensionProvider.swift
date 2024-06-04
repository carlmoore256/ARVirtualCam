//
//  ARVirtualCamExtensionProvider.swift
//  ARVirtualCamExtension
//
//  Created by Carl Moore on 5/24/24.
//

import Foundation
import CoreMediaIO
import IOKit.audio
import os.log
import AppKit



// MARK: -

class ARVirtualCamExtensionDeviceSource: NSObject, CMIOExtensionDeviceSource {
    
    private(set) var device: CMIOExtensionDevice!
    
    private var _streamSource: ARVirtualCamExtensionStreamSource!
//    public var _streamSink: CameraStreamSink!
    
    private var _streamingCounter: UInt32 = 0
    
    private var _timer: DispatchSourceTimer?
    
    private let _timerQueue = DispatchQueue(label: "timerQueue", qos: .userInteractive, attributes: [], autoreleaseFrequency: .workItem, target: .global(qos: .userInteractive))
    
    private var _videoDescription: CMFormatDescription!
    
    private var _bufferPool: CVPixelBufferPool!
    
    private var _bufferAuxAttributes: NSDictionary!
    
    private var _whiteStripeStartRow: UInt32 = 0
    
    private var _whiteStripeIsAscending: Bool = false
    
    private var _debugLogMessage: String = "No Message"
    
    var debugLogMessage: String {
        get {
            return _debugLogMessage
        }
        set {
            _timerQueue.sync {
                _debugLogMessage = newValue
            }
        }
    }
    
    init(localizedName: String) {
        
        super.init()
        let deviceID = UUID() // replace this with your device UUID
        self.device = CMIOExtensionDevice(localizedName: localizedName, deviceID: deviceID, legacyDeviceID: nil, source: self)
        
        let dims = CMVideoDimensions(width: 1920, height: 1080)
        CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: kCVPixelFormatType_32BGRA, width: dims.width, height: dims.height, extensions: nil, formatDescriptionOut: &_videoDescription)
        
        let pixelBufferAttributes: NSDictionary = [
            kCVPixelBufferWidthKey: dims.width,
            kCVPixelBufferHeightKey: dims.height,
            kCVPixelBufferPixelFormatTypeKey: _videoDescription.mediaSubType,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as NSDictionary
        ]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &_bufferPool)
        
        let videoStreamFormat = CMIOExtensionStreamFormat.init(formatDescription: _videoDescription, maxFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), minFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), validFrameDurations: nil)
        _bufferAuxAttributes = [kCVPixelBufferPoolAllocationThresholdKey: 5]
        
        let videoID = UUID() // replace this with your video UUID
        _streamSource = ARVirtualCamExtensionStreamSource(localizedName: "SampleCapture.Video", streamID: videoID, streamFormat: videoStreamFormat, device: device)
        do {
            try device.addStream(_streamSource.stream)
        } catch let error {
            fatalError("Failed to add stream: \(error.localizedDescription)")
        }
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        
        return [.deviceTransportType, .deviceModel]
    }
    
    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        
        let deviceProperties = CMIOExtensionDeviceProperties(dictionary: [:])
        if properties.contains(.deviceTransportType) {
            deviceProperties.transportType = kIOAudioDeviceTransportTypeVirtual
        }
        if properties.contains(.deviceModel) {
            deviceProperties.model = "SampleCapture Model"
        }
        
        return deviceProperties
    }
    
    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {
        
        // Handle settable properties here.
    }
    
    private func drawHorizontalLine(_ pixelBuffer: CVPixelBuffer) {
        var bufferPtr = CVPixelBufferGetBaseAddress(pixelBuffer)!
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        memset(bufferPtr, 0, rowBytes * height)
        
        let whiteStripeStartRow = self._whiteStripeStartRow
        if self._whiteStripeIsAscending {
            self._whiteStripeStartRow = whiteStripeStartRow - 1
            self._whiteStripeIsAscending = self._whiteStripeStartRow > 0
        }
        else {
            self._whiteStripeStartRow = whiteStripeStartRow + 1
            self._whiteStripeIsAscending = self._whiteStripeStartRow >= (height - kWhiteStripeHeight)
        }
        bufferPtr += rowBytes * Int(whiteStripeStartRow)
        for _ in 0..<kWhiteStripeHeight {
            for _ in 0..<width {
                var white: UInt32 = 0xFFFFFFFF
                memcpy(bufferPtr, &white, MemoryLayout.size(ofValue: white))
                bufferPtr += MemoryLayout.size(ofValue: white)
            }
        }
    }
    
    func startStreaming() {
        
        guard let _ = _bufferPool else {
            return
        }
        
        _streamingCounter += 1
        
        _timer = DispatchSource.makeTimerSource(flags: .strict, queue: _timerQueue)
        _timer!.schedule(deadline: .now(), repeating: 1.0 / Double(kFrameRate), leeway: .seconds(0))
        
        _timer!.setEventHandler {
            
            var err: OSStatus = 0
            let now = CMClockGetTime(CMClockGetHostTimeClock())
            
            var pixelBuffer: CVPixelBuffer?
            err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, self._bufferPool, self._bufferAuxAttributes, &pixelBuffer)
            if err != 0 {
                os_log(.error, "out of pixel buffers \(err)")
            }
            
            if let pixelBuffer = pixelBuffer {
                
                CVPixelBufferLockBaseAddress(pixelBuffer, [])
                
                self.drawHorizontalLine(pixelBuffer)
                                
                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                
                var sbuf: CMSampleBuffer!
                var timingInfo = CMSampleTimingInfo()
                timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
                err = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: self._videoDescription, sampleTiming: &timingInfo, sampleBufferOut: &sbuf)
                if err == 0 {
                    self._streamSource.stream.send(sbuf, discontinuity: [], hostTimeInNanoseconds: UInt64(timingInfo.presentationTimeStamp.seconds * Double(NSEC_PER_SEC)))
                }
                os_log(.info, "video time \(timingInfo.presentationTimeStamp.seconds) now \(now.seconds) err \(err)")
            }
        }
        
        _timer!.setCancelHandler {
        }
        
        _timer!.resume()
    }
    
    func stopStreaming() {
        
        if _streamingCounter > 1 {
            _streamingCounter -= 1
        }
        else {
            _streamingCounter = 0
            if let timer = _timer {
                timer.cancel()
                _timer = nil
            }
        }
    }
    
    private func drawText(_ text: String, on pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
        let bufferBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        if let context = CGContext(data: bufferBaseAddress, width: bufferWidth, height: bufferHeight, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
            
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))  // White color
            context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))  // Black color
            context.setLineWidth(1)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 100),
                .paragraphStyle: paragraphStyle,
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.clear
            ]
            
            let attributedString = NSAttributedString(string: text, attributes: attrs)
            attributedString.draw(at: CGPoint(x: 10, y: bufferHeight - 40))  // Draw near the bottom of the buffer
        } else {
            print("Failed to create CGContext")
        }
    }
    
    
}

// MARK: -

class ARVirtualCamExtensionStreamSource: NSObject, CMIOExtensionStreamSource {
    
    private(set) var stream: CMIOExtensionStream!
    
    let device: CMIOExtensionDevice
    
    private let _streamFormat: CMIOExtensionStreamFormat
    
    init(localizedName: String, streamID: UUID, streamFormat: CMIOExtensionStreamFormat, device: CMIOExtensionDevice) {
        
        self.device = device
        self._streamFormat = streamFormat
        super.init()
        self.stream = CMIOExtensionStream(localizedName: localizedName, streamID: streamID, direction: .source, clockType: .hostTime, source: self)
    }
    
    var formats: [CMIOExtensionStreamFormat] {
        
        return [_streamFormat]
    }
    
    var activeFormatIndex: Int = 0 {
        
        didSet {
            if activeFormatIndex >= 1 {
                os_log(.error, "Invalid index")
            }
        }
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        
        return [.streamActiveFormatIndex, .streamFrameDuration]
    }
    
    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        
        let streamProperties = CMIOExtensionStreamProperties(dictionary: [:])
        if properties.contains(.streamActiveFormatIndex) {
            streamProperties.activeFormatIndex = 0
        }
        if properties.contains(.streamFrameDuration) {
            let frameDuration = CMTime(value: 1, timescale: Int32(kFrameRate))
            streamProperties.frameDuration = frameDuration
        }
        
        return streamProperties
    }
    
    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        
        if let activeFormatIndex = streamProperties.activeFormatIndex {
            self.activeFormatIndex = activeFormatIndex
        }
    }
    
    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
        
        // An opportunity to inspect the client info and decide if it should be allowed to start the stream.
        return true
    }
    
    func startStream() throws {
        
        guard let deviceSource = device.source as? ARVirtualCamExtensionDeviceSource else {
            fatalError("Unexpected source type \(String(describing: device.source))")
        }
        deviceSource.startStreaming()
    }
    
    func stopStream() throws {
        
        guard let deviceSource = device.source as? ARVirtualCamExtensionDeviceSource else {
            fatalError("Unexpected source type \(String(describing: device.source))")
        }
        deviceSource.stopStreaming()
    }
}

// MARK: -

class ARVirtualCamExtensionProviderSource: NSObject, CMIOExtensionProviderSource {
    
    private(set) var provider: CMIOExtensionProvider!
    
    private var deviceSource: ARVirtualCamExtensionDeviceSource!
    
    // CMIOExtensionProviderSource protocol methods (all are required)
    
    init(clientQueue: DispatchQueue?, deviceSource: ARVirtualCamExtensionDeviceSource) {
        
        super.init()
        
        provider = CMIOExtensionProvider(source: self, clientQueue: clientQueue)
        self.deviceSource = deviceSource
        
        do {
            try provider.addDevice(deviceSource.device)
        } catch let error {
            fatalError("Failed to add device: \(error.localizedDescription)")
        }
    }
    
    func connect(to client: CMIOExtensionClient) throws {
        
        // Handle client connect
    }
    
    func disconnect(from client: CMIOExtensionClient) {
        
        // Handle client disconnect
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        
        // See full list of CMIOExtensionProperty choices in CMIOExtensionProperties.h
        return [.providerManufacturer]
    }
    
    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        
        let providerProperties = CMIOExtensionProviderProperties(dictionary: [:])
        if properties.contains(.providerManufacturer) {
            providerProperties.manufacturer = "SampleCapture Manufacturer"
        }
        return providerProperties
    }
    
    func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {
        
        // Handle settable properties here.
    }
}
