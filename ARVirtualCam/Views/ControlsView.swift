//
//  ContentView.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/24/24.
//

import SwiftUI

struct ControlsView: View {
    // @EnvironmentObject var cmioSourceHandler: CMIOSourceHandler
    @EnvironmentObject private var viewModel : VirtualCameraPluginViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Toggle("Mirror Camera", isOn: $viewModel.mirrorCamera)
                .toggleStyle(SwitchToggleStyle())
                .padding()
            
            Button("Connect to Camera", action: viewModel.connectToCamera)
                .buttonStyle(RoundedButtonStyle())
            
            Text(viewModel.debugMessage)
                .padding()
            
            Spacer()
        }
        .padding()
    }
}

struct ControlsView_Previews: PreviewProvider {
    static var previews: some View {
        ControlsView()
    }
}
