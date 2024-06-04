//
//  Comparable.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 6/3/24.
//

import Foundation

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
