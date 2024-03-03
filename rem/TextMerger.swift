//
//  TextMerger.swift
//  rem
//
//  Created by Jason McGhee on 12/25/23.
//

import Foundation

class TextMerger {
    static let shared = TextMerger()

    func mergeTexts(texts: [String]) -> String {
        var mergedText: String = ""
        var linesSeen = Set<String>()
        for text in texts {
            let cleanedText = cleanText(text)
            for line in self.segmentText(cleanedText) {
                if !linesSeen.contains(line) {
                    mergedText += "\(line)\n"
                    linesSeen.insert(line)
                }
            }
        }
        return mergedText
    }

    private func mergeTwoTexts(text1: String, text2: String) -> String {
        return [text1, text2].joined(separator: "\n")
//        let segments1 = segmentText(text1)
//        let segments2 = segmentText(text2)
//        var mergedSegments: [String] = []
        
        // If the first line matches any...
        // Start from there and go down until no more matches
        // let firstSegment2 = segments2.first
        
        // Go through each line of `segments1` and look for a "match"
        // Then try to find contiguous matches of `k` (3?) in a row, and merge if so.
        // let verySimilar = calculateSimilarity(seg1: seg1, seg2: firstSegment2) > 0.8
        
        
        // If the last line matches any...
        // Start from there and go up until no more matches
        // let lastSegment2 = segments2.last
        
        // Go through each line of `segments1` and look for a "match"
        // Then try to find contiguous matches of `k` (3?) in a row, and merge if so.
        // let verySimilar = calculateSimilarity(seg1: seg1, seg2: lastSegment2) > 0.8

        // return mergedSegments.joined(separator: "\n")
    }

    private func segmentText(_ text: String) -> [String] {
        return text.components(separatedBy: "\n")
    }

    private func mergeSegments(seg1: String, seg2: String) -> String {
        return seg1.count > seg2.count ? seg1 : seg2
    }

    func cleanText(_ text: String) -> String {
        let lines = text.split(separator: "\n")
        let cleanedLines = lines.filter { line in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let regexPattern = #"^(?:\s*\w\s*|\s*\d+\s*|\s*\b(File|Edit|View|Help)\b\s*)$"#
            return !trimmedLine.isEmpty && (trimmedLine.range(of: regexPattern, options: .regularExpression) == nil)
        }
        return cleanedLines.joined(separator: "\n")
    }

    func compressDocument(_ text: String, chunkSize: Int = 100) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var chunks: [String] = []
        var tempChunk = ""

        for line in lines {
            if (tempChunk.count + line.count) <= chunkSize {
                tempChunk += line + "\n"
            } else {
                chunks.append(tempChunk)
                tempChunk = String(line) + "\n"
            }
        }
        if !tempChunk.isEmpty {
            chunks.append(tempChunk)
        }
        
        for (i, chunk) in chunks.enumerated() {
            chunks[i] = chunk.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }

        let compressedText = mergeTexts(texts: chunks)
        return compressedText
    }
}
