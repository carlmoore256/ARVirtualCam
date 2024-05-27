//
//  InstallView.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/24/24.
//

import Foundation
import SwiftUI
import SystemExtensions

struct InstallView: View {
    
    @State private var logText: String = ""
    @ObservedObject private var delegate = SystemExtensionDelegate()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ARVirtualCam")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
  
            HStack(spacing: 10) {
                Button(action: install) {
                    Text("Install Extension")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Button(action: uninstall) {
                    Text("Uninstall Extension")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            Text(delegate.logText)
                .padding()
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(.white)
                .background(Color.black)
                .cornerRadius(8)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(20)
        .shadow(radius: 5)
    }
    
    func install() {
        guard let identifier = BundleLocator.extensionBundle().bundleIdentifier else {
            delegate.logText = "Error getting bundle identifier"
            return
        }
        let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: identifier, queue: .main)
        activationRequest.delegate = delegate
        OSSystemExtensionManager.shared.submitRequest(activationRequest)
        delegate.logText = "Attempting to install extension..."
    }
    
    func uninstall() {
        guard let identifier = BundleLocator.extensionBundle().bundleIdentifier else {
            delegate.logText = "Error getting bundle identifier"
            return
        }
        let deactivationRequest = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: identifier, queue: .main)
        deactivationRequest.delegate = delegate
        OSSystemExtensionManager.shared.submitRequest(deactivationRequest)
        delegate.logText = "Attempting to uninstall extension..."
    }
}

class SystemExtensionDelegate:  NSObject, ObservableObject, OSSystemExtensionRequestDelegate {
    @Published var logText: String = ""
    
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        debugPrint("Replacing extension version \(existing.bundleShortVersion) with \(ext.bundleShortVersion)")
        DispatchQueue.main.async {
            self.logText = "Replacing extension version \(existing.bundleShortVersion) with \(ext.bundleShortVersion)"
        }
        return .replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        debugPrint("Extension needs user approval")
        DispatchQueue.main.async {
            self.logText = "Extension needs user approval"
        }
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        debugPrint("Request finished with result: \(result.rawValue)")
        DispatchQueue.main.async {
            self.logText = "Request finished with result: \(result.rawValue)"
        }
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        debugPrint("Request failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.logText = "Request failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    InstallView()
}
