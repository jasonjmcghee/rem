//
//  remApp.swift
//  rem
//
//  Created by Jason McGhee on 12/16/23.
//

import SwiftUI
import AppKit
import ScreenCaptureKit
import Vision
import VisionKit
import CoreGraphics

final class MainWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
}

@main
struct remApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene, as we are controlling everything through the AppDelegate
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var timelineViewWindow: NSWindow?
    var timelineView = TimelineView(viewModel: TimelineViewModel())

    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    
    var searchViewWindow: NSWindow?
    var searchView: SearchView?

    var lastCaptureTime = Date()
    
    var screenCaptureSession: SCStream?
    var captureOutputURL: URL?
    
    var lastVideoEncodingTime = Date()
    let chunkSizeSeconds = TimeInterval(300)
    
    let idleStatusImage = NSImage(named: "StatusIdle")
    let recordingStatusImage = NSImage(named: "StatusRecording")
    
    let ocrQueue = DispatchQueue(label: "today.jason.ocrQueue", attributes: .concurrent)
    var imageBufferQueue = DispatchQueue(label: "today.jason.imageBufferQueue", attributes: .concurrent)
    var imageDataBuffer = [Data]()
    var ffmpegTimer: Timer?
    var screenshotTimer: Timer?
    private let frameThreshold = 300 // Number of frames after which FFmpeg processing is triggered
    
    private var ffmpegProcess: Process?
    private var ffmpegInputPipe: Pipe?
    
    private let processingQueue = DispatchQueue(label: "today.jason.processingQueue", attributes: .concurrent)
    private var pendingScreenshotURLs = [URL]()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let _ = DatabaseManager.shared

        // Initialize the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 360)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())

        // Create the status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Setup Menu
        setupMenu()
        
        // Monitor for scroll events
        NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] (event) in
            self?.handleGlobalScrollEvent(event)
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] (event) in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 3 {
                self?.showSearchView()
            }
            
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 0 {
                LLM.shared.ask(query: "how's it going?")
            }
            
            if (self?.searchViewWindow?.isVisible ?? false) && event.keyCode == 53 {
                self?.closeSearchView()
            }
            return event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] (event) in
            guard !event.modifierFlags.contains(.command) else { return event }

            if event.scrollingDeltaX != 0 {
                self?.timelineView.viewModel.updateIndex(withDelta: event.scrollingDeltaX)
            }
            return event
        }
        
        // Initialize the search view
        searchView = SearchView(onThumbnailClick: openFullView)
    }
    
    func setupMenu() {
        DispatchQueue.main.async {
            if let button = self.statusBarItem.button {
                button.image = self.isCapturing ? self.recordingStatusImage : self.idleStatusImage
                button.action = #selector(self.togglePopover(_:))
            }
            let menu = NSMenu()
            let recordingTitle = self.isCapturing ? "Stop Remembering" : "Start Remembering"
            let recordingSelector = self.isCapturing ? #selector(self.disableRecording) : #selector(self.enableRecording)
            menu.addItem(NSMenuItem(title: recordingTitle, action: recordingSelector, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Open Timeline", action: #selector(self.showTimelineView), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Search", action: #selector(self.showSearchView), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Copy Recent Context", action: #selector(self.copyRecentContext), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "⚠️ Purge All Data ⚠️", action: #selector(self.confirmPurgeAllData), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator()) // Separator
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(self.quitApp), keyEquivalent: "q"))
            self.statusBarItem.menu = menu
        }
    }
    
    @objc func confirmPurgeAllData() {
        let alert = NSAlert()
        alert.messageText = "Purge all data?"
        alert.informativeText = "This is a permanent action and will delete everything rem has every seen."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Yes, delete everything")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            self.forgetEverything()
        }
    }
    
    private func handleGlobalScrollEvent(_ event: NSEvent) {
        guard event.modifierFlags.contains(.command) else { return }
        
        if event.scrollingDeltaX < 0 && !(timelineViewWindow?.isVisible ?? false) { // Check if scroll up
            DispatchQueue.main.async { [weak self] in
                self?.showTimelineView()
            }
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusBarItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    private let serialQueue = DispatchQueue(label: "today.jason.recordingBufferQueue")

    private var isCapturing = false
    private let screenshotQueue = DispatchQueue(label: "today.jason.screenshotQueue")

    func startScreenCapture() async {        
        do {
            let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

            isCapturing = true
            setupMenu()
            screenshotQueue.async { [weak self] in
                self?.scheduleScreenshot(shareableContent: shareableContent)
            }
        } catch {
            print("Error starting screen capture: \(error.localizedDescription)")
        }
    }
    
    @objc private func copyRecentContext() {
        let texts = DatabaseManager.shared.getRecentTextContext()
        let text = TextMerger.shared.mergeTexts(texts: texts)
        ClipboardManager.shared.replaceClipboardContents(with: text)
    }

    private func scheduleScreenshot(shareableContent: SCShareableContent) {
        guard isCapturing else { return }
        
        Task {
            guard let display = shareableContent.displays.first else { return }

            let window = shareableContent.windows.first { $0.isActive }
            let activeApplicationName = window?.owningApplication?.applicationName
            
            // Do we want to record the timeline being searched?
            guard let image = CGDisplayCreateImage(display.displayID, rect: display.frame) else { return }
            let frameId = DatabaseManager.shared.insertFrame(activeApplicationName: activeApplicationName)
            
            if (!isTimelineOpen()) {
                // Make sure to set timeline to be the latest frame
                await self.timelineView.viewModel.setIndexToLatest()
            }
            
            await processScreenshot(frameId: frameId, image: image, frame: display.frame)
            
            screenshotQueue.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.scheduleScreenshot(shareableContent: shareableContent)
            }
        }
    }
    
    @objc func forgetEverything() {
        if let savedir = RemFileManager.shared.getSaveDir() {
            if FileManager.default.fileExists(atPath: savedir.path) {
                do {
                    try FileManager.default.removeItem(at: savedir)
                } catch {
                    print("Error deleting folder: \(error)")
                }
            } else {
                print("Error finding folder.")
            }
        }
        DatabaseManager.shared.reconnect()
    }
    
    func stopScreenCapture() {
        isCapturing = false
        self.timelineView.viewModel.setIndexToLatest()
        print("Screen capture stopped")
    }
    
//    // Old method
//    func takeScreenshot(filter: SCContentFilter, configuration: SCStreamConfiguration, frame: CGRect) async {
//        do {
//            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
//            await processScreenshot(image: image, frame: frame)
//        } catch {
//            print("Error taking screenshot: \(error.localizedDescription)")
//        }
//    }
    
    private func processScreenshot(frameId: Int64, image: CGImage, frame: CGRect) async {
        self.performOCR(frameId: frameId, on: image, frame: frame)
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let data = bitmapRep.representation(using: .png, properties: [:]) else { return }
        
        imageBufferQueue.async(flags: .barrier) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.imageDataBuffer.append(data)

            // If the buffer reaches the threshold, process the chunk
            if strongSelf.imageDataBuffer.count >= strongSelf.frameThreshold {
                let chunk = Array(strongSelf.imageDataBuffer.prefix(strongSelf.frameThreshold))
                strongSelf.imageDataBuffer.removeFirst(strongSelf.frameThreshold)
                strongSelf.processChunk(chunk)
            }
        }
    }
    
    private func processChunk(_ chunk: [Data]) {
        // Create a unique output file for each chunk
        if let savedir = RemFileManager.shared.getSaveDir() {
            let outputPath = savedir.appendingPathComponent("output-\(Date().timeIntervalSince1970).mp4").path
            
            DatabaseManager.shared.startNewVideoChunk(filePath: outputPath)
            
            // Setup the FFmpeg process for the chunk
            let ffmpegProcess = Process()
            guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: "") else {
                print("FFmpeg binary not found in the bundle.")
                return
            }
            ffmpegProcess.executableURL = URL(fileURLWithPath: ffmpegPath)
            ffmpegProcess.arguments = [
                "-f", "image2pipe",
                "-i", "-",
                "-color_trc", "iec61966_2_1", // Set transfer characteristics for sRGB (approximates 2.2 gamma)
                "-c:v", "h264_videotoolbox",
                "-crf", "25",
                outputPath
            ]
            let ffmpegInputPipe = Pipe()
            ffmpegProcess.standardInput = ffmpegInputPipe
            
            // Start the FFmpeg process
            do {
                try ffmpegProcess.run()
            } catch {
                print("Failed to start FFmpeg process for chunk: \(error)")
                return
            }
            
            // Write the chunk data to the FFmpeg process
            for (index, data) in chunk.enumerated() {
                ffmpegInputPipe.fileHandleForWriting.write(data)
            }
            
            // Close the pipe and let the process run to completion
            ffmpegInputPipe.fileHandleForWriting.closeFile()
        } else {
            print("Failed to save ffmpeg video")
        }
    }

    @objc func enableRecording() {
        Task {
            await startScreenCapture()
        }
    }
    
    @objc func disableRecording() {
        // Stop screen capture
        stopScreenCapture()
        
        Task {
            // Process any remaining frames in the buffer
            imageBufferQueue.sync { [weak self] in
                guard let strongSelf = self else { return }
                
                if !strongSelf.imageDataBuffer.isEmpty {
                    strongSelf.processChunk(strongSelf.imageDataBuffer)
                    strongSelf.imageDataBuffer.removeAll()
                }
            }
        }
        
        setupMenu()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }

    
    private func performOCR(frameId: Int64, on image: CGImage, frame: CGRect) {
        ocrQueue.async {
            // Select only a region... / active window?
//            let invWidth = 1 / CGFloat(image.width)
//            let invHeight = 1 / CGFloat(image.height)
//            let regionOfInterest = CGRect(
//                x: min(max(0, frame.minX * invWidth), 1),
//                y: min(max(0, frame.minY * invHeight), 1),
//                width: min(max(0, frame.width * invWidth), 1),
//                height: min(max(0, frame.height * invHeight), 1)
//            )
            Task {
                do {
                    let configuration = ImageAnalyzer.Configuration([.text])
                    let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                    let analysis = try await ImageAnalyzer().analyze(nsImage, orientation: CGImagePropertyOrientation.up, configuration: configuration)
                    let textToAssociate = analysis.transcript
                    let newClipboardText = ClipboardManager.shared.getClipboardIfChanged() ?? ""
                    DatabaseManager.shared.insertTextForFrame(frameId: frameId, text: [textToAssociate, newClipboardText].joined(separator: "\n"))
                    // print(textToAssociate)
                } catch {
                    print("OCR error: \(error.localizedDescription)")
                }
            }
            
            
            // Old method
//            let request = VNRecognizeTextRequest { [weak self] request, error in
//                guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
//                    print("OCR error: \(error?.localizedDescription ?? "Unknown error")")
//                    return
//                }
//
//                let topK = 1
//                let recognizedStrings = observations.compactMap { observation in
//                    observation.topCandidates(topK).first?.string
//                }.joined(separator: "\n")
//                
//                DatabaseManager.shared.insertTextForFrame(frameId: frameId, text: recognizedStrings)
//            }
//            
//            request.recognitionLevel = .accurate
////            request.regionOfInterest = regionOfInterest
//
//            let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
//            do {
//                try requestHandler.perform([request])
//            } catch {
//                print("Failed to perform OCR: \(error.localizedDescription)")
//            }
        }
    }

    private func saveOCRResult(_ text: String, forImageURL imageURL: URL) {
        // Here you can save the OCR results along with the image URL to the database
        // For simplicity, we're just printing it
        print("OCR Result for \(imageURL.lastPathComponent): \(text)")
    }
    
    private func processImageDataBuffer() {
        // Temporarily store the buffered data and clear the buffer
        let tempBuffer = imageDataBuffer
        imageDataBuffer.removeAll()

        // Write the buffered data to the FFmpeg process
        tempBuffer.forEach {
            ffmpegInputPipe?.fileHandleForWriting.write($0)
        }
    }
    
    @objc func showTimelineView() {
        if timelineViewWindow == nil {
            let screenRect = NSScreen.main?.frame ?? NSRect.zero
            timelineViewWindow = MainWindow(
                contentRect: screenRect,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            timelineViewWindow?.hasShadow = false
            timelineViewWindow?.level = .normal

            timelineViewWindow?.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces, .participatesInCycle]
            timelineViewWindow?.ignoresMouseEvents = false
            timelineViewWindow?.contentView = NSHostingView(rootView: timelineView)
            timelineViewWindow?.orderFrontRegardless() // Ensure it comes to the front

        } else if (!(timelineViewWindow?.isVisible ?? false)) {
            self.timelineViewWindow?.contentView?.subviews.first?.subviews.first?.enterFullScreenMode(NSScreen.main!)
            timelineViewWindow?.makeKeyAndOrderFront(nil)
            timelineViewWindow?.orderFrontRegardless() // Ensure it comes to the front
        }
    }
    
    private func isTimelineOpen() -> Bool {
        return self.timelineViewWindow?.contentView?.subviews.first?.subviews.first?.isInFullScreenMode ?? false
    }
    
    func openFullView(atIndex index: Int64) {
        self.timelineView.viewModel.updateIndex(withIndex: index)
        closeSearchView()
        self.showTimelineView()
    }
    
    func closeSearchView() {
        searchViewWindow?.isReleasedWhenClosed = false
        searchViewWindow?.close()
    }
    
    @objc func showSearchView() {
        // Ensure that the search view window is created and shown
        if searchViewWindow == nil {
            let screenRect = NSScreen.main?.frame ?? NSRect.zero
            searchViewWindow = MainWindow(
                contentRect: screenRect,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered, defer: false)
            searchViewWindow?.hasShadow = false
            searchViewWindow?.ignoresMouseEvents = false

            searchViewWindow?.center()
            searchViewWindow?.contentView = NSHostingView(rootView: searchView)
            searchViewWindow?.makeKeyAndOrderFront(nil)
            searchViewWindow?.orderFrontRegardless() // Ensure it comes to the front
            
        } else if (!(searchViewWindow?.isVisible ?? false)) {
            searchViewWindow?.makeKeyAndOrderFront(nil)
            searchViewWindow?.orderFrontRegardless() // Ensure it comes to the front
        }
    }
}
