//
//  SignalClient.swift
//  WebRTC
//
//  Created by Stasel on 20/05/2018.
//  Copyright © 2018 Stasel. All rights reserved.
//

import Foundation
import WebRTC

protocol SignalingClientDelegate: AnyObject {
    func signalingClientDidConnect(_ signalClient: SignalingClient)
    func signalingClientDidDisconnect(_ signalClient: SignalingClient)
    func signalingClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription)
    func signalingClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate)
//    func signalingClient(_ signalClient: SignalingClient, didSendLocalSdp sdp: RTCSessionDescription)
//    func signalingClient(_ signalClient: SignalingClient, didSendCandidate candidate: RTCIceCandidate)
}

final class SignalingClient {
    
    var isConnected = false

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let webSocket: WebSocketProvider
    weak var delegate: SignalingClientDelegate?
    
    private var reconnectWorkItem: DispatchWorkItem?
    
    init(serverUrl: URL) {
        self.webSocket = NativeWebSocket(url: serverUrl)
    }
    
    func connect() {
        self.webSocket.delegate = self
        self.webSocket.connect()
    }
    
    func changeUrl(url: URL) {
        self.webSocket.changeUrl(url: url)
        reconnectWorkItem?.cancel()
        self.connect()
    }
    
    func send(sdp rtcSdp: RTCSessionDescription) {
        let message = Message.sdp(SessionDescription(from: rtcSdp))
        do {
            let dataMessage = try self.encoder.encode(message)
            
            self.webSocket.send(data: dataMessage)
//            self.delegate?.signalingClient(self, didSendLocalSdp: rtcSdp)
        }
        catch {
            debugPrint("Warning: Could not encode sdp: \(error)")
        }
    }
    
    func send(candidate rtcIceCandidate: RTCIceCandidate) {
        let message = Message.candidate(IceCandidate(from: rtcIceCandidate))
        do {
            let dataMessage = try self.encoder.encode(message)
            self.webSocket.send(data: dataMessage)
//            self.delegate?.signalingClient(self, didSendCandidate: rtcIceCandidate)
        }
        catch {
            debugPrint("Warning: Could not encode candidate: \(error)")
        }
    }
}


extension SignalingClient: WebSocketProviderDelegate {

    func webSocketDidConnect(_ webSocket: WebSocketProvider) {
        self.delegate?.signalingClientDidConnect(self)
        self.isConnected = true
    }
    
    func webSocketDidDisconnect(_ webSocket: WebSocketProvider) {
        self.delegate?.signalingClientDidDisconnect(self)
        reconnectWorkItem?.cancel()
        reconnectWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            debugPrint("Trying to reconnect to signaling server...")
            self.webSocket.connect()
        }
        // retry connection after 2 seconds
        if let reconnectWorkItem = reconnectWorkItem {
            DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: reconnectWorkItem)
        }
    }
    
    func webSocket(_ webSocket: WebSocketProvider, didReceiveData data: Data) {
        let message: Message
        debugPrint("data: \(data)")
        do {
            message = try self.decoder.decode(Message.self, from: data)
        }
        catch {
            debugPrint("Warning: Could not decode incoming message: \(error)")
            return
        }
        
        switch message {
        case .candidate(let iceCandidate):
            self.delegate?.signalingClient(self, didReceiveCandidate: iceCandidate.rtcIceCandidate)
        case .sdp(let sessionDescription):
            self.delegate?.signalingClient(self, didReceiveRemoteSdp: sessionDescription.rtcSessionDescription)
        }

    }
}
