//
//  FrameVideoCapturer.swift
//  RgbdCameraStreamer
//
//  Created by Carl Moore on 5/24/24.
//

import Foundation
import WebRTC

class FrameVideoCapturer: RTCVideoCapturer {
    var videoSource: RTCVideoSource?
    let rtcQueue = DispatchQueue(label: "WebRTC")
    
    init(videoSource: RTCVideoSource) {
        self.videoSource = videoSource
        super.init()
    }
    
    func capture(pixelBuffer: CVPixelBuffer, timeStamp: CMTime, fps: Int32 = 30) {
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let timeStampNs = Int64(CMTimeGetSeconds(timeStamp) * Double(NSEC_PER_SEC))
        
        self.rtcQueue.async {
            let videoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: ._0, timeStampNs: timeStampNs)
            guard let videoSource = self.videoSource else {
                debugPrint("Video source is null!")
                return
            }
            videoSource.adaptOutputFormat(toWidth: Int32(CVPixelBufferGetWidth(pixelBuffer)), height: Int32(CVPixelBufferGetHeight(pixelBuffer)), fps: fps)
            videoSource.capturer(self, didCapture: videoFrame)
        }
        
    }
}
