//
//  Colors.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 6/2/24.
//

import Foundation

class ColorUtils {
    
    
    
    static func HSVtoRGB(h: Float16, s: Float16, v: Float16) -> (r: UInt8, g: UInt8, b: UInt8) {
        // Optimized HSV to RGB conversion
        let c = v * s
        let x = c * (1 - abs((h / 60.0).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        
        var r: Float16 = 0, g: Float16 = 0, b: Float16 = 0
        
        let hSegment = Int(h / 60.0) % 6
        
        switch hSegment {
        case 0:
            r = c; g = x; b = 0
        case 1:
            r = x; g = c; b = 0
        case 2:
            r = 0; g = c; b = x
        case 3:
            r = 0; g = x; b = c
        case 4:
            r = x; g = 0; b = c
        case 5:
            r = c; g = 0; b = x
        default:
            break
        }
        
        r += m
        g += m
        b += m
        
        return (
            r: UInt8(r * 255.0),
            g: UInt8(g * 255.0),
            b: UInt8(b * 255.0)
        )
    }
    
    
}
