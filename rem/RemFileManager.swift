//
//  FileManager.swift
//  rem
//
//  Created by Jason McGhee on 12/26/23.
//

import Foundation
import os

class RemFileManager {
    private let logger = Logger()
    static let shared: RemFileManager = RemFileManager()
    
    func getSaveDir() -> URL? {
        let fileManager = FileManager.default
        
        // Get the base directory URL
        if let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            
            // Create a subdirectory URL within the base directory
            let subdirectory = baseDirectory.appendingPathComponent("today.jason.rem")
            
            // Check if the subdirectory exists
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: subdirectory.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Subdirectory already exists
                    return subdirectory
                }
            }
            
            // Create the subdirectory if it doesn't exist
            do {
                try fileManager.createDirectory(at: subdirectory, withIntermediateDirectories: true, attributes: nil)
                return subdirectory
            } catch {
                logger.error("Error creating subdirectory: \(error)")
            }
        }
        
        return nil
    }
}
