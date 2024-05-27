//
//  ConnectionView.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/25/24.
//

import SwiftUI
import WebRTC

struct ConnectionView : View {
    @StateObject private var webRTC: WebRTCStateManager
    @StateObject var depthPixelBufferChannel = CVPixelBufferDataChannel()
    
    init (webRTCClient: WebRTCClient, signalingClient: SignalingClient) {
        let observableWebRTC = WebRTCStateManager(webRTCClient: webRTCClient, signalingClient: signalingClient)
        
        self._webRTC = StateObject(wrappedValue: observableWebRTC)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if let videoTrack = webRTC.webRTCClient.getRemoteVideoTrack(trackId: "color") {
                VideoView(rtcVideoTrack: videoTrack).frame(maxWidth: .infinity, maxHeight: 240)
            }
            Text("Depth")
            PixelBufferView(pixelBufferChannel: depthPixelBufferChannel).frame(maxWidth: .infinity, maxHeight: 240)
            Divider()
            Text("Available WebRTC Channels:")
            ForEach(webRTC.dataChannels) { dataChannel in
                ChannelDataItem(dataChannel: dataChannel)
            }
            Divider()
            StatusIndicator(title: "Signaling Server Connected", status: self.webRTC.signalingConnected)
            StatusIndicator(title: "Local SDP", status: self.webRTC.hasLocalSdp)
            StatusIndicator(title: "Remote SDP", status: self.webRTC.hasRemoteSdp)
            Divider()
            VStack(alignment: .leading) {
                Text("Local Candidate Count: \(self.webRTC.localCandidateCount)")
                Text("Connection State: \(self.webRTC.connectionStatusLabel)")
                Text(self.webRTC.peerConnectionStatus)
            }
            Divider()
            HStack(spacing: 10) {
                Button("Send Offer", action: self.webRTC.createOffer)
                    .buttonStyle(RoundedButtonStyle())
                Button("Send Answer", action: self.webRTC.createAnswer)
                    .buttonStyle(RoundedButtonStyle())
            }
        }
        .padding([.all], 20)
        .onAppear() {
            self.webRTC.connect()
        }
        .onChange(of: webRTC.dataChannels) {
            if let depthChannel = webRTC.dataChannels.first(where: { $0.label == "depth" }) {
                print("Depth data channel found: \(depthChannel)")
                depthChannel.setDelegate(delegate: depthPixelBufferChannel)
                
            }
        }
    }
}

struct ChannelDataItem: View {
    let dataChannel: ActiveRTCDataChannel
    
    var body: some View {
        HStack {
            Text("Channel: \(dataChannel.channel.label)")
            Spacer()
            Text(dataChannel.isLocal ? "Local" : "Remote")
        }
    }
}

struct StatusIndicator: View {
    let title: String
    let status: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(status ? .green : .red)
        }
    }
}


#Preview {
    ControlsView()
    //    let webRTCClient: WebRTCClient = WebRTCClient(iceServers: WebRTCConfig.default.iceServers, streamId: WebRTCConfig.default.streamId)
    //    let signalingClient = SignalingClient(serverUrl: WebRTCConfig.default.signalingServerUrl)
    //    ConnectionView(webRTCClient: webRTCClient, signalingClient: signalingClient)
}
