//
//  WebRTCDelegateManager.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/25/24.
//

import Foundation
import WebRTC

// just implent all the relevant delegate methods for the webRTC client
class WebRTCStateManager: WebRTCClientDelegate, SignalingClientDelegate, ObservableObject {
    
    let webRTCClient: WebRTCClient
    let signalingClient: SignalingClient
    
    @Published var localCandidateCount = 0
    @Published var connectionState: RTCIceConnectionState = .new
    @Published var receivedData: Data?
    @Published var connectionStatusLabel: String = "New"
    
    @Published var signalingConnected = false
    @Published var hasRemoteSdp = false
    @Published var remoteCandidateCount = 0
    @Published var hasLocalSdp = false
    @Published var peerConnectionStatus: String = ""
    
    @Published var currentStreams: [RTCMediaStream] = []
    @Published var dataChannels: [ActiveRTCDataChannel] = []
    
    init(webRTCClient: WebRTCClient, signalingClient: SignalingClient) {
        self.signalingClient = signalingClient
        self.webRTCClient = webRTCClient
        
        webRTCClient.delegate = self
        signalingClient.delegate = self
    }
    
    func connect() {
        self.signalingClient.connect()
    }
    
    func signalingClientDidConnect(_ signalClient: SignalingClient) {
        DispatchQueue.main.async {
            self.signalingConnected = true
        }
    }
    
    func signalingClientDidDisconnect(_ signalClient: SignalingClient) {
        DispatchQueue.main.async {
            self.signalingConnected = false
        }
    }
    
    func signalingClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
        self.webRTCClient.set(remoteSdp: sdp) { (error) in
            DispatchQueue.main.async {
                print("Received remote sdp")
                self.hasRemoteSdp = true
            }
        }
    }
    
//    func signalingClient(_ signalClient: SignalingClient, didSendCandidate candidate: RTCIceCandidate) {
//        self.webRTCClient.offer(
//    }
    
    func signalingClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate) {
        self.webRTCClient.set(remoteCandidate: candidate) { error in
            print("Received remote candidate")
            DispatchQueue.main.async {
                self.remoteCandidateCount += 1
            }
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        DispatchQueue.main.async {
            print("discovered local candidate \(candidate.sdp)")
            self.localCandidateCount += 1
        }
        self.signalingClient.send(candidate: candidate)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        DispatchQueue.main.async {
            self.connectionState = state
            self.connectionStatusLabel = state.description.capitalized
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        DispatchQueue.main.async {
            let message = String(data: data, encoding: .utf8) ?? "(Binary: \(data.count) bytes)"
            print("Received message: \(message)")
            self.receivedData = data
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didRemoveStream stream: RTCMediaStream) {
        DispatchQueue.main.async {
            self.currentStreams.append(stream)
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didAddStream stream: RTCMediaStream) {
        DispatchQueue.main.async {
            if let index = self.currentStreams.firstIndex(of: stream) {
                self.currentStreams.remove(at: index)
            }
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, peerConnectionUpdate update: String) {
        DispatchQueue.main.async {
            self.peerConnectionStatus = update
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, remoteDataChannelAdded dataChannel: ActiveRTCDataChannel) {
        print("Remote data channel added: \(dataChannel)")
        DispatchQueue.main.async {
            self.dataChannels.append(dataChannel)
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, dataChannelDidChangeState dataChannel: RTCDataChannel) {
        print("Data channel state changed: \(dataChannel.label) -> \(dataChannel.readyState)")
    }
    
    func createOffer() {
        self.webRTCClient.offer { (sdp) in
            DispatchQueue.main.async {
                self.hasLocalSdp = true
            }
            self.signalingClient.send(sdp: sdp)
        }
    }
    
    func createAnswer() {
        self.webRTCClient.answer { (localSdp) in
            DispatchQueue.main.async {
                self.hasLocalSdp = true
            }
            self.signalingClient.send(sdp: localSdp)
        }
    }
    
    func startCaptureLocalVideo(renderer: RTCVideoRenderer) {
        self.webRTCClient.startCaptureLocalVideo(renderer: renderer, trackId: "video0")
    }
    
    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        self.webRTCClient.renderRemoteVideo(to: renderer)
    }
}
