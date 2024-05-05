//
//  SQLite.swift
//  rem
//
//  Created by Jason McGhee on 12/16/23.
//

// SQLite.swift
import AVFoundation
import Foundation
import SQLite
import Vision
import os

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: Connection
    static var FPS: CMTimeScale = 25
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: DatabaseManager.self)
    )
    // Last 15 frames
    let recentFramesThreshold = 15
    
    private let videoChunks = Table("video_chunks")
    private let frames = Table("frames")
    private let uniqueAppNames = Table("unique_application_names")
    private let framesText = Table("frames_text")

    let allText = VirtualTable("allText")
    let chunksFramesView = View("chunks_frames_view")
    
    private let id = Expression<Int64>("id")
    private let offsetIndex = Expression<Int64>("offsetIndex")
    private let chunkId = Expression<Int64>("chunkId")
    private let chunksFramesIndex = Expression<Int64>("chunksFramesIndex")
    private let timestamp = Expression<Date>("timestamp")
    private let filePath = Expression<String>("filePath")
    private let activeApplicationName = Expression<String?>("activeApplicationName")
    private let x = Expression<Double>("x")
    private let y = Expression<Double>("y")
    private let w = Expression<Double>("w")
    private let h = Expression<Double>("h")
    
    let frameId = Expression<Int64>("frameId")
    let text = Expression<String>("text")
    
    private var currentChunkId: Int64 = 0 // Initialize with a default value
    private var lastFrameId: Int64 = 0
    private var currentFrameOffset: Int64 = 0
    private var lastChunksFramesIndex: Int64 = 0
    
    init() {
        if let savedir = RemFileManager.shared.getSaveDir() {
            db = try! Connection("\(savedir)/db.sqlite3")
        } else {
            db = try! Connection("db.sqlite3")
        }
        
        try! db.run("PRAGMA journal_mode = WAL")
        try! db.run("PRAGMA synchronous = NORMAL")
        
        createTables()
        currentChunkId = getCurrentChunkId()
        lastFrameId = getLastFrameId()
        lastChunksFramesIndex = getLastChunksFramesIndex()
    }
    
    func purge() {
        do {
            try db.run(videoChunks.drop(ifExists: true))
            try db.run(frames.drop(ifExists: true))
            try db.run(allText.drop(ifExists: true))
            try db.run(uniqueAppNames.drop(ifExists: true))
            try db.run(chunksFramesView.drop(ifExists: true))
            try db.run(framesText.drop(ifExists: true))
        } catch {
            print("Failed to delete tables")
        }
        
        createTables()
        createIndices()
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
        
        try! db.run(uniqueAppNames.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(activeApplicationName, unique: true)
        })
        
        try! db.run(framesText.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(frameId)
            t.column(text)
            t.column(x)
            t.column(y)
            t.column(w)
            t.column(h)
        })
        
        // Seed the `uniqueAppNames` table if empty
        do {
            if try db.scalar(uniqueAppNames.count) == 0 {
                let query = frames.select(distinct: activeApplicationName)
                var appNames: [String] = []
                for row in try db.prepare(query) {
                    if let appName = row[activeApplicationName] {
                        appNames.append(appName)
                    }
                }
                let insert = uniqueAppNames.insertMany(
                    appNames.map { name in [activeApplicationName <- name] }
                )
                try db.run(insert)
            }
        } catch {
            print("Error seeding database with app names: \(error)")
        }
        let config = FTS4Config()
            .column(frameId, [.unindexed])
            .column(text)
            .languageId("lid")
            .order(.desc)
        
        // Text search
        try! db.run(allText.create(.FTS4(config), ifNotExists: true))
        
        // Create chunksFramesView (ensures all frames have associated chunks)
        let viewSQL = """
        CREATE VIEW IF NOT EXISTS chunks_frames_view AS
        SELECT
            ROW_NUMBER() OVER (ORDER BY vc.id, f.id) as chunksFramesIndex,
            vc.id as chunkId,
            vc.filePath,
            f.id as frameId,
            f.timestamp,
            f.activeApplicationName,
            f.offsetIndex
        FROM
            video_chunks vc
        JOIN
            frames f ON vc.id = f.chunkId
        ORDER BY
            vc.id, f.id;
        """
        try! db.run(viewSQL)
    }
    
    private func createIndices() {
        do {
            // Compound index on frames for chunkId and id
            try db.run(frames.createIndex(chunkId, id, unique: false, ifNotExists: true))
            try db.run(frames.createIndex(timestamp, ifNotExists: true))
            
            // For speeding up chunksFramesView
            try db.run(videoChunks.createIndex(id, unique: true, ifNotExists: true))
            
            // Accessing framesText by frameId
            try db.run(framesText.createIndex(frameId, unique: false, ifNotExists: true))
            // Additional indices can be added here as needed
        } catch {
            print("Failed to create indices: \(error)")
        }
    }
    
    private func getCurrentChunkId() -> Int64 {
        do {
            if let lastFrame = try db.pluck(frames.order(id.desc)) {
                return lastFrame[chunkId] + 1
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
            print("Error fetching last frame ID: \(error)")
        }
        return 0
    }
    
    private func getLastChunksFramesIndex() -> Int64 {
        do {
            if let lastFrame = try db.pluck(chunksFramesView.order(chunksFramesIndex.desc)) {
                return lastFrame[chunksFramesIndex]
            }
        } catch {
            print("Error fetching last chunks frames Index: \(error)")
        }
        return 0
    }
    
    // Insert a new video chunk and return its ID
    func startNewVideoChunk(filePath: String) -> Int64 {
        let insert = videoChunks.insert(self.id <- currentChunkId, self.filePath <- filePath)
        let id = try! db.run(insert)
        currentChunkId = id + 1
        currentFrameOffset = 0
        lastChunksFramesIndex = getLastChunksFramesIndex()
        return id
    }
    
    func insertFrame(activeApplicationName: String?) -> Int64 {
        let insert = frames.insert(chunkId <- currentChunkId, timestamp <- Date(), offsetIndex <- currentFrameOffset, self.activeApplicationName <- activeApplicationName)
        let id = try! db.run(insert)
        currentFrameOffset += 1
        lastFrameId = id
        
        if let appName = activeApplicationName {
            //will check if the app name is already in the database.
            insertUniqueApplicationNamesIfNeeded(appName)
        }
        
        return id
    }
    
    private func insertUniqueApplicationNamesIfNeeded(_ appName: String) {
        let query = uniqueAppNames.filter(activeApplicationName == appName)
        
        do {
            let count = try db.scalar(query.count)
            if count == 0 {
                insertUniqueApplicationNames(appName)
            }
        } catch {
            print("Error checking existence of app name: \(error)")
        }
    }

    func insertUniqueApplicationNames(_ appName: String) {
        let insert = uniqueAppNames.insert(activeApplicationName <- appName)
        do {
            try db.run(insert)
        } catch {
            print("Error inserting unique application name: \(error)")
        }
    }
    
    func insertTextForFrame(frameId: Int64, text: String, x: Double, y: Double, w: Double, h: Double){
        let insert = framesText.insert(self.frameId <- frameId, self.text <- text, self.x <- x, self.y <- y,
                                       self.w <- w, self.h <- h)
        try! db.run(insert)
    }
    
    func insertTextsForFrames(entries: [(frameId: Int64, text: String, x: Double, y: Double, w: Double, h: Double)]){
        try! db.transaction {
            for entry in entries {
                let insert = framesText.insert(
                    self.frameId <- entry.frameId,
                    self.text <- entry.text,
                    self.x <- entry.x,
                    self.y <- entry.y,
                    self.w <- entry.w,
                    self.h <- entry.h
                )
                try db.run(insert)
            }
        }
    }
    
    func insertAllTextForFrame(frameId: Int64, text: String) {
        let insert = allText.insert(self.frameId <- frameId, self.text <- text)
        try! db.run(insert)
    }
    
    func getFrame(forIndex index: Int64) -> (offsetIndex: Int64, filePath: String)? {
        do {
            let query = frames.join(videoChunks, on: chunkId == videoChunks[id]).filter(frames[id] == index).limit(1)
            if let frame = try db.pluck(query) {
                return (frame[offsetIndex], frame[filePath])
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    func getChunksFramesIndex(frameId index: Int64) -> Int64? {
        do {
            let query = chunksFramesView.filter(frameId == index).limit(1)
            if let frame = try db.pluck(query) {
                return frame[chunksFramesIndex]
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    func getFrameByChunksFramesIndex(forIndex index: Int64) -> (offsetIndex: Int64, filePath: String)? {
        do {
            let query = chunksFramesView.filter(chunksFramesIndex == index).limit(1)
            if let frame = try db.pluck(query) {
                return (frame[offsetIndex], frame[filePath])
            }
            
            //  let justFrameQuery = frames.filter(frames[id] === index).limit(1)
            //  try! db.run(justFrameQuery.delete())
        } catch {
            return nil
        }
        
        return nil
    }
    
    func frameExists(forIndex index: Int64) -> Bool {
        do {
            let query = frames.join(videoChunks, on: chunkId == videoChunks[id]).filter(frames[id] == index).exists
            return try db.scalar(query)
        } catch {
            return false
        }
    }
    
    // Function to retrieve the file path of a video chunk by its index
    func getVideoChunkPath(byIndex index: Int64) -> String? {
        do {
            let query = videoChunks.filter(chunkId == index)
            if let chunk = try db.pluck(query) {
                return chunk[filePath]
            }
        } catch {
            return nil
        }
        return nil
    }
    
    // Function to get the timestamp of the last inserted frame
    private func getLastFrameTimestamp() -> Date? {
        do {
            let query = frames.select(timestamp).order(id.desc).limit(1)
            if let lastFrame = try db.pluck(query) {
                return lastFrame[timestamp]
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func getLastFrameIndexFromDB() -> Int64? {
        do {
            let query = frames.select(id).order(id.desc).limit(1)
            if let lastFrame = try db.pluck(query) {
                return lastFrame[id]
            }
        } catch {
            return nil
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
    
    func getMaxChunksFramesIndex() -> Int64 {
        return lastChunksFramesIndex
    }
    
    func getLastAccessibleFrame() -> Int64 {
        do {
            let query = frames.join(videoChunks, on: chunkId == videoChunks[id]).select(frames[id]).order(frames[id].desc).limit(1)
            if let lastFrame = try db.pluck(query) {
                return lastFrame[id]
            }
        } catch {
            return 0
        }
        return 0
    }
    
    func search(appName: String = "", searchText: String, limit: Int = 9, offset: Int = 0) -> [(frameId: Int64, fullText: String, applicationName: String?, timestamp: Date, filePath: String, offsetIndex: Int64)] {
        var partialQuery = allText
            .join(frames, on: frames[id] == allText[frameId])
            .join(videoChunks, on: frames[chunkId] == videoChunks[id])

        if !appName.isEmpty {
            partialQuery = partialQuery.join(uniqueAppNames, on: uniqueAppNames[activeApplicationName] == frames[activeApplicationName])
        }

        var query = partialQuery
                     .filter(text.match("*\(searchText)*"))

        if !appName.isEmpty && searchText.isEmpty {
            query = partialQuery
                     .filter(uniqueAppNames[activeApplicationName].lowercaseString == appName.lowercased())
        } else if !appName.isEmpty && !searchText.isEmpty {
            query = query.filter(uniqueAppNames[activeApplicationName].lowercaseString == appName.lowercased())
        }

        query = query.select(allText[frameId], text, frames[activeApplicationName], frames[timestamp], videoChunks[filePath], frames[offsetIndex])
                     .limit(limit, offset: offset)
        
        var results: [(Int64, String, String?, Date, String, Int64)] = []
        do {
            for row in try db.prepare(query) {
                let frameId = row[allText[frameId]]
                let matchedText = row[text]
                let applicationName = row[frames[activeApplicationName]]
                let timestamp = row[frames[timestamp]]
                let filePath = row[videoChunks[filePath]]
                let offsetIndex = row[frames[offsetIndex]]
                results.append((frameId, matchedText, applicationName, timestamp, filePath, offsetIndex))
            }
        } catch {
            print("Search error: \(error)")
        }
        return results
    }
    
    func getRecentResults(selectedFilterApp: String = "", limit: Int = 9, offset: Int = 0) -> [(frameId: Int64, fullText: String?, applicationName: String?, timestamp: Date, filePath: String, offsetIndex: Int64)] {
        var query = frames
            .join(videoChunks, on: frames[chunkId] == videoChunks[id])
            .select(frames[id], frames[activeApplicationName], frames[timestamp], videoChunks[filePath], frames[offsetIndex])
            .order(frames[timestamp].desc)
            .limit(limit, offset: offset)

        if !selectedFilterApp.isEmpty {
            query = query
                .join(uniqueAppNames, on: uniqueAppNames[activeApplicationName] == frames[activeApplicationName])
                .filter(uniqueAppNames[activeApplicationName].lowercaseString == selectedFilterApp.lowercased())
        }
        
        var results: [(Int64, String?, String?, Date, String, Int64)] = []
        do {
            for row in try db.prepare(query) {
                let frameId = row[frames[id]]
                let applicationName = row[frames[activeApplicationName]]
                let timestamp = row[frames[timestamp]]
                let filePath = row[videoChunks[filePath]]
                let offsetIndex = row[frames[offsetIndex]]
                results.append((frameId, nil, applicationName, timestamp, filePath, offsetIndex))
            }
        } catch {
            print("Error fetching recent results: \(error)")
        }
        return results
    }
    
    func getAllApplicationNames() -> [String] {
        var applicationNames: [String] = []
        
        do {
            let distinctAppsQuery = uniqueAppNames.select(activeApplicationName)
            for row in try db.prepare(distinctAppsQuery) {
                if let appName = row[activeApplicationName] {
                    applicationNames.append(appName)
                }
            }
        } catch {
            print("Error fetching application names: \(error)")
        }
        
        return applicationNames
    }

    func getImage(index: Int64, maxSize: CGSize? = nil) -> CGImage? {
        guard let frameData = DatabaseManager.shared.getFrame(forIndex: index) else { return nil }
        
        let videoURL = URL(fileURLWithPath: frameData.filePath)
        return extractFrame(from: videoURL, frameOffset: frameData.offsetIndex, maxSize: maxSize)
    }
    
    func getImageByChunksFramesIndex(index: Int64, maxSize: CGSize? = nil) -> CGImage? {
        guard let frameData = DatabaseManager.shared.getFrameByChunksFramesIndex(forIndex: index) else { return nil }
        
        let videoURL = URL(fileURLWithPath: frameData.filePath)
        return extractFrame(from: videoURL, frameOffset: frameData.offsetIndex, maxSize: maxSize)
    }
    
    func getImages(filePath: String, frameOffsets: [Int64], maxSize: CGSize? = nil) -> AVAssetImageGenerator.Images {
        let videoURL = URL(fileURLWithPath: filePath)
        return extractFrames(from: videoURL, frameOffsets: frameOffsets, maxSize: maxSize)
    }
    
    func extractFrame(from videoURL: URL, frameOffset: Int64, maxSize: CGSize? = nil) -> CGImage? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        if let maxSize = maxSize {
            generator.maximumSize = maxSize
        }
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime.zero
        generator.requestedTimeToleranceAfter = CMTime.zero
        
        do {
            let a = CMTime(value: frameOffset, timescale: DatabaseManager.FPS)
            let aI = try generator.copyCGImage(at: a, actualTime: nil)
            return aI
        } catch {
            print("Error extracting frame \(videoURL): \(error)")
            return nil
        }
    }
    
    func extractFrames(from videoURL: URL, frameOffsets: [Int64], maxSize: CGSize? = nil) -> AVAssetImageGenerator.Images {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        if let maxSize = maxSize {
            generator.maximumSize = maxSize
        }
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime.zero
        generator.requestedTimeToleranceAfter = CMTime.zero
        
        return generator.images(for: frameOffsets.map { o in CMTime(value: o, timescale: DatabaseManager.FPS) })
    }
}
