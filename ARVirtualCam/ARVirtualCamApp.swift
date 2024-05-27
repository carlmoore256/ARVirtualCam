//
//  ARVirtualCamApp.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/24/24.
//

import SwiftUI

@main
struct ARVirtualCamApp: App {
    
    let webRTCClient: WebRTCClient
    let signalingClient: SignalingClient
    
    init() {
        self.webRTCClient = WebRTCClient(iceServers: WebRTCConfig.default.iceServers, streamId: WebRTCConfig.default.streamId)
        self.signalingClient = SignalingClient(serverUrl: WebRTCConfig.default.signalingServerUrl)
    }
    
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 20) {
                InstallView()
                ControlsView()
                ConnectionView(webRTCClient: self.webRTCClient, signalingClient: self.signalingClient)
            }.padding([.all], 20)
        }
    }
}
