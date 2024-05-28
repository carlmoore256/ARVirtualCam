//
//  WebRTCClient.swift
//  WebRTC
//
//  Created by Stasel on 20/05/2018.
//  Copyright © 2018 Stasel. All rights reserved.
//

import Foundation
import WebRTC

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data)
    func webRTCClient(_ client: WebRTCClient, didAddStream stream: RTCMediaStream)
    func webRTCClient(_ client: WebRTCClient, didRemoveStream stream: RTCMediaStream)
    func webRTCClient(_ client: WebRTCClient, peerConnectionUpdate update: String)
    func webRTCClient(_ client: WebRTCClient, remoteDataChannelAdded dataChannel: ActiveRTCDataChannel)
    func webRTCClient(_ client: WebRTCClient, dataChannelDidChangeState dataChannel: RTCDataChannel)
//    func webRTCClient(_ client: WebRTCClient, didAddVideoTrack videoTrack: RemoteRTCVideoTrack)
//    func webRTCClient(_ client: WebRTCClient, didRemoteVideoTrack videoTrack: RemoteRTCVideoTrack)

}

protocol ActiveRTCVideoTrack : Identifiable {
    var id: String { get }
    var track: RTCVideoTrack { get }
    var isLocal: Bool { get }
}

struct LocalRTCVideoTrack: ActiveRTCVideoTrack {
    let id: String
    var track: RTCVideoTrack
    var source: RTCVideoSource
    var capturer: FrameVideoCapturer
    var isLocal = true
    
    init(track: RTCVideoTrack, source: RTCVideoSource, capturer: FrameVideoCapturer) {
        self.id = track.trackId
        self.track = track
        self.source = source
        self.capturer = capturer
    }
}

struct RemoteRTCVideoTrack: ActiveRTCVideoTrack {
    let id: String
    var track: RTCVideoTrack
    var isLocal = false
    
    init(track: RTCVideoTrack) {
        self.id = track.trackId
        self.track = track
    }
}

class ActiveRTCDataChannel : Identifiable, Equatable  {
    let id: String = UUID().uuidString
    let label: String
    let channel: RTCDataChannel
    var delegate: RTCDataChannelDelegate?
    let isLocal: Bool
    
    
    init(channel: RTCDataChannel, isLocal: Bool) {
        self.channel = channel
        self.isLocal = isLocal
        self.label = channel.label
    }
    
    init(channel: RTCDataChannel, isLocal: Bool, delegate: RTCDataChannelDelegate?) {
        self.channel = channel
        self.isLocal = isLocal
        self.delegate = delegate
        self.channel.delegate = self.delegate
        self.label = channel.label
    }
    
    func setDelegate(delegate: RTCDataChannelDelegate) {
        self.delegate = delegate
        channel.delegate = delegate
    }
    
    
    static func == (lhs: ActiveRTCDataChannel, rhs: ActiveRTCDataChannel) -> Bool {
        lhs.id == rhs.id
    }
}

final class WebRTCClient: NSObject {
    
    // The `RTCPeerConnectionFactory` is in charge of creating new RTCPeerConnection instances.
    // A new RTCPeerConnection should be created every new call, but the factory is shared.
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()
    
    weak var delegate: WebRTCClientDelegate?
    private var peerConnection: RTCPeerConnection
    private let mediaConstrains =  [kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue]
    private var videoCapturer: RTCVideoCapturer?
    
    var localVideoTracks: [String: LocalRTCVideoTrack] = [:]
    var remoteVideoTracks: [String: RemoteRTCVideoTrack] = [:]
    
    var localDataChannels: [String: ActiveRTCDataChannel] = [:]
    var remoteDataChannels: [String: ActiveRTCDataChannel] = [:]
    
    private var streamId: String
    private var iceServers: [String]
    
    @available(*, unavailable)
    override init() {
        fatalError("WebRTCClient:init is unavailable")
    }
    
    required init(iceServers: [String], streamId: String) {
        self.iceServers = iceServers
        self.streamId = streamId
        
        self.peerConnection = WebRTCClient.createPeerConnection(iceServers: iceServers)
        super.init()
        
        self.createMediaSenders()
        // self.configureAudioSession()
        self.peerConnection.delegate = self
    }
    
    private static func createPeerConnection(iceServers: [String]) -> RTCPeerConnection {
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: iceServers)]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                              optionalConstraints: ["DtlsSrtpKeyAgreement":kRTCMediaConstraintsValueTrue])
        return WebRTCClient.factory.peerConnection(with: config, constraints: constraints, delegate: nil)!
    }
    
    
    func reinitializeConnection() {
        self.peerConnection = WebRTCClient.createPeerConnection(iceServers: iceServers)
        self.createMediaSenders()
        self.peerConnection.delegate = self
    }
    
    // MARK: Signaling
    func offer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        let constrains = RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains,
                                             optionalConstraints: nil)
        
        self.peerConnection.offer(for: constrains) { (sdp, error) in
            guard let sdp = sdp else {
                return
            }
            
            self.peerConnection.setLocalDescription(sdp, completionHandler: { (error) in
                completion(sdp)
            })
        }
    }
    
    func answer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void)  {
        let constrains = RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains,
                                             optionalConstraints: nil)
        self.peerConnection.answer(for: constrains) { (sdp, error) in
            guard let sdp = sdp else {
                return
            }
            
            
            self.peerConnection.setLocalDescription(sdp, completionHandler: { (error) in
                completion(sdp)
            })
        }
    }
    
    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> ()) {
        self.peerConnection.setRemoteDescription(remoteSdp, completionHandler: completion)
    }
    
    func set(remoteCandidate: RTCIceCandidate, completion: @escaping (Error?) -> ()) {
        self.peerConnection.add(remoteCandidate, completionHandler: completion)
    }
    
    
    func startCaptureLocalVideo(renderer: RTCVideoRenderer, trackId: String) {
        guard let capturer = self.videoCapturer as? RTCCameraVideoCapturer else {
            return
        }
        
        guard let track = self.localVideoTracks[trackId] else {
            print("No track with the id: \(trackId)")
            return
        }
        
        guard
            let frontCamera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == .front }),
            
                // choose highest res
            let format = (RTCCameraVideoCapturer.supportedFormats(for: frontCamera).sorted { (f1, f2) -> Bool in
                let width1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription).width
                let width2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription).width
                return width1 < width2
            }).last,
            
                // choose highest fps
            let fps = (format.videoSupportedFrameRateRanges.sorted { return $0.maxFrameRate < $1.maxFrameRate }.last) else {
            return
        }
        
        capturer.startCapture(with: frontCamera,
                              format: format,
                              fps: Int(fps.maxFrameRate))
        
        track.track.add(renderer)
    }
    
    func getRemoteVideoTrack(trackId: String) -> LocalRTCVideoTrack? {
        guard let activeVideoTrack = self.localVideoTracks[trackId] else {
            print("No video track found with id \(trackId)")
            return nil
        }
        return activeVideoTrack
    }
    
    func getRemoteDataChannel(label: String) -> ActiveRTCDataChannel? {
        guard let dataChannel = self.remoteDataChannels[label] else {
            print("No data channel with the label \(label)")
            return nil
        }
        return dataChannel
    }
    
    
    func renderRemoteVideo(to renderer: RTCVideoRenderer, trackId: String) {
        guard let videoTrack = self.remoteVideoTracks[trackId] else {
            print("No video track found with id \(trackId)")
            return
        }
        videoTrack.track.add(renderer)
    }
    
    func disconnect() {
        localVideoTracks.values.forEach { track in
            track.track.isEnabled = false
        }
        localVideoTracks.removeAll()
        peerConnection.close()
    }
    
    
    
    private func createMediaSenders() {
        // // Audio
        // let audioTrack = self.createAudioTrack()
        // self.peerConnection.add(audioTrack, streamIds: [self.streamId])
        
        // Video
        self.createVideoTrack(trackId: "color")
        // self.createVideoTrack(trackId: "depth")
        
        // self.remoteVideoTrack = self.peerConnection.transceivers.first { $0.mediaType == .video }?.receiver.track as? RTCVideoTrack
        
        // Data
        createDataChannel(label: "foobar")
    }
    
    private func createVideoTrack(trackId: String) {
        let videoSource = WebRTCClient.factory.videoSource()
        let videoTrack = WebRTCClient.factory.videoTrack(with: videoSource, trackId: trackId)
        let videoCapturer = FrameVideoCapturer(videoSource: videoSource)
        self.localVideoTracks[trackId] = LocalRTCVideoTrack(track: videoTrack, source: videoSource, capturer: videoCapturer)
        self.peerConnection.add(videoTrack, streamIds: [self.streamId])
    }
    
    func feedFrameToVideoTrack(pixelBuffer: CVPixelBuffer, timeStamp: CMTime, trackId: String, fps: Int32 = 30) {
        guard let activeVideoTrack = self.localVideoTracks[trackId] else {
            debugPrint("No video track found with id \(trackId)")
            return
        }
        activeVideoTrack.capturer.capture(pixelBuffer: pixelBuffer, timeStamp: timeStamp, fps: fps)
    }
    
    func createDataChannel(label: String) {
        let config = RTCDataChannelConfiguration()
        config.isOrdered = true  // Ensures data is received in the order it was sent
        config.isNegotiated = false  // Let WebRTC negotiate the channel automatically
        
        if let dataChannel = self.peerConnection.dataChannel(forLabel: label, configuration: config) {
            let activeDataChannel = ActiveRTCDataChannel(channel: dataChannel, isLocal: true, delegate: DataChannelDelegate())
            self.localDataChannels[label] = activeDataChannel
            print("Data Channel created successfully.")
        } else {
            print("Warning: Couldn't create data channel.")
        }
    }
    
    func sendData(_ data: Data, channel: String = "WebRTCData") {
        let buffer = RTCDataBuffer(data: data, isBinary: true)
        guard let dataChannel = self.remoteDataChannels[channel] else {
            print("No data channel with the label \(channel)")
            return
        }
        dataChannel.channel.sendData(buffer)
    }
}

extension WebRTCClient: RTCPeerConnectionDelegate {
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        debugPrint("peerConnection new signaling state: \(stateChanged)")
        self.delegate?.webRTCClient(self, peerConnectionUpdate: "New signaling state: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        debugPrint("peerConnection added stream", stream, "id", stream.streamId)
        for track in stream.videoTracks {
            print("Remote video track added: \(track.trackId)")
            remoteVideoTracks[track.trackId] = RemoteRTCVideoTrack(track: track)
        }
        self.delegate?.webRTCClient(self, didAddStream: stream)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        debugPrint("peerConnection did remove stream")
//        for track in stream.videoTracks {
//              TODO: remove remote video streams
//        }
        self.delegate?.webRTCClient(self, didRemoveStream: stream)
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        debugPrint("peerConnection should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        debugPrint("peerConnection new connection state: \(newState)")
        self.delegate?.webRTCClient(self, didChangeConnectionState: newState)
        self.delegate?.webRTCClient(self, peerConnectionUpdate: "New ICE Connection state: \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        debugPrint("peerConnection new gathering state: \(newState)")
        self.delegate?.webRTCClient(self, peerConnectionUpdate: "New ICE Gathering state: \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        self.delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        debugPrint("peerConnection did remove candidate(s)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        debugPrint("peerConnection did open data channel")
        let remoteDataChannel = ActiveRTCDataChannel(channel: dataChannel, isLocal: false)
        self.remoteDataChannels[dataChannel.label] = remoteDataChannel
        self.delegate?.webRTCClient(self, remoteDataChannelAdded: remoteDataChannel)
    }
}


class DataChannelDelegate: NSObject, RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print("DataChannelDelegate: dataChannel \(dataChannel.label) did change state: \(dataChannel.readyState)")
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        debugPrint("DataChannelDelegate: dataChannel \(dataChannel.label) received data")
    }
}


extension WebRTCClient {
    private func setTrackEnabled<T: RTCMediaStreamTrack>(_ type: T.Type, isEnabled: Bool) {
        peerConnection.transceivers
            .compactMap { return $0.sender.track as? T }
            .forEach { $0.isEnabled = isEnabled }
    }
}

// MARK: - Video control
extension WebRTCClient {
    func hideVideo() {
        self.setVideoEnabled(false)
    }
    func showVideo() {
        self.setVideoEnabled(true)
    }
    private func setVideoEnabled(_ isEnabled: Bool) {
        setTrackEnabled(RTCVideoTrack.self, isEnabled: isEnabled)
    }
}
