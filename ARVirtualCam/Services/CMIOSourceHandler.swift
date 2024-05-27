//
//  CMIOSink.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/25/24.
//

import Foundation
import AVFoundation
import Cocoa
import CoreMediaIO
import SystemExtensions

class CMIOSourceHandler : ObservableObject {
    
    private var _videoDescription: CMFormatDescription!
    private var _bufferPool: CVPixelBufferPool!
    private var _bufferAuxAttributes: NSDictionary!
    private var readyToEnqueue = false
    private var enqueued = false
    var sinkQueue: CMSimpleQueue?
    var sinkStream: CMIOStreamID?
    var sourceStream: CMIOStreamID?
    var needToStream: Bool = false
    var mirrorCamera: Bool = false
    
    private var _whiteStripeStartRow: UInt32 = 0
    private var _whiteStripeIsAscending: Bool = false
    
    private var image = NSImage(named: "cham-index")
    
    func initSink(deviceId: CMIODeviceID, sinkStream: CMIOStreamID) {
        let dims = CMVideoDimensions(width: fixedCamWidth, height: fixedCamHeight)
        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            width: dims.width, height: dims.height, extensions: nil, formatDescriptionOut: &_videoDescription)
        
        var pixelBufferAttributes: NSDictionary!
        pixelBufferAttributes = [
            kCVPixelBufferWidthKey: dims.width,
            kCVPixelBufferHeightKey: dims.height,
            kCVPixelBufferPixelFormatTypeKey: _videoDescription.mediaSubType,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &_bufferPool)
        
        let pointerQueue = UnsafeMutablePointer<Unmanaged<CMSimpleQueue>?>.allocate(capacity: 1)
        let pointerRef = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let result = CMIOStreamCopyBufferQueue(sinkStream, {
            (sinkStream: CMIOStreamID, buf: UnsafeMutableRawPointer?, refcon: UnsafeMutableRawPointer?) in
            let sender = Unmanaged<CMIOSourceHandler>.fromOpaque(refcon!).takeUnretainedValue()
            sender.readyToEnqueue = true
        },pointerRef,pointerQueue)
        if result != 0 {
            print("Error starting sink")
        } else {
            if let queue = pointerQueue.pointee {
                self.sinkQueue = queue.takeUnretainedValue()
            }
            let resultStart = CMIODeviceStartStream(deviceId, sinkStream) == 0
            if resultStart {
                print("initSink started")
            } else {
                print("initSink error startstream")
            }
        }
    }
    
    func makeDevicesVisible(){
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var allow : UInt32 = 1
        let dataSize : UInt32 = 4
        let zero : UInt32 = 0
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &prop, zero, nil, dataSize, &allow)
    }
    
    func connectToCamera() {
        guard let device = CameraProvider.getCMIODevice(name: cameraName) else {
            print("Error getting camera device!")
            return
        }
        
        if let deviceObjectId = CameraProvider.getCMIODeviceObjectId(deviceUniqueId: device.uniqueID) {
            let streamIds = CameraProvider.getInputStreams(deviceId: deviceObjectId)
            if streamIds.count == 2 {
                sinkStream = streamIds[1]
                print("Found sink stream!")
                initSink(deviceId: deviceObjectId, sinkStream: streamIds[1])
            }
            if let firstStream = streamIds.first {
                print("Found source stream!")
                sourceStream = firstStream
            }
        }
    }
    
    
    func enqueue(_ queue: CMSimpleQueue, _ image: CGImage, mirrorCamera: Bool) {
        guard CMSimpleQueueGetCount(queue) < CMSimpleQueueGetCapacity(queue) else {
            print("error enqueuing")
            return
        }
        var err: OSStatus = 0
        var pixelBuffer: CVPixelBuffer?
        err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, self._bufferPool, self._bufferAuxAttributes, &pixelBuffer)
        if let pixelBuffer = pixelBuffer {
            
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            
//            var bufferPtr = CVPixelBufferGetBaseAddress(pixelBuffer)!
//            let width = CVPixelBufferGetWidth(pixelBuffer)
//            let height = CVPixelBufferGetHeight(pixelBuffer)
//            let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
//            memset(bufferPtr, 0, rowBytes * height)
//            
//            let whiteStripeStartRow = self._whiteStripeStartRow
//            if self._whiteStripeIsAscending {
//                self._whiteStripeStartRow = whiteStripeStartRow - 1
//                self._whiteStripeIsAscending = self._whiteStripeStartRow > 0
//            }
//            else {
//                self._whiteStripeStartRow = whiteStripeStartRow + 1
//                self._whiteStripeIsAscending = self._whiteStripeStartRow >= (height - 30)
//            }
//            bufferPtr += rowBytes * Int(whiteStripeStartRow)
//            for _ in 0..<30 {
//                for _ in 0..<width {
//                    var white: UInt32 = 0xFFFFFFFF
//                    memcpy(bufferPtr, &white, MemoryLayout.size(ofValue: white))
//                    bufferPtr += MemoryLayout.size(ofValue: white)
//                }
//            }
            
            let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            // optimizing context: interpolationQuality and bitmapInfo
            // see https://stackoverflow.com/questions/7560979/cgcontextdrawimage-is-extremely-slow-after-large-uiimage-drawn-into-it
            if let context = CGContext(data: pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: rgbColorSpace,
                                      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
            {
                context.interpolationQuality = .low
                if mirrorCamera {
                    context.translateBy(x: CGFloat(width), y: 0.0)
                    context.scaleBy(x: -1.0, y: 1.0)
                }
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            
            var sbuf: CMSampleBuffer!
            var timingInfo = CMSampleTimingInfo()
            timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
            err = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: self._videoDescription, sampleTiming: &timingInfo, sampleBufferOut: &sbuf)
            if err == 0 {
                if let sbuf = sbuf {
                    let pointerRef = UnsafeMutableRawPointer(Unmanaged.passRetained(sbuf).toOpaque())
                    CMSimpleQueueEnqueue(queue, element: pointerRef)
                }
            }
        } else {
            print("error getting pixel buffer")
        }
    }

    func setJustProperty(streamId: CMIOStreamID, newValue: String) {
        let selector = FourCharCode("just")
        var address = CMIOObjectPropertyAddress(mSelector: selector, mScope: .global, mElement: .main)
        let exists = CMIOObjectHasProperty(streamId, &address)
        if exists {
            var settable: DarwinBoolean = false
            CMIOObjectIsPropertySettable(streamId,&address,&settable)
            if settable == false {
                return
            }
            var dataSize: UInt32 = 0
            CMIOObjectGetPropertyDataSize(streamId, &address, 0, nil, &dataSize)
            var newName: CFString = newValue as NSString
            CMIOObjectSetPropertyData(streamId, &address, 0, nil, dataSize, &newName)
        }
    }

    func getJustProperty(streamId: CMIOStreamID) -> String? {
        let selector = FourCharCode("just")
        var address = CMIOObjectPropertyAddress(selector, .global, .main)
        let exists = CMIOObjectHasProperty(streamId, &address)
        if exists {
            var dataSize: UInt32 = 0
            var dataUsed: UInt32 = 0
            CMIOObjectGetPropertyDataSize(streamId, &address, 0, nil, &dataSize)
            var name: CFString = "" as NSString
            CMIOObjectGetPropertyData(streamId, &address, 0, nil, dataSize, &dataUsed, &name);
            return name as String
        } else {
            return nil
        }
    }

    @objc func propertyTimer() {
        if let sourceStream = sourceStream {
            self.setJustProperty(streamId: sourceStream, newValue: "random")
            let just = self.getJustProperty(streamId: sourceStream)
            if let just = just {
                if just == "sc=1" {
                    needToStream = true
                } else {
                    needToStream = false
                }
            }
        }
    }
    
    @objc func fireTimer() {
        if needToStream {
            if (enqueued == false || readyToEnqueue == true), let queue = self.sinkQueue {
                enqueued = true
                readyToEnqueue = false
                if let image = image, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    self.enqueue(queue, cgImage, mirrorCamera: mirrorCamera)
                }
            }
        }
    }
}


