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
    @State private var debounceTimer: Timer? = nil

    let overlayView = ImageAnalysisOverlayView()
    private let imageAnalyzer = ImageAnalyzer()

    private var fps: Int32 = 25
    
    init(viewModel: TimelineViewModel) {
        self.viewModel = viewModel
        _frame = State(initialValue: NSScreen.main?.visibleFrame ?? NSRect.zero)
        _customHostingView = State(initialValue: nil)
    }
    
    var body: some View {
        ZStack {
            let index = viewModel.currentFrameIndex
            if let image = DatabaseManager.shared.getImage(index: index) {
                let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.width))
                CustomHostingControllerRepresentable(image: nsImage, analysis: $imageAnalysis, frame: frame)
                    .frame(width: frame.width, height: frame.height)
                    .ignoresSafeArea(.all)
                    .onChange(of: viewModel.currentFrameIndex) { newIndex in
                        debounceTimer?.invalidate()
                        debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                            if let image = DatabaseManager.shared.getImage(index: newIndex) {
                                analyzeImage(image)  // Assuming `image` is available here, modify as needed
                            }
                        }
                    }
                    .onAppear {
                        debounceTimer?.invalidate()
                        analyzeImage(image)
                    }
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea(.all)
    }
    
    private func createCustomHostingView(with image: NSImage) -> CustomHostingView {
        if let view = customHostingView {
            view.updateImage(image)
            return view
        } else {
            let view = CustomHostingView(image: image, frame: frame)
            customHostingView = view
            return view
        }
    }
    
    private func analyzeImage(_ image: CGImage) {
        let configuration = ImageAnalyzer.Configuration([.text])
        
        Task {
            do {
                let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                let analysis = try await imageAnalyzer.analyze(nsImage, orientation: CGImagePropertyOrientation.up, configuration: configuration)
                DispatchQueue.main.async {
                    self.imageAnalysis = analysis
                    print("Analysis successful: \(analysis.transcript)")
                }
            } catch {
                print("Error analyzing image: \(error)")
            }
        }
    }
        
        var closeButton: some View {
            Button("Exit Full Screen") {
                if let window = NSApplication.shared.windows.first(where: { $0.contentView is NSHostingView<TimelineView> }) {
                    window.toggleFullScreen(nil)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        
        
//        struct Timeline_Previews: PreviewProvider {
//            static var previews: some View {
//                TimelineView(viewModel: TimelineViewModel())
//            }
//        }
        
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
        if analysis != nil {
            self.exitFullScreenMode()
        }
        overlayView.analysis = analysis
    }
}

struct CustomHostingControllerRepresentable: NSViewControllerRepresentable {
    var image: NSImage
    @Binding var analysis: ImageAnalysis?
    var frame: NSRect

    func makeNSViewController(context: Context) -> CustomHostingViewController {
        let viewController = CustomHostingViewController()
        viewController.updateImage(image, frame: frame)
        return viewController
    }

    func updateNSViewController(_ nsViewController: CustomHostingViewController, context: Context) {
        nsViewController.updateImage(image, frame: frame)
        nsViewController.updateAnalysis(analysis)
    }
}

class CustomHostingViewController: NSViewController {
    var customHostingView: CustomHostingView?
    
    override func viewWillAppear() {
        view.enterFullScreenMode(NSScreen.main!)
    }

    override func loadView() {
        let interceptingView = CustomInterceptingView()
        self.view = interceptingView // Basic NSView as a container
        if customHostingView == nil {
            customHostingView = CustomHostingView(image: NSImage(), frame: self.view.bounds)
            customHostingView?.frame = CGRect(origin: .zero, size: self.view.bounds.size)
            view.addSubview(customHostingView!)
        }
        interceptingView.customHostingView = customHostingView
    }

    func updateImage(_ image: NSImage, frame: NSRect) {
        if customHostingView == nil {
            customHostingView = CustomHostingView(image: image, frame: frame)
            customHostingView?.frame = CGRect(origin: .zero, size: frame.size)
            view.addSubview(customHostingView!)
        } else {
            customHostingView?.updateImage(image)
        }
        customHostingView?.frame = CGRect(origin: .zero, size: frame.size)
    }

    func updateAnalysis(_ analysis: ImageAnalysis?) {
        customHostingView?.updateAnalysis(analysis)
    }
}

class CustomInterceptingView: NSView {
    weak var customHostingView: CustomHostingView?
    
    private func exit() {
        if (self.isInFullScreenMode) {
            self.exitFullScreenMode()
            self.window?.isReleasedWhenClosed = false
            self.window?.close()
        }
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
        if event.modifierFlags.contains(.command) && event.scrollingDeltaY > 0 {
            self.exit()
        }
    }
}

class TimelineViewModel: ObservableObject {
    private var speedFactor: Double = 0.05 // Adjust this factor based on UX requirements
    @Published var currentFrameContinuous: Double = 0.0
    @Published var currentFrameIndex: Int64 = 0
    
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
        self.currentFrameIndex = Int64(currentFrameContinuous)
    }
    
    func updateIndex(withIndex: Int64) {
        let maxValue = Double(DatabaseManager.shared.getMaxFrame())
        let clampedValue = min(max(1, Double(withIndex)), maxValue)
        
        
        self.currentFrameContinuous = clampedValue
        self.currentFrameIndex = Int64(currentFrameContinuous)
    }
    
    func setIndexToLatest() {
        self.currentFrameContinuous = Double(DatabaseManager.shared.getMaxFrame())
        self.currentFrameIndex = Int64(currentFrameContinuous)
    }
}
