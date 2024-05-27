//
//  BundleLocator.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/24/24.
//

import Foundation

class BundleLocator {
    static func extensionBundle() -> Bundle {
        let extensionsDirectoryURL = URL(
            fileURLWithPath: "Contents/Library/SystemExtensions",
            relativeTo: Bundle.main.bundleURL
        )

        let extensionURLs: [URL]
        do {
            extensionURLs = try FileManager.default.contentsOfDirectory(
                at: extensionsDirectoryURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
        } catch {
            fatalError("Failed to retrieve contents of directory: \(error)")
        }

        guard let extensionURL = extensionURLs.first else {
            fatalError("No extensions found.")
        }
        
        guard let extensionBundle = Bundle(url: extensionURL) else {
            fatalError("Failed to load extension bundle from URL: \(extensionURL)")
        }

        return extensionBundle
    }
}
