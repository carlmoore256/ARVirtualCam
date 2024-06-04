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
    
    @StateObject var virtualCameraViewModel: VirtualCameraViewModel = VirtualCameraViewModel()
    @State private var isInstallWindowOpen = false
    
    let minimumWindowSize = CGSize(width: 500, height: 800)
    
    init() {
        self.webRTCClient = WebRTCClient(iceServers: WebRTCConfig.default.iceServers, streamId: WebRTCConfig.default.streamId)
        self.signalingClient = SignalingClient(serverUrl: WebRTCConfig.default.signalingServerUrl)
    }
    
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    Button(action: {
                        isInstallWindowOpen.toggle()
                    }) {
                        Text("Install Plugin")
                    }
                }
                ControlsView().environmentObject(self.virtualCameraViewModel).padding()
                ConnectionView(webRTCClient: self.webRTCClient, signalingClient: self.signalingClient).environmentObject(self.virtualCameraViewModel)

            }.padding([.all], 10)
                .sheet(isPresented: $isInstallWindowOpen) {
                    VStack {
                        HStack {
                            Spacer()
                            Button("Close") {
                                isInstallWindowOpen.toggle()
                            }
                            .padding()
                        }
                        .padding(.top, 10)
                        .padding(.trailing, 10)
                        InstallView()
                    }
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .onTapGesture {
                        isInstallWindowOpen.toggle()
                    }
                }
        }.defaultSize(minimumWindowSize)
    }
}
