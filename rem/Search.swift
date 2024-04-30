import SwiftUI
import Combine
import os

struct SearchView: View {
    var onThumbnailClick: (Int64) -> Void  // Closure to handle thumbnail click

    var body: some View {
        ZStack {
            // Using a thin material for the background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Components
            VStack {
                ResultsView(onThumbnailClick: onThumbnailClick)
                    .padding(.top, 20)

                Spacer()
                // Future components will be added here
                Spacer()
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSearch: () -> Void
    @Namespace var nspace
    @FocusState var focused: Bool?
    var debounceSearch = Debouncer(delay: 0.3)
    @Binding var selectedFilterAppIndex: Int
    @Binding var selectedFilterApp: String
    @State private var applicationFilterArray: [String] = []
    
    var body: some View {
        HStack(spacing: 16) {
            // Search TextField
            TextField("Search", text: $text, prompt: Text("Search for something..."))
                .prefersDefaultFocus(in: nspace)
                .textFieldStyle(.plain)
                .focused($focused, equals: true)
                .font(.system(size: 20))
                .padding()
                .padding(.horizontal, 24)
                .background(.thickMaterial)
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .imageScale(.large)
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 12)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(white: 0.3), lineWidth: 1)
                )
                .onSubmit {
                    Task {
                        onSearch()
                    }
                }
                .onChange(of: text) { _ in
                    debounceSearch.debounce {
                        Task {
                            onSearch()
                        }
                    }
                }
                .onAppear {
                    self.focused = true
                }

            FilterPicker(
                applicationFilterArray: applicationFilterArray,
                selectedFilterAppIndex: $selectedFilterAppIndex,
                selectedFilterApp: $selectedFilterApp,
                debounceSearch: debounceSearch,
                onSearch: onSearch
            )
        }.padding(.horizontal, 16)
    }
}

struct FilterPicker: View {
    @State var applicationFilterArray: [String]
    @Binding var selectedFilterAppIndex: Int
    @Binding var selectedFilterApp: String
    var debounceSearch: Debouncer
    var onSearch: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Picker("Application", selection: $selectedFilterAppIndex) {
                ForEach(applicationFilterArray.indices, id: \.self) { index in
                    Text(applicationFilterArray[index])
                        .tag(index)
                }
            }
            .onHover(perform: { hovering in
              updateAppFilterData()
            })
            .onAppear{
                updateAppFilterData()
            }
            .pickerStyle(.menu)
            .onChange(of: selectedFilterAppIndex) { newIndex in
                guard newIndex >= 0 && newIndex < applicationFilterArray.count else {
                    return
                }
                selectedFilterApp = applicationFilterArray[selectedFilterAppIndex]
                onSearch()
            }
            .frame(width: 200)
        }
    }
    private func updateAppFilterData() {
        var appFilters = ["All apps"]
        let allAppNames = DatabaseManager.shared.getAllApplicationNames()
        appFilters.append(contentsOf: allAppNames)
        applicationFilterArray = appFilters
    }
}


struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct ThumbnailView: View {
    let imagePath: String

    var body: some View {
        if let image = NSImage(contentsOfFile: imagePath) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .cornerRadius(8)
        } else {
            Image(systemName: "photo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .cornerRadius(8)
        }
    }
}

class SearchResult: ObservableObject, Identifiable {
    let id = UUID()  // Unique identifier for each SearchResult

    @Published var thumbnail: NSImage
    var frameId: Int64
    var applicationName: String?
    var fullText: String?
    var searchText: String
    var timestamp: Date
    var matchRange: Range<String.Index>?
    
    init(frameId: Int64, applicationName: String?, fullText: String?, searchText: String, timestamp: Date) {
        self.thumbnail = NSImage()
        self.frameId = frameId
        self.applicationName = applicationName
        self.fullText = fullText
        self.searchText = searchText
        self.timestamp = timestamp

        // Find range, ignoring case and whitespace
        if let text = fullText {
            let pattern = searchText
                .trimmingCharacters(in: .whitespacesAndNewlines)
//                    .replacingOccurrences(of: "\\s+", with: "\\s*", options: .regularExpression)
                .replacingOccurrences(of: "(", with: "\\(")
                .replacingOccurrences(of: ")", with: "\\)")
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
                self.matchRange = Range(match.range, in: text) ?? text.startIndex..<text.startIndex
            } else {
                self.matchRange = text.startIndex..<text.startIndex
            }
        }
    }
    
    // Method to update the thumbnail
        func updateThumbnail(_ newImage: NSImage) {
            DispatchQueue.main.async {
                self.thumbnail = newImage
            }
        }
}

struct HighlightTextView: NSViewRepresentable {
    var text: String
    var range: NSRange

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = .clear
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        textView.alignment = .center // Center the text horizontally
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        if nsView.string != text {
            nsView.textStorage?.beginEditing()
            let attributedString = NSMutableAttributedString(string: text)
            attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: NSRange(location: 0, length: text.utf16.count))
            attributedString.addAttribute(.foregroundColor, value: NSColor.white, range: NSRange(location: 0, length: text.utf16.count))
            nsView.textStorage?.setAttributedString(attributedString)

            // Apply highlight only to the specified range
            let highlightRange = NSIntersectionRange(range, NSRange(location: 0, length: text.utf16.count))
            nsView.textStorage?.addAttribute(.backgroundColor, value: NSColor.yellow, range: highlightRange)
            nsView.textStorage?.addAttribute(.foregroundColor, value: NSColor.black, range: highlightRange)

            nsView.textStorage?.endEditing()
        }
    }
}

struct HighlightedTextDisplayView: View {
    let fullText: String
    let matchRange: Range<String.Index>

    var body: some View {
        // Calculate the start and end indices for the substring
        let start = fullText.index(max(fullText.startIndex, matchRange.lowerBound), offsetBy: -10, limitedBy: fullText.startIndex) ?? fullText.startIndex
        let end = fullText.index(min(fullText.endIndex, matchRange.upperBound), offsetBy: 10, limitedBy: fullText.endIndex) ?? fullText.endIndex
        let surroundingText = fullText[start..<end]

        // Adjust the range for the highlight
        let adjustedStart = fullText.distance(from: start, to: matchRange.lowerBound)
        let adjustedLength = fullText.distance(from: matchRange.lowerBound, to: matchRange.upperBound)
        let adjustedRange = NSRange(location: adjustedStart, length: adjustedLength)

        HighlightTextView(text: String(surroundingText), range: adjustedRange)
    }
}


struct SearchResultView: View {
    @StateObject var result: SearchResult
    var onClick: (Int64) -> Void

    @State private var isHovered = false

    var body: some View {
        VStack {
            let frame = NSScreen.main!.frame
            Image(nsImage: result.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: frame.width / 4, height: frame.height / 4)

            VStack(alignment: .center, spacing: 24.0) {
                Text(result.timestamp.formatted(date: .abbreviated, time: .standard))
                if let appName = result.applicationName {
                    Text(appName).font(.headline)
                }
                
                if let fullText = result.fullText, let matchRange = result.matchRange {
                    HighlightedTextDisplayView(fullText: fullText, matchRange: matchRange)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(isHovered ? Color.white.opacity(0.3) : Color.clear))
        .onHover { hover in
            isHovered = hover
        }
        .onTapGesture {
            onClick(result.frameId)
        }
        .cornerRadius(10)
    }
}


struct ResultsView: View {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ResultsView.self)
    )
    @State private var isLoadingMore = false
    @State var searchText: String = ""
    @State private var searchResults: [SearchResult] = []
    @State var limit: Int = 27
    @State var offset: Int = 0
    @State var selectedFilterApp: String = ""
    @State var selectedFilterAppIndex: Int = 0
    
    var onThumbnailClick: (Int64) -> Void

        var body: some View {
            VStack {
                SearchBar(
                    text: $searchText,
                    onSearch: performSearch,
                    selectedFilterAppIndex: $selectedFilterAppIndex,
                    selectedFilterApp: $selectedFilterApp
                )
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                    ForEach(searchResults) { result in
                        SearchResultView(result: result, onClick: onThumbnailClick)
                    }
                }
                .padding()
                .onScrollToBottom {
                    Task {
                        loadMoreResults()
                    }
                }
                
                if isLoadingMore {
                    ProgressView()
                }
            }.onAppear {
                Task {
                    performSearch()
                }
            }
        }
    }
    
    // Function to load more results
    private func loadMoreResults() {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        searchResults.append(contentsOf: getSearchResults())
        offset += limit
        isLoadingMore = false
    }
    
    private func performSearch() {
        offset = 0
        searchResults = getSearchResults()
    }
    
    private func getSearchResults() -> [SearchResult] {
        var results: [(frameId: Int64, fullText: String?, applicationName: String?, timestamp: Date, filePath: String, offsetIndex: Int64)] = []

        if selectedFilterAppIndex == 0 {
            if searchText.isEmpty {
                results = DatabaseManager.shared.getRecentResults(limit: limit, offset: offset)
            } else {
                results = DatabaseManager.shared.search(searchText: searchText, limit: limit, offset: offset)
            }
        } else {
            if searchText.isEmpty {
                results = DatabaseManager.shared.getRecentResults(selectedFilterApp: selectedFilterApp, limit: limit, offset: offset)
            } else {
                results = DatabaseManager.shared.search(appName: selectedFilterApp, searchText: searchText, limit: limit, offset: offset)
            }
        }
        
        return mapResultsToSearchResult(results)
    }

    
    private func mapResultsToSearchResult(_ data: [(frameId: Int64, fullText: String?, applicationName: String?, timestamp: Date, filePath: String, offsetIndex: Int64)]) -> [SearchResult] {
            let searchResults = data.map { item in
                SearchResult(frameId: item.frameId, applicationName: item.applicationName, fullText: item.fullText?.split(separator: "\n").joined(separator: " "), searchText: searchText, timestamp: item.timestamp)
            }

            // Fetch all images in bulk
            Task {
                await fetchThumbnailsForResults(searchResults, data: data)
            }

            return searchResults
        }

    private func fetchThumbnailsForResults(_ results: [SearchResult], data: [(frameId: Int64, fullText: String?, applicationName: String?, timestamp: Date, filePath: String, offsetIndex: Int64)]) async {
        var offsetsLookup: [String: [(Int64, Int64)]] = [:]
        var frameIdIndexLookup: [Int64: Int] = [:]
        
        for (index, item) in data.enumerated() {
            if !offsetsLookup.contains(where: { (key, value) in
                key == item.filePath
            }) {
                offsetsLookup[item.filePath] = []
            }
            offsetsLookup[item.filePath]?.append((item.frameId, item.offsetIndex))
            frameIdIndexLookup[item.frameId] = index
        }
        
        for (key, value) in offsetsLookup {
            let frameOffsets = value.map { $0.1 }
            var offsetToId: [Int64: Int64] = [:]
            value.forEach { v in
                offsetToId[v.1] = v.0
            }
            let imageSequence = DatabaseManager.shared.getImages(filePath: key, frameOffsets: frameOffsets, maxSize: CGSize(width: 600, height: 600))
            
            let fps = Double(DatabaseManager.FPS)
            var count = 0
            for await imageResult in imageSequence {
                switch imageResult {
                case .success(let requestedTime, let image, _):
                    if count < results.count {
                        let offset = Int64((requestedTime.seconds * Double(fps)).rounded())
                        if let id = offsetToId[offset] {
                            if let dataIndex = frameIdIndexLookup[id] {
                                results[dataIndex].updateThumbnail(NSImage(cgImage: image, size: NSZeroSize))
                            }
                        }
                    }
                    count += 1
                case .failure(let requestedTime, let error):
                    let offset = Int64(requestedTime.seconds * fps)
                    logger.error("Failed to load image for time \(offset): \(error)")
                }
            }
        }
    }
}

// Key definition for tracking ScrollView offset
struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollViewOffsetModifier: ViewModifier {
    var onBottomReached: () -> Void
    @State private var currentOffsetY: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ViewOffsetKey.self, value: proxy.frame(in: .global).minY)
                }
            )
            .onPreferenceChange(ViewOffsetKey.self) { value in
                if currentOffsetY > value && currentOffsetY - value > 100 { // Detect scroll upwards
                    onBottomReached()
                }
                currentOffsetY = value
            }
    }
}

extension View {
    func onScrollToBottom(perform action: @escaping () -> Void) -> some View {
        self.modifier(ScrollViewOffsetModifier(onBottomReached: action))
    }
}
