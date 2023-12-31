//
//  ImageHelper.swift
//  rem
//
//  Created by Jason McGhee on 12/31/23.
//

import Foundation
import os
import SwiftUI

class ImageHelper {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ImageHelper.self)
    )
    
    // Useful for debugging...
    static func pngData(from nsImage: NSImage) -> Data? {
        guard let tiffRepresentation = nsImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            logger.error("Failed to get TIFF representation of NSImage")
            return nil
        }
        
        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            logger.error("Failed to convert NSImage to PNG")
            return nil
        }
        
        return pngData
    }
    
    static func saveNSImage(image: NSImage, path: String) {
        let pngData = pngData(from: image)
        do {
            if let savedir = RemFileManager.shared.getSaveDir() {
                let outputPath = savedir.appendingPathComponent("\(path).png").path
                let fileURL = URL(fileURLWithPath: outputPath)
                try pngData?.write(to: fileURL)
                logger.info("PNG file written successfully")
            } else {
                logger.error("Error writing PNG file")
            }
        } catch {
            logger.error("Error writing PNG file: \(error)")
        }
    }
}
