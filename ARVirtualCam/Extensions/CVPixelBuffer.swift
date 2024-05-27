//
//  CVPixelBuffer.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/27/24.
//

import Foundation
import VideoToolbox

extension CVPixelBuffer {
    func toCGImage() -> CGImage? {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(self, options: nil, imageOut: &cgImage)
        return cgImage
    }
}

