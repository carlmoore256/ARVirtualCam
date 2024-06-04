//
//  Config.swift
//  ARVirtualCamExtension
//
//  Created by Carl Moore on 5/25/24.
//
import Foundation

let kFrameRate: Int = 60
let cameraName = "Sample Camera"
let fixedCamWidth: Int32 = 320
let fixedCamHeight: Int32 = 240

//let fixedCamWidth: Int32 = 1280
//let fixedCamHeight: Int32 = 720

let defaultSignalingServerUrl = URL(string: "ws://192.168.1.242:8080")!
let defaultIceServers = ["stun:stun.l.google.com:19302",
                         "stun:stun1.l.google.com:19302",
                         "stun:stun2.l.google.com:19302",
                         "stun:stun3.l.google.com:19302",
                         "stun:stun4.l.google.com:19302"]

let defaultStreamId = "stream"


struct WebRTCConfig {
    let signalingServerUrl: URL
    let iceServers: [String]
    let streamId: String
    
    static let `default` = WebRTCConfig(signalingServerUrl: defaultSignalingServerUrl, iceServers: defaultIceServers, streamId: defaultStreamId)
}
