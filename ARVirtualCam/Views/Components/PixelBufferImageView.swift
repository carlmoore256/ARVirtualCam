//
//  PixelBufferImageView.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/26/24.
//

import Foundation
import SwiftUI

struct PixelBufferImageView: View {
    let pixelBuffer: CVPixelBuffer
    
    var body: some View {
        if let cgImage = createCGImage(from: pixelBuffer) {
            Image(decorative: cgImage, scale: 1.0, orientation: .up)
                .resizable()
                .scaledToFit()
        } else {
            Text("Unable to render image")
        }
    }
    
    func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
