//
//  WindowHelper.swift
//  rem
//
//  Created by Stefan Eletzhofer on 31.12.23.
//
// Adopted from https://stackoverflow.com/questions/72763902/swift-get-a-list-of-opened-app-windows-with-desktop-number-and-position-info
//

import os
import Foundation
import CoreGraphics
import Cocoa

class WindowHelper {
    private let logger = Logger()
    static let shared: WindowHelper = WindowHelper()

    func getActiveWindowInfo(forApp application: NSRunningApplication) -> NSDictionary? {
        let windowsInfo = CGWindowListCopyWindowInfo(CGWindowListOption.optionOnScreenOnly, CGWindowID(0))
        
        let pid = application.processIdentifier
        logger.debug("Active application PID: \(pid)")
        if pid > 0 {
            let windowInfos = Array<NSDictionary>.fromCFArray(records: windowsInfo) ?? []
            
            // it appears that the first window listed is the active window ...
            for windowInfo in windowInfos.filter({$0["kCGWindowOwnerPID"] as! Int64 == pid}) {
                return windowInfo
            }
        }
        return nil
    }
    
    func getActiveWindowBounds(forApp application: NSRunningApplication) -> CGRect? {
        if
            let wi : NSDictionary = getActiveWindowInfo(forApp: application),
            let bounds : NSDictionary = wi["kCGWindowBounds"] as? NSDictionary,
            let x = bounds["X"] as? Double,
            let y = bounds["Y"] as? Double,
            let width = bounds["Width"] as? Double,
            let height = bounds["Height"] as? Double
        {
            return CGRect(x: x, y: y, width: width, height: height)
        }
        return nil
    }
   
}

extension Array {
    static func fromCFArray(records: CFArray?) -> Array<Element>? {
        var result: [Element]?
        if let records = records {
            for i in 0..<CFArrayGetCount(records) {
                let unmanagedObject: UnsafeRawPointer = CFArrayGetValueAtIndex(records, i)
                let rec: Element = unsafeBitCast(unmanagedObject, to: Element.self)
                if (result == nil){
                    result = [Element]()
                }
                result!.append(rec)
            }
        }
        return result
    }
}
