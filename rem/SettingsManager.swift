//
//  SettingsManager.swift
//  rem
//
//  Created by Jason McGhee on 12/27/23.
//

import Foundation
import SwiftUI
import LaunchAtLogin

// The settings structure
struct AppSettings: Codable {
    var saveEverythingCopiedToClipboard: Bool
    var enableCmdScrollShortcut: Bool
    var onlyOCRFrontmostWindow: Bool = true
    var fastOCR: Bool = true
    var startRememberingOnStartup: Bool = false
    var recordWindowWithMouse: Bool = false
}

// The settings manager handles saving and loading the settings
class SettingsManager: ObservableObject {
    @Published var settings: AppSettings

    private let settingsKey = "appSettings"

    init() {
        // Load settings or use default values
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decodedSettings
        } else {
            // Default settings
            self.settings = AppSettings(saveEverythingCopiedToClipboard: false, enableCmdScrollShortcut: true)
        }
    }

    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading) {
            Text("Settings")
                .font(.title)
                .padding(.bottom)
            Form {
                Toggle("Launch rem and start remembering on startup", isOn: $settingsManager.settings.startRememberingOnStartup)
                    .onChange(of: settingsManager.settings.startRememberingOnStartup) { value in
                        LaunchAtLogin.isEnabled = value
                        settingsManager.saveSettings()
                    }
                Toggle("Remember everything copied to clipboard", isOn: $settingsManager.settings.saveEverythingCopiedToClipboard)
                    .onChange(of: settingsManager.settings.saveEverythingCopiedToClipboard) { _ in settingsManager.saveSettings() }
                Toggle("Allow opening / closing timeline with CMD + Scroll", isOn: $settingsManager.settings.enableCmdScrollShortcut)
                    .onChange(of: settingsManager.settings.enableCmdScrollShortcut) { _ in settingsManager.saveSettings() }
                Toggle("Only OCR region of active application window (more efficient)", isOn: $settingsManager.settings.onlyOCRFrontmostWindow)
                    .onChange(of: settingsManager.settings.onlyOCRFrontmostWindow) { _ in settingsManager.saveSettings() }
                Toggle("Use faster, but lower accuracy OCR (more efficient)", isOn: $settingsManager.settings.fastOCR)
                    .onChange(of: settingsManager.settings.fastOCR) { _ in settingsManager.saveSettings() }
                Toggle("Always record window with mouse", isOn: $settingsManager.settings.recordWindowWithMouse)
                    .onChange(of: settingsManager.settings.recordWindowWithMouse) { _ in settingsManager.saveSettings() }
            }
        }
        .padding()
    }
}

