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

class CMIOVirutalCameraSource : ObservableObject {
    
    private var _videoDescription: CMFormatDescription!
    private var _bufferPool: CVPixelBufferPool!
    private var _bufferAuxAttributes: NSDictionary!
    private var readyToEnqueue = false
    private var enqueued = false
    
    private var inputPixelBuffer: CVPixelBuffer!
    var sinkQueue: CMSimpleQueue?
    var sinkStream: CMIOStreamID?
    var sourceStream: CMIOStreamID?
    var needToStream: Bool = false
    var mirrorCamera: Bool = false
    
    private var _whiteStripeStartRow: UInt32 = 0
    private var _whiteStripeIsAscending: Bool = false
    
    private var image = NSImage(named: "cham-index")
    
    private var width: Int32
    private var height: Int32
    private var pixelFormat: OSType
    
    private let ciContext = CIContext()
    private let resizeFilter = CIFilter(name: "CILanczosScaleTransform")!
    
    //    kCVPixelFormatType_32BGRA
    init(width: Int32 = fixedCamWidth, height: Int32 = fixedCamHeight, pixelFormat: OSType = kCVPixelFormatType_32BGRA) {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        
        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: pixelFormat,
            width: width,
            height: height,
            extensions: nil,
            formatDescriptionOut: &_videoDescription)
        
        var pixelBufferAttributes: NSDictionary!
        pixelBufferAttributes = [
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferPixelFormatTypeKey: _videoDescription.mediaSubType,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &_bufferPool)
        
        // create the input pixel buffer so we can dump frames into it
        CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, self._bufferPool, self._bufferAuxAttributes, &self.inputPixelBuffer)
        // set filter up for resizing
        self.resizeFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)
        
        self.makeDevicesVisible()
        self.connectToCamera()
    }
    
    func setPixelBuffer(newPixelBuffer: CVPixelBuffer) {
        let newWidth = Int32(CVPixelBufferGetWidth(newPixelBuffer))
        let newHeight = Int32(CVPixelBufferGetHeight(newPixelBuffer))
        
        if newWidth != width || newHeight != height {
            // if the dimensions of the incoming buffer are different, resize it
            let ciImage = CIImage(cvPixelBuffer: newPixelBuffer)
            self.resizeFilter.setValue(ciImage, forKey: kCIInputImageKey)
            self.resizeFilter.setValue(Int(width) / Int(newWidth), forKey: kCIInputScaleKey)
            if let outputImage = self.resizeFilter.outputImage {
                self.ciContext.render(outputImage, to: self.inputPixelBuffer!)
            } else {
                print("Error resizing pixel buffer")
                return
            }
        } else {
            self.inputPixelBuffer = newPixelBuffer
            //            let ciImage = CIImage(cvPixelBuffer: newPixelBuffer)
            //            self.ciContext.render(ciImage, to: self.inputPixelBuffer!)
        }
    }
    
    func generateDefaultPixelBuffer(with image: CGImage, mirrored: Bool = false) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, self._bufferPool, self._bufferAuxAttributes, &pixelBuffer)
        if let pixelBuffer = pixelBuffer {
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
            let width = pixelBuffer.width
            let height = pixelBuffer.height
            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            // optimizing context: interpolationQuality and bitmapInfo
            // see https://stackoverflow.com/questions/7560979/cgcontextdrawimage-is-extremely-slow-after-large-uiimage-drawn-into-it
            if let context = CGContext(data: pixelData,
                                       width: pixelBuffer.width,
                                       height: pixelBuffer.height,
                                       bitsPerComponent: 8,
                                       bytesPerRow: pixelBuffer.bytesPerRow,
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
            return pixelBuffer
        } else {
            print("error getting pixel buffer")
            return nil
        }
    }
    
    func initSink(deviceId: CMIODeviceID, sinkStream: CMIOStreamID) {
        let pointerQueue = UnsafeMutablePointer<Unmanaged<CMSimpleQueue>?>.allocate(capacity: 1)
        let pointerRef = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let result = CMIOStreamCopyBufferQueue(sinkStream, {
            (sinkStream: CMIOStreamID, buf: UnsafeMutableRawPointer?, refcon: UnsafeMutableRawPointer?) in
            let sender = Unmanaged<CMIOVirutalCameraSource>.fromOpaque(refcon!).takeUnretainedValue()
            sender.readyToEnqueue = true
        }, pointerRef,pointerQueue)
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
    
    func makeDevicesVisible() {
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
        guard let device = CameraProvider.getCMIODevice(name: depthCameraName) else {
            print("Error getting camera device!")
            return
        }
        if let deviceObjectId = CameraProvider.getCMIODeviceObjectId(deviceUniqueId: device.uniqueID) {
            let streamIds = CameraProvider.getInputStreams(deviceId: deviceObjectId)
            if streamIds.count == 2 {
                print("Found sink stream!")
                sinkStream = streamIds[1]
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
            print("error enqueuing frame for virtual camera, queue is at capacity")
            return
        }
        var err: OSStatus = 0
        if let pixelBuffer = self.inputPixelBuffer ?? generateDefaultPixelBuffer(with: image) {
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


//            guard self.inputPixelBuffer != nil else {
//                print("No pixel buffer yet, creating")
//                CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, self._bufferPool, self._bufferAuxAttributes, &self.inputPixelBuffer)
//                return
//            }

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
