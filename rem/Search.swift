import SwiftUI
import Combine

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
    @State private var debounceTimer: Timer? = nil
    @FocusState var focused: Bool?

    var body: some View {
        HStack {
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
                .onSubmit(onSearch) // Trigger search when user submits
                .onChange(of: text) {
                    debounceTimer?.invalidate()
                    debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                        onSearch()
                    }
                } // Trigger search when text changes
                .onAppear {
                    self.focused = true
                }
                .padding(.horizontal, 10)
        }
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

struct SearchResult: Hashable {
    var thumbnail: NSImage
    var frameId: Int64
    var applicationName: String?
    var fullText: String?
    var searchText: String
    var timestamp: Date
    var matchRange: Range<String.Index>?
    
    init(thumbnail: NSImage, frameId: Int64, applicationName: String?, fullText: String?, searchText: String, timestamp: Date) {
            self.thumbnail = thumbnail
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
    let result: SearchResult
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
                Text(result.timestamp.formatted())
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
    @State var searchText: String = ""
    @State private var searchResults: [SearchResult] = []
    var onThumbnailClick: (Int64) -> Void  // Closure to handle thumbnail click
    
    var body: some View {
        VStack {
            SearchBar(text: $searchText, onSearch: performSearch)
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                    ForEach(searchResults, id: \.self) { result in
                        SearchResultView(result: result, onClick: onThumbnailClick)
                    }
                }
                .padding()
            }
        }
        .onAppear(perform: loadRecentResults)
    }
    
    private func performSearch() {
        if searchText.isEmpty {
            loadRecentResults()
        } else {
            let results = DatabaseManager.shared.search(searchText: searchText)
            searchResults = mapResultsToSearchResult(results)
        }
    }
    
    private func loadRecentResults() {
        let recentResults = DatabaseManager.shared.getRecentResults(limit: 27)
        searchResults = mapResultsToSearchResult(recentResults)
    }
    
    private func mapResultsToSearchResult(_ data: [(frameId: Int64, fullText: String?, applicationName: String?, timestamp: Date)]) -> [SearchResult] {
        data.map { item in
            var nsImage: NSImage = NSImage(systemSymbolName: "questionmark.diamond", accessibilityDescription: "Missing thumbnail")!
            if let cgImage = DatabaseManager.shared.getImage(index: item.frameId) {
                let size = NSSize(width: cgImage.width, height: cgImage.height)
                nsImage = NSImage(cgImage: cgImage, size: size)
            }
            return SearchResult(
                thumbnail: nsImage,
                frameId: item.frameId,
                applicationName: item.applicationName,
                fullText: item.fullText?.split(separator: "\n").joined(separator: " "),
                searchText: searchText,
                timestamp: item.timestamp
            )
        }
    }
}

#Preview("Hello", traits: .defaultLayout) {
    SearchView(onThumbnailClick: { _ in })
}

