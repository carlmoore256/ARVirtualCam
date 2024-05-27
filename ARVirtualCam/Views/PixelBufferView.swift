//
//  DepthVideoView.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/27/24.
//

import SwiftUI
import AppKit
import Foundation

struct PixelBufferView: NSViewRepresentable {
    @ObservedObject var pixelBufferChannel: CVPixelBufferDataChannel
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        pixelBufferChannel.onPixelBufferUpdate = { pixelBuffer in
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                let nsImage = NSImage(cgImage: cgImage, size: nsView.bounds.size)
                nsView.image = nsImage
            }
        }
    }
}
