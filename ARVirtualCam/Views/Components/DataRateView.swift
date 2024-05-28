//
//  DataRateView.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/27/24.
//

import Foundation
import SwiftUI

struct DataRateView: View {
    @Binding var dataRate: Double
    
    var body: some View {
        Text(formattedDataRate)
            .font(.system(.body, design: .monospaced))
    }
    
    private var formattedDataRate: String {
        let (value, unit) = formatDataRate(dataRate)
        return String(format: "%.2f %@", value, unit)
    }
    
    private func formatDataRate(_ dataRate: Double) -> (Double, String) {
        if dataRate < 1024 {
            return (dataRate, "B/s")
        } else if dataRate < 1024 * 1024 {
            return (dataRate / 1024, "kB/s")
        } else if dataRate < 1024 * 1024 * 1024 {
            return (dataRate / (1024 * 1024), "MB/s")
        } else {
            return (dataRate / (1024 * 1024 * 1024), "GB/s")
        }
    }
}
