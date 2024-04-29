// TimelineView.swift
import SwiftUI
import AVFoundation
import VisionKit
import os

struct TimelineView: View {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TimelineView.self)
    )
    @ObservedObject var viewModel: TimelineViewModel
    @State private var imageAnalysis: ImageAnalysis?
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
        _customHostingView = State(initialValue: nil)
    }
    
    var body: some View {
        ZStack {
            let frame = NSScreen.main?.frame ?? NSRect.zero
            let image = DatabaseManager.shared.getImageByChunksFramesIndex(index: viewModel.currentFrameIndex)
            let nsImage = image.flatMap { NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)) }
            
            CustomHostingControllerRepresentable(
                settingsManager: settingsManager,
                onClose: onClose,
                image: nsImage,
                analysis: imageAnalysis,
                frame: frame,
                timelineOpen: viewModel.timelineOpen
            )
                .frame(width: frame.width, height: frame.height)
                .ignoresSafeArea(.all)
                .onChange(of: viewModel.currentFrameIndex) { _ in
                    analyzeCurrentImage()
                }
                .onAppear {
                    analyzeCurrentImage()
                }
            
            if image == nil {
                VStack(alignment: .center) {
                    Text("Nothing to remember, or missing frame (if missing, sorry, still alpha!)")
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.1)))
                }
            }
            
        }
        .ignoresSafeArea(.all)
    }
    
    private func analyzeCurrentImage() {
        ocrDebouncer.debounce {
            analyzeImage(index: viewModel.currentFrameIndex)
        }
    }
    
    private func analyzeImage(index: Int64) {
        Task {
            if let image = DatabaseManager.shared.getImageByChunksFramesIndex(index: index) {
                let configuration = ImageAnalyzer.Configuration([.text])
                do {
                    let analysis = try await imageAnalyzer.analyze(image, orientation: CGImagePropertyOrientation.up, configuration: configuration)
                    DispatchQueue.main.async {
                        self.imageAnalysis = analysis
                        // print("Analysis successful: \(analysis.transcript)")
                    }
                } catch {
                    logger.error("Error analyzing image: \(error)")
                }
            }
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

        imageView.imageScaling = .scaleProportionallyUpOrDown

        // Configuring frame to account for the offset and scaling
        imageView.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
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
    var analysis: ImageAnalysis?
    var frame: NSRect
    var timelineOpen: Bool

    func makeNSViewController(context: Context) -> CustomHostingViewController {
        let viewController = CustomHostingViewController()
        viewController.onClose = onClose
        viewController.settingsManager = settingsManager
        viewController.updateContent(image: image, frame: frame, analysis: analysis)
        return viewController
    }

    func updateNSViewController(_ nsViewController: CustomHostingViewController, context: Context) {
        if timelineOpen {
            nsViewController.updateContent(image: image, frame: frame, analysis: analysis)
        }
        nsViewController.onClose = onClose
        nsViewController.settingsManager = settingsManager
    }
}

class CustomHostingViewController: NSViewController {
    var settingsManager: SettingsManager?
    var onClose: (() -> Void)?
    var customHostingView: CustomHostingView?
    var interceptingView: CustomInterceptingView?
    var hadImage: Bool = false
    
    override func viewWillAppear() {
        DispatchQueue.main.async {
            self.view.window?.makeKey()
        }
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

    func updateImage(_ image: NSImage, frame: NSRect) {
        // Image available: update or create CustomHostingView with the image
        if customHostingView == nil {
            customHostingView = CustomHostingView(image: image, frame: frame)
            customHostingView?.frame = CGRect(origin: .zero, size: frame.size)
            view.addSubview(customHostingView!)
        } else {
            customHostingView?.updateImage(image)
        }
        customHostingView?.frame = CGRect(origin: .zero, size: frame.size)
    }

    func updateContent(image: NSImage?, frame: NSRect, analysis: ImageAnalysis?) {
        if let im = image {
            let fullScreenOptions = [NSView.FullScreenModeOptionKey.fullScreenModeAllScreens: NSNumber(value: false)]
            if !view.isInFullScreenMode {
                DispatchQueue.main.async {
                    self.view.enterFullScreenMode(NSScreen.main!, withOptions: fullScreenOptions)
                }
            }
            updateImage(im, frame: frame)
            updateAnalysis(analysis)
            hadImage = true
        } else {
            if view.isInFullScreenMode {
                DispatchQueue.main.async {
                    self.view.exitFullScreenMode()
                }
            }
            displayVisualEffectView()
            hadImage = false
        }
    }

    private func displayVisualEffectView() {
        interceptingView?.subviews.forEach { $0.removeFromSuperview() }

        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.frame = interceptingView?.bounds ?? NSRect.zero

        interceptingView?.addSubview(visualEffectView)
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
    @Published var timelineOpen: Bool = false
    private var indexUpdateThrottle = Throttler(delay: 0.05)
    
    init() {
        let maxFrame = DatabaseManager.shared.getMaxChunksFramesIndex()
        currentFrameIndex = maxFrame
        currentFrameContinuous = Double(maxFrame)
    }

    func updateIndex(withDelta delta: Double) {
        // Logic to update the index based on the delta
        // This method will be called from AppDelegate
        let nextValue = currentFrameContinuous - delta * speedFactor
        let maxValue = Double(DatabaseManager.shared.getMaxChunksFramesIndex())
        let clampedValue = min(max(1, nextValue), maxValue)
        self.currentFrameContinuous = clampedValue
        self.updateIndexSafely()
    }
    
    func updateIndex(withIndex: Int64) {
        let maxValue = Double(DatabaseManager.shared.getMaxChunksFramesIndex())
        let clampedValue = min(max(1, Double(withIndex)), maxValue)
        self.currentFrameContinuous = clampedValue
        self.updateIndexSafely()
    }
    
    func setIndexToLatest() {
        let maxFrame = DatabaseManager.shared.getMaxChunksFramesIndex()
        DispatchQueue.main.async {
            self.currentFrameContinuous = Double(maxFrame)
            self.currentFrameIndex = maxFrame
        }
    }
    
    func updateIndexSafely() {
        indexUpdateThrottle.throttle {
            let rounded = Int64(self.currentFrameContinuous)
            self.currentFrameIndex = rounded
        }
    }
    
    func setIsOpen(isOpen: Bool) {
        timelineOpen = isOpen
    }
}
