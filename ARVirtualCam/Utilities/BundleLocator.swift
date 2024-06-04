//
//  BundleLocator.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/24/24.
//

import Foundation

class BundleLocator {
    static func getExtensionBundles() -> [Bundle]  {
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
        
        if extensionURLs.count == 0 {
            fatalError("Failed to find any system extensions")
        }
        
        var bundles: [Bundle] = []
        
        for url in extensionURLs {
            guard let extensionBundle = Bundle(url: url) else {
                print("Error loading url as bundle: \(url)")
                continue
            }
            if extensionBundle.bundleIdentifier == nil {
                print("Error - bundle has no identifier: \(extensionBundle)")
                continue
            }
            bundles.append(extensionBundle)
        }
        return bundles
    }
}
