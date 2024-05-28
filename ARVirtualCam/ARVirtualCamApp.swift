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
    
    @StateObject var virtualCameraViewModel: VirtualCameraPluginViewModel = VirtualCameraPluginViewModel()
    @State private var isInstallWindowOpen = false
    
    init() {
        self.webRTCClient = WebRTCClient(iceServers: WebRTCConfig.default.iceServers, streamId: WebRTCConfig.default.streamId)
        self.signalingClient = SignalingClient(serverUrl: WebRTCConfig.default.signalingServerUrl)
    }
    
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button(action: {
                        isInstallWindowOpen.toggle()
                    }) {
                        Text("Install Plugin")
                    }
                }
                ControlsView().environmentObject(self.virtualCameraViewModel)
                ConnectionView(webRTCClient: self.webRTCClient, signalingClient: self.signalingClient).environmentObject(self.virtualCameraViewModel)

            }.padding([.all], 20)
                .sheet(isPresented: $isInstallWindowOpen) {
                    VStack {
                        HStack {
                            Spacer()
                            Button("Close") {
                                isInstallWindowOpen.toggle()
                            }
                            .padding()
                        }
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                        InstallView()
                    }
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .onTapGesture {
                        isInstallWindowOpen.toggle()
                    }
                }
        }
    }
}
