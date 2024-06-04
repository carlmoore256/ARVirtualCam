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
    // @StateObject var colorPixelBufferChannel = CVPixelBufferDataChannel()
    
    @EnvironmentObject var virtualCameraViewModel: VirtualCameraViewModel // allows us to send data to the virtual camera
    
    let imageWidth: CGFloat = 200
    let imageHeight: CGFloat = 200
    let transformAlgorithm = Truncate16Bit(rangeMin: 0.0, rangeMax: 5.0)
    let depthTranscoder : DepthBufferTranscoder
    
    init (webRTCClient: WebRTCClient, signalingClient: SignalingClient) {
        let observableWebRTC = WebRTCStateManager(webRTCClient: webRTCClient, signalingClient: signalingClient)
        self._webRTC = StateObject(wrappedValue: observableWebRTC)
        
        self.depthTranscoder = DepthBufferTranscoder(width: 320, height: 240, transform: self.transformAlgorithm)
    }
    
    
    var body: some View {
        
        VStack(spacing: 10) {
            Slider(value: Binding<Double>(
                get: { Double(transformAlgorithm.rangeMin) },
                set: { transformAlgorithm.rangeMin = Float($0) }
            ),
                   in: 0...7,
                   label: {
                Text("Range Min")
            })
            Slider(value: Binding<Double>(
                get: { Double(transformAlgorithm.rangeMax) },
                set: { transformAlgorithm.rangeMax = Float($0) }
            ),
                   in: 0...7,
                   label: {
                Text("Range Max")
            })
            HStack {
                Text("Depth")
                Spacer()
                Text("\(depthPixelBufferChannel.averageFrameRate) FPS")
                DataRateView(dataRate: $depthPixelBufferChannel.averageDataRate)
                
            }
            
            HStack {
                ForEach(webRTC.remoteTracks) { track in
                    VideoView(rtcVideoTrack: track.track).frame(maxWidth: 400, maxHeight: 240)
                        .frame(width: imageWidth, height: imageHeight)
                        .border(Color.gray, width: 1)
                        .clipped()
                }
                PixelBufferView(pixelBufferChannel: depthPixelBufferChannel).frame(maxHeight: 240)
                    .frame(width: imageWidth, height: imageHeight)
                    .border(Color.gray, width: 1)
                    .clipped()
            }
            
            Divider()
            Text("Available WebRTC Streams:")
            ForEach(webRTC.remoteTracks) { track in
                TrackInfoItem(track: track)
            }
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
                // sets the delegate of this specific channel to the depthPixelBuffer delegate
                depthChannel.setDelegate(delegate: depthPixelBufferChannel)
                // add a listener to whenever the buffer updates, and send the depth buffer to the virtual cam
                depthPixelBufferChannel.addBufferListener(id: "sendBuffer", listener: { pixelBuffer in
                    guard let encodedBuffer = depthTranscoder.transcode(pixelBuffer) else {
                        print("Error encountered encoding buffer")
                        return
                    }
                    virtualCameraViewModel.sendPixelBuffer(pixelBuffer: encodedBuffer)
                })
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

struct TrackInfoItem: View {
    let track: any ActiveRTCVideoTrack
    var body: some View {
        HStack {
            Text(track.isLocal ? "Local Stream: \(track.id)" : "Remote Stream: \(track.id)")
            Spacer()
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
