// TimelineView.swift
import SwiftUI
import AVFoundation
import VisionKit

struct TimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @State private var imageAnalysis: ImageAnalysis?
    @State private var frame: NSRect
    @State private var lastAnalyzedIndex: Int64 = -1 // To track the last analyzed index
    @State var customHostingView: CustomHostingView?
    
    private var ocrDebouncer = Debouncer(delay: 1.0)

    let overlayView = ImageAnalysisOverlayView()
    private let imageAnalyzer = ImageAnalyzer()
    
    var settingsManager: SettingsManager
    var onClose: () -> Void  // Closure to handle thumbnail click

    private var fps: Int32 = 25
    
    init(viewModel: TimelineViewModel, settingsManager: SettingsManager, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.settingsManager = settingsManager
        self.onClose = onClose
        _frame = State(initialValue: NSScreen.main?.visibleFrame ?? NSRect.zero)
        _customHostingView = State(initialValue: nil)
    }
    
    var body: some View {
        ZStack {
            let image = DatabaseManager.shared.getImage(index: viewModel.currentFrameIndex)
            let nsImage = image.flatMap { NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)) }
            
            CustomHostingControllerRepresentable(
                settingsManager: settingsManager,
                onClose: onClose,
                image: nsImage,
                analysis: $imageAnalysis,
                frame: frame
            )
                .frame(width: frame.width, height: frame.height)
                .ignoresSafeArea(.all)
                .onChange(of: viewModel.currentFrameIndex) {
                    ocrDebouncer.debounce {
                        analyzeCurrentImage()
                    }
                }
                .onAppear {
                    analyzeCurrentImage()
                }
            
        }
        .ignoresSafeArea(.all)
    }
    
    private func analyzeCurrentImage() {
        analyzeImage(index: viewModel.currentFrameIndex)
    }
    
    private func analyzeImage(index: Int64) {
        Task {
            if let image = DatabaseManager.shared.getImage(index: index) {
                let configuration = ImageAnalyzer.Configuration([.text])
                do {
                    let analysis = try await imageAnalyzer.analyze(image, orientation: CGImagePropertyOrientation.up, configuration: configuration)
                    DispatchQueue.main.async {
                        self.imageAnalysis = analysis
                        // print("Analysis successful: \(analysis.transcript)")
                    }
                } catch {
                    print("Error analyzing image: \(error)")
                }
            }
        }
    }
     
    
    // Useful for debugging...
    func pngData(from nsImage: NSImage) -> Data? {
        guard let tiffRepresentation = nsImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            print("Failed to get TIFF representation of NSImage")
            return nil
        }
        
        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("Failed to convert NSImage to PNG")
            return nil
        }
        
        return pngData
    }
    
    func saveNSImage(image: NSImage, path: String) {
        let pngData = pngData(from: image)
        do {
            if let savedir = RemFileManager.shared.getSaveDir() {
                let outputPath = savedir.appendingPathComponent("\(path).png").path
                let fileURL = URL(fileURLWithPath: outputPath)
                try pngData?.write(to: fileURL)
                print("PNG file written successfully")
            } else {
                print("Error writing PNG file")
            }
        } catch {
            print("Error writing PNG file: \(error)")
        }
    }
}

class CustomHostingView: NSHostingView<AnyView> {
    var imageView: NSImageView!
    var overlayView: ImageAnalysisOverlayView!

    init(image: NSImage, frame: NSRect) {
        super.init(rootView: AnyView(EmptyView()))

        self.imageView = NSImageView(frame: frame)
        configureImageView(with: image, in: frame)
        
        self.overlayView = ImageAnalysisOverlayView()
        setupOverlayView()  // This is now safe to call

        addSubview(imageView)
        imageView.addSubview(overlayView)
    }

    required init(rootView: AnyView) {
        super.init(rootView: rootView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureImageView(with image: NSImage, in frame: NSRect) {
        imageView.image = image
        imageView.imageScaling = .scaleAxesIndependently

        // Configuring frame to account for the offset and scaling
        let adjustedFrame = CGRect(x: 0, y: -24, width: frame.width, height: frame.height + 24)
        imageView.frame = adjustedFrame
    }

    private func setupOverlayView() {
        overlayView.autoresizingMask = [.width, .height]
        overlayView.frame = imageView.bounds
        overlayView.trackingImageView = imageView
        overlayView.preferredInteractionTypes = .textSelection
    }
    
    func updateImage(_ image: NSImage) {
        configureImageView(with: image, in: self.frame)
    }

    func updateAnalysis(_ analysis: ImageAnalysis?) {
        overlayView.analysis = analysis
    }
}

struct CustomHostingControllerRepresentable: NSViewControllerRepresentable {
    var settingsManager: SettingsManager
    var onClose: () -> Void
    var image: NSImage?
    @Binding var analysis: ImageAnalysis?
    var frame: NSRect

    func makeNSViewController(context: Context) -> CustomHostingViewController {
        let viewController = CustomHostingViewController()
        viewController.onClose = onClose
        viewController.settingsManager = settingsManager
        viewController.updateContent(image: image, frame: frame, analysis: analysis)
        return viewController
    }

    func updateNSViewController(_ nsViewController: CustomHostingViewController, context: Context) {
        nsViewController.updateContent(image: image, frame: frame, analysis: analysis)
        nsViewController.onClose = onClose
        nsViewController.settingsManager = settingsManager
    }
}

class CustomHostingViewController: NSViewController {
    var settingsManager: SettingsManager?
    var onClose: (() -> Void)?  // Closure to handle thumbnail click
    var customHostingView: CustomHostingView?
    var interceptingView: CustomInterceptingView?
    
    override func viewWillAppear() {
        view.enterFullScreenMode(NSScreen.main!)
    }

    override func loadView() {
        let _interceptingView = CustomInterceptingView()
        _interceptingView.onClose = onClose
        _interceptingView.settingsManager = settingsManager
        self.view = _interceptingView // Basic NSView as a container
        if customHostingView == nil {
            customHostingView = CustomHostingView(image: NSImage(), frame: self.view.bounds)
            customHostingView?.frame = CGRect(origin: .zero, size: self.view.bounds.size)
            view.addSubview(customHostingView!)
        }
        _interceptingView.customHostingView = customHostingView
        interceptingView = _interceptingView
    }

    func updateImage(_ image: NSImage?, frame: NSRect) {
        if let image = image {
            // Image available: update or create CustomHostingView with the image
            if customHostingView == nil {
                customHostingView = CustomHostingView(image: image, frame: frame)
                customHostingView?.frame = CGRect(origin: .zero, size: frame.size)
                view.addSubview(customHostingView!)
            } else {
                customHostingView?.updateImage(image)
            }
            customHostingView?.frame = CGRect(origin: .zero, size: frame.size)
        } else {
            // Image not available: Display VisualEffectView
            displayVisualEffectView()
        }
    }

    func updateContent(image: NSImage?, frame: NSRect, analysis: ImageAnalysis?) {
        if let image = image {
            // Image is available
            updateImage(image, frame: frame)
            updateAnalysis(analysis)
        } else {
            // Image is not available, display VisualEffectView
            displayVisualEffectView()
        }
    }

    private func displayVisualEffectView() {
        // Ensure previous content is removed
        view.subviews.forEach { $0.removeFromSuperview() }

        let visualEffectView = VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        NSHostingController(rootView: visualEffectView)
            .view
            .frame = view.bounds
        view.addSubview(NSHostingController(rootView: visualEffectView).view)
    }

    func updateAnalysis(_ analysis: ImageAnalysis?) {
        customHostingView?.updateAnalysis(analysis)
    }
}

class CustomInterceptingView: NSView {
    var settingsManager: SettingsManager?
    var onClose: (() -> Void)?  // Closure to handle thumbnail click
    weak var customHostingView: CustomHostingView?
    
    private func exit() {
        self.exitFullScreenMode()
        self.onClose?()
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Iterate over each subview to check if the point is within its bounds
        if let v = self.customHostingView {
            for subview in v.subviews.reversed() { // Reverse order to start from topmost view
                let localPoint = subview.convert(point, from: self)
                if subview.bounds.contains(localPoint), let targetView = subview.hitTest(localPoint) {
                    return targetView // Return the subview that should handle the event
                }
            }
        }
        return super.hitTest(point) // Return self if no subviews are targeted
    }

    
    // This method is called whenever a key is pressed
    override func keyDown(with event: NSEvent) {
        // Check for specific keys like Escape
        if event.keyCode == 53 { // 53 is the keycode for Escape
            self.exit()
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        guard settingsManager?.settings.enableCmdScrollShortcut ?? false else { return }
        if event.modifierFlags.contains(.command) && event.scrollingDeltaY > 0 {
            self.exit()
        }
    }
}

class TimelineViewModel: ObservableObject {
    private var speedFactor: Double = 0.05 // Adjust this factor based on UX requirements
    @Published var currentFrameContinuous: Double = 0.0
    @Published var currentFrameIndex: Int64 = 0
    private var indexUpdateThrottle = Throttler(delay: 0.05)
    
    init() {
        let maxFrame = DatabaseManager.shared.getMaxFrame()
        currentFrameIndex = maxFrame
        currentFrameContinuous = Double(maxFrame)
    }

    func updateIndex(withDelta delta: Double) {
        // Logic to update the index based on the delta
        // This method will be called from AppDelegate
        var nextValue = currentFrameContinuous - delta * speedFactor
        let maxValue = Double(DatabaseManager.shared.getMaxFrame())
        let clampedValue = min(max(1, nextValue), maxValue)
        self.currentFrameContinuous = clampedValue
        self.updateIndexSafely()
    }
    
    func updateIndex(withIndex: Int64) {
        let maxValue = Double(DatabaseManager.shared.getMaxFrame())
        let clampedValue = min(max(1, Double(withIndex)), maxValue)
        self.currentFrameContinuous = clampedValue
        self.updateIndexSafely()
    }
    
    func setIndexToLatest() {
        self.currentFrameContinuous = Double(DatabaseManager.shared.getMaxFrame())
        self.currentFrameIndex = Int64(currentFrameContinuous)
    }
    
    func updateIndexSafely() {
        indexUpdateThrottle.throttle {
            let rounded = Int64(self.currentFrameContinuous)
            self.currentFrameIndex = rounded
        }
    }
}
