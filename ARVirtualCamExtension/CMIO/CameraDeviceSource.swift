//
//  CameraDeviceSource.swift
//  ARVirtualCamExtension
//
//  Created by Carl Moore on 5/25/24.
//

import Foundation
import CoreMediaIO
import IOKit.audio
import os.log
import Cocoa

let textColor = NSColor.white
let fontSize = 24.0
let textFont = NSFont.systemFont(ofSize: fontSize)
let kWhiteStripeHeight: Int = 10

class CameraDeviceSource: NSObject, CMIOExtensionDeviceSource {
    
    private(set) var device: CMIOExtensionDevice!
    
    public var _streamSource: CameraStreamSource!
    public var _streamSink: CameraStreamSink!
    private var _streamingCounter: UInt32 = 0
    private var _streamingSinkCounter: UInt32 = 0
    
    private var _timer: DispatchSourceTimer?
    
    private let _timerQueue = DispatchQueue(label: "timerQueue", qos: .userInteractive, attributes: [], autoreleaseFrequency: .workItem, target: .global(qos: .userInteractive))
    
    private var _videoDescription: CMFormatDescription!
    
    private var _bufferPool: CVPixelBufferPool!
    
    private var _bufferAuxAttributes: NSDictionary!
    
    private var _whiteStripeStartRow: UInt32 = 0
    
    private var _whiteStripeIsAscending: Bool = false
    
    var lastMessage = "Sample Camera for macOS"
    
    func myStreamingCounter() -> String {
        return "sc=\(_streamingCounter)"
    }
    
    init(localizedName: String) {
        
        paragraphStyle.alignment = NSTextAlignment.center
        textFontAttributes = [
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.foregroundColor: textColor,
            NSAttributedString.Key.paragraphStyle: paragraphStyle
        ]
        super.init()
        let deviceID = UUID()
        self.device = CMIOExtensionDevice(localizedName: localizedName, deviceID: deviceID, legacyDeviceID: deviceID.uuidString, source: self)
        
        //let dims = CMVideoDimensions(width: 1920, height: 1080)
        let dims = CMVideoDimensions(width: fixedCamWidth, height: fixedCamHeight)
        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            //codecType: kCVPixelFormatType_32ARGB/*kCVPixelFormatType_32BGRA*/,
            width: dims.width, height: dims.height, extensions: nil, formatDescriptionOut: &_videoDescription)
        
        let pixelBufferAttributes: NSDictionary = [
            kCVPixelBufferWidthKey: dims.width,
            kCVPixelBufferHeightKey: dims.height,
            kCVPixelBufferPixelFormatTypeKey: _videoDescription.mediaSubType,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &_bufferPool)
        
        let videoStreamFormat = CMIOExtensionStreamFormat.init(formatDescription: _videoDescription, maxFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), minFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), validFrameDurations: nil)
        _bufferAuxAttributes = [kCVPixelBufferPoolAllocationThresholdKey: 5]
        
        let videoID = UUID()
        _streamSource = CameraStreamSource(localizedName: "SampleCamera.Video", streamID: videoID, streamFormat: videoStreamFormat, device: device)
        let videoSinkID = UUID()
        _streamSink = CameraStreamSink(localizedName: "SampleCamera.Video.Sink", streamID: videoSinkID, streamFormat: videoStreamFormat, device: device)
        do {
            try device.addStream(_streamSource.stream)
            try device.addStream(_streamSink.stream)
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
            //deviceProperties.setPropertyState(CMIOExtensionPropertyState(value: "toto" as NSString), forProperty: .deviceModel)
            deviceProperties.model = "Sample Camera Model"
        }
        
        return deviceProperties
    }
    
    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {
        
        
        // Handle settable properties here.
    }
    
    let paragraphStyle = NSMutableParagraphStyle()
    let textFontAttributes: [NSAttributedString.Key : Any]
    
    func startStreaming() {
        
        guard let _ = _bufferPool else {
            return
        }
        
        _streamingCounter += 1
        _timer = DispatchSource.makeTimerSource(flags: .strict, queue: _timerQueue)
        _timer!.schedule(deadline: .now(), repeating: 1.0/Double(kFrameRate), leeway: .seconds(0))
        
        _timer!.setEventHandler {
            
            if self.sinkStarted {
                return
            }
            //var text: String? = nil
            var err: OSStatus = 0
            
            var pixelBuffer: CVPixelBuffer?
            
            let timestamp = CMClockGetTime(CMClockGetHostTimeClock())
            let text = self.lastMessage + " \(Int(timestamp.seconds))"
            err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, self._bufferPool, self._bufferAuxAttributes, &pixelBuffer)
            if err != 0 {
                os_log(.error, "out of pixel buffers \(err)")
            }
            if let pixelBuffer = pixelBuffer {
                
                CVPixelBufferLockBaseAddress(pixelBuffer, [])
                let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
                let width = CVPixelBufferGetWidth(pixelBuffer)
                let height = CVPixelBufferGetHeight(pixelBuffer)
                let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                if let context = CGContext(data: pixelData,
                                           width: width,
                                           height: height,
                                           bitsPerComponent: 8,
                                           bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                           space: rgbColorSpace,
//                                           bitmapInfo: UInt32(CGImageAlphaInfo.noneSkipFirst.rawValue) | UInt32(CGImageByteOrderInfo.order32Little.rawValue))
                                           bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
                {
                    
                    let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = graphicsContext
                    let cgContext = graphicsContext.cgContext
                    let dstRect = CGRect(x: 0, y: 0, width: width, height: height)
                    cgContext.clear(dstRect)
                    cgContext.setFillColor(NSColor.black.cgColor)
                    cgContext.fill(dstRect)
                    let textOrigin = CGPoint(x: 0, y: -height/2 + Int(fontSize/2.0))
                    let rect = CGRect(origin: textOrigin, size: NSSize(width: width, height: height))
                    text.draw(in: rect, withAttributes: self.textFontAttributes)
                    NSGraphicsContext.restoreGraphicsState()
                }
                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            }
            
            if let pixelBuffer = pixelBuffer {
                var sbuf: CMSampleBuffer!
                var timingInfo = CMSampleTimingInfo()
                timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
                err = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: self._videoDescription, sampleTiming: &timingInfo, sampleBufferOut: &sbuf)
                if err == 0 {
                    self._streamSource.stream.send(sbuf, discontinuity: [], hostTimeInNanoseconds: UInt64(timingInfo.presentationTimeStamp.seconds * Double(NSEC_PER_SEC)))
                } else {
                    self.lastMessage = "err send"
                }
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
    
    var sinkStarted = false
    var lastTimingInfo = CMSampleTimingInfo()
    func consumeBuffer(_ client: CMIOExtensionClient) {
        if sinkStarted == false {
            return
        }
        self._streamSink.stream.consumeSampleBuffer(from: client) { sbuf, seq, discontinuity, hasMoreSampleBuffers, err in
            if sbuf != nil {
                self.lastTimingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
                let output: CMIOExtensionScheduledOutput = CMIOExtensionScheduledOutput(sequenceNumber: seq, hostTimeInNanoseconds: UInt64(self.lastTimingInfo.presentationTimeStamp.seconds * Double(NSEC_PER_SEC)))
                if self._streamingCounter > 0 {
                    self._streamSource.stream.send(sbuf!, discontinuity: [], hostTimeInNanoseconds: UInt64(sbuf!.presentationTimeStamp.seconds * Double(NSEC_PER_SEC)))
                }
                self._streamSink.stream.notifyScheduledOutputChanged(output)
            }
            self.consumeBuffer(client)
        }
    }
    
    func startStreamingSink(client: CMIOExtensionClient) {
        
        _streamingSinkCounter += 1
        self.sinkStarted = true
        consumeBuffer(client)
    }
    
    func stopStreamingSink() {
        self.sinkStarted = false
        if _streamingSinkCounter > 1 {
            _streamingSinkCounter -= 1
        }
        else {
            _streamingSinkCounter = 0
        }
    }}
