//
//  VideoView.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/26/24.
//

import Foundation
import SwiftUI
import WebRTC


struct VideoView: View {
    let rtcVideoTrack: RTCVideoTrack

    var body: some View {
        GeometryReader { geometry in
            RTCMTLNSVideoViewWrapper(videoTrack: rtcVideoTrack, frame: geometry.frame(in: .local))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

}

struct RTCMTLNSVideoViewWrapper: NSViewRepresentable {
    typealias NSViewType = RTCMTLNSVideoView
    let renderer: RTCMTLNSVideoView

    init (videoTrack: RTCVideoTrack, frame: CGRect) {
        self.renderer = RTCMTLNSVideoView(frame: frame)
        videoTrack.add(self.renderer)
    }

    func makeNSView(context: Context) -> RTCMTLNSVideoView {
        return renderer
    }

    func updateNSView(_ uiView: RTCMTLNSVideoView, context: Context) {
        // Update video content if needed
    }
}

//
//ZStack {
//  
//}
