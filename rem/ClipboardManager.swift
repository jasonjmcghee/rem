import AppKit

class ClipboardManager {
    static let shared = ClipboardManager()
    
    private var changeCount: Int
    private var pasteboard: NSPasteboard
    
    init() {
        self.pasteboard = NSPasteboard.general
        self.changeCount = pasteboard.changeCount
    }
    
    func getClipboardIfChanged() -> String? {
        // Check if the clipboard has changed since the last check
        if pasteboard.changeCount != changeCount {
            var newItems: [String] = []
            let currentChangeCount = pasteboard.changeCount
            
            // Iterate over the changes since the last recorded changeCount
            for _ in changeCount..<currentChangeCount {
                if let string = pasteboard.string(forType: .string) {
                    newItems.append(string)
                }
            }
            
            // Update the changeCount to the current changeCount
            changeCount = currentChangeCount
            
            // Return the concatenated string if there are new items
            return newItems.isEmpty ? nil : newItems.joined(separator: "\n")
        }
        
        // Return nil if there are no new changes
        return nil
    }
    
    func replaceClipboardContents(with string: String) {
        pasteboard.clearContents()
        
        let finalContents = string.isEmpty ? "No context. Is remembering disabled?" : """
        Below is the text that's been on my screen recently. ------------- \(string) ------------------ Above is the text that's been on my screen recently. Please answer whatever I ask using the provided information about what has been on the screen recently. Do not say anything else or give any other information. Only answer the query. --------------------------\n
        """

        pasteboard.setString(finalContents, forType: .string)
        // We don't want to pickup our own changes
        changeCount = pasteboard.changeCount
    }
}
