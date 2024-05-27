//
//  SignalClientDelegateManager.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/25/24.
//

import Foundation
import WebRTC

class ObservableSignalClientDelegate: SignalClientDelegate, ObservableObject {
    @Published var signalingConnected = false
    @Published var hasRemoteSdp = false
    @Published var remoteCandidateCount = 0
    private var webRTCClient: WebRTCClient
    
    init(webRTCClient: WebRTCClient) {
        self.webRTCClient  = webRTCClient
    }
    
    func signalClientDidConnect(_ signalClient: SignalingClient) {
        self.signalingConnected = true
    }
    
    func signalClientDidDisconnect(_ signalClient: SignalingClient) {
        self.signalingConnected = false
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
        print("Received remote sdp")
        self.webRTCClient.set(remoteSdp: sdp) { (error) in
            self.hasRemoteSdp = true
        }
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate) {
        self.webRTCClient.set(remoteCandidate: candidate) { error in
            print("Received remote candidate")
            self.remoteCandidateCount += 1
        }
    }
}
