//
//  SQLite.swift
//  rem
//
//  Created by Jason McGhee on 12/16/23.
//

// SQLite.swift
import Foundation
import SQLite
import Vision
import AVFoundation

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: Connection
    
    // Last 15 frames
    let recentFramesThreshold = 15

    private let videoChunks = Table("video_chunks")
    private let frames = Table("frames")
    let allText = VirtualTable("allText")


    private let id = Expression<Int64>("id")
    private let offsetIndex = Expression<Int64>("offsetIndex")
    private let chunkId = Expression<Int64>("chunkId")
    private let timestamp = Expression<Date>("timestamp")
    private let filePath = Expression<String>("filePath")
    private let activeApplicationName = Expression<String?>("activeApplicationName")
    
    let frameId = Expression<Int64>("frameId")
    let text = Expression<String>("text")
    
    private var currentChunkId: Int64 = 0 // Initialize with a default value
    private var lastFrameId: Int64 = 0
    private var currentFrameOffset: Int64 = 0

    init() {
        if let savedir = RemFileManager.shared.getSaveDir() {
            db = try! Connection("\(savedir)/db.sqlite3")
        } else {
            db = try! Connection("db.sqlite3")
        }

        createTables()
        currentChunkId = getCurrentChunkId()
        lastFrameId = getLastFrameId()
    }
    
    private func connect() {
        if let savedir = RemFileManager.shared.getSaveDir() {
            db = try! Connection("\(savedir)/db.sqlite3")
        } else {
            db = try! Connection("db.sqlite3")
        }
    }
    
    func reconnect() {
        self.connect()
        currentChunkId = getCurrentChunkId()
        lastFrameId = getLastFrameId()
    }

    private func createTables() {
        try! db.run(videoChunks.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(filePath)
        })

        try! db.run(frames.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(chunkId, references: videoChunks, id)
            t.column(offsetIndex)
            t.column(timestamp)
            t.column(activeApplicationName)
        })
        
        let config = FTS4Config()
            .column(frameId, [.unindexed])
            .column(text)
            .languageId("lid")
            .order(.desc)

        // Text search
        try! db.run(allText.create(.FTS4(config), ifNotExists: true))
    }
    
    private func getCurrentChunkId() -> Int64 {
        do {
            if let lastChunk = try db.pluck(videoChunks.order(id.desc)) {
                return lastChunk[id] + 1
            }
        } catch {
            print("Error fetching last chunk ID: \(error)")
        }
        return 1
    }
    
    private func getLastFrameId() -> Int64 {
        do {
            if let lastFrame = try db.pluck(frames.order(id.desc)) {
                return lastFrame[id]
            }
        } catch {
            print("Error fetching last chunk ID: \(error)")
        }
        return 0
    }

    // Insert a new video chunk and return its ID
    func startNewVideoChunk(filePath: String) -> Int64 {
        let insert = videoChunks.insert(self.filePath <- filePath)
        let id = try! db.run(insert)
        currentChunkId = id + 1
        currentFrameOffset = 0
        return id
    }

    func insertFrame(activeApplicationName: String?) -> Int64 {
        let insert = frames.insert(self.chunkId <- currentChunkId, self.timestamp <- Date(), self.offsetIndex <- currentFrameOffset, self.activeApplicationName <- activeApplicationName)
        let id = try! db.run(insert)
        currentFrameOffset += 1
        lastFrameId = id
        return id
    }
    
    func insertTextForFrame(frameId: Int64, text: String) {
        let insert = allText.insert(self.frameId <- frameId, self.text <- text)
        try! db.run(insert)
    }
    
    func getFrame(forIndex index: Int64) -> (offsetIndex: Int64, filePath: String)? {
        let query = frames.join(videoChunks, on: chunkId == videoChunks[id]).filter(frames[id] == index).limit(1)
        if let frame = try! db.pluck(query) {
            return (frame[self.offsetIndex], frame[self.filePath])
        }
        return nil
    }

    // Function to retrieve the file path of a video chunk by its index
    func getVideoChunkPath(byIndex index: Int64) -> String? {
        let query = videoChunks.filter(chunkId == index)
        if let chunk = try! db.pluck(query) {
            return chunk[filePath]
        }
        return nil
    }

// Function to get the timestamp of the last inserted frame
    private func getLastFrameTimestamp() -> Date? {
        let query = frames.select(timestamp).order(id.desc).limit(1)
        if let lastFrame = try! db.pluck(query) {
            return lastFrame[timestamp]
        }
        return nil
    }
    
    private func getLastFrameIndexFromDB() -> Int64? {
        let query = frames.select(id).order(id.desc).limit(1)
        if let lastFrame = try! db.pluck(query) {
            return lastFrame[id]
        }
        return nil
    }
    
    func getRecentTextContext() -> [String] {
        let query = allText.select(text).order(frameId.desc).limit(recentFramesThreshold)
        
        var texts: [String] = []
        do {
            for textFrame in try db.prepare(query) {
                texts.append(textFrame[text])
            }
        } catch {
            print(error)
        }
        return texts
    }
    
    func getMaxFrame() -> Int64 {
        return lastFrameId
    }
    
    func search(searchText: String, limit: Int = 9) -> [(frameId: Int64, fullText: String, applicationName: String?, timestamp: Date)] {
        let query = allText
            .join(frames, on: frames[id] == allText[frameId])
            .filter(self.text.match("*\(searchText)*"))
            .select(allText[frameId], self.text, frames[activeApplicationName], frames[timestamp])
            .limit(limit)

        var results: [(Int64, String, String?, Date)] = []
        do {
            for row in try db.prepare(query) {
                let frameId = row[allText[frameId]]
                let matchedText = row[self.text]
                let applicationName = row[frames[activeApplicationName]]
                let timestamp = row[frames[timestamp]]
                results.append((frameId, matchedText, applicationName, timestamp))
            }
        } catch {
            print("Search error: \(error)")
        }
        return results
    }
    
    func getRecentResults(limit: Int = 9) -> [(frameId: Int64, fullText: String?, applicationName: String?, timestamp: Date)] {
        let query = allText
            .join(frames, on: frames[id] == allText[frameId])
            .order(frames[timestamp].desc)
            .limit(limit)
            .select(allText[frameId], frames[activeApplicationName], frames[timestamp])

        var results: [(Int64, String?, String?, Date)] = []
        do {
            for row in try db.prepare(query) {
                let frameId = row[allText[frameId]]
                let applicationName = row[frames[activeApplicationName]]
                let timestamp = row[frames[timestamp]]
                results.append((frameId, nil, applicationName, timestamp))
            }
        } catch {
            print("Error fetching recent results: \(error)")
        }
        return results
    }
    
    func getImage(index: Int64) -> CGImage? {
        guard let frameData = DatabaseManager.shared.getFrame(forIndex: index) else { return nil }
        
        let videoURL = URL(fileURLWithPath: frameData.filePath)
        
        return extractFrame(from: videoURL, frameOffset: frameData.offsetIndex)
    }
    
    func extractFrame(from videoURL: URL, frameOffset: Int64) -> CGImage? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime.zero;
        generator.requestedTimeToleranceAfter = CMTime.zero;
        
        do {
            let a = CMTime(value: frameOffset, timescale: 25)
            let aI = try generator.copyCGImage(at: a, actualTime: nil)
            return aI
        } catch {
            print("Error extracting frame: \(error)")
            return nil
        }
    }
}


