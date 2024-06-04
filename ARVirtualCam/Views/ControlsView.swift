//
//  ContentView.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/24/24.
//

import SwiftUI

struct ControlsView: View {
    // @EnvironmentObject var cmioSourceHandler: CMIOSourceHandler
    @EnvironmentObject private var viewModel : VirtualCameraViewModel
    
    var body: some View {
        VStack(spacing: 5) {
            Toggle("Mirror Camera", isOn: $viewModel.mirrorCamera)
                .toggleStyle(SwitchToggleStyle())
                .padding()
            Text(viewModel.debugMessage)
                .padding()
        }
    }
}

struct ControlsView_Previews: PreviewProvider {
    static var previews: some View {
        ControlsView()
    }
}
