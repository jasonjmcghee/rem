//
//  ImageResizer.swift
//  rem
//
//  Created by Jason McGhee on 1/17/24.
//

import Foundation
import Cocoa

class ImageResizer {
    private var context: CGContext
    private let targetWidth: CGFloat
    private let targetHeight: CGFloat

    init(targetWidth: Int, targetHeight: Int) {
        self.targetWidth = CGFloat(targetWidth)
        self.targetHeight = CGFloat(targetHeight)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        context = CGContext(data: nil, width: targetWidth, height: targetHeight, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo)!
    }

    func resizeAndPad(image: CGImage) -> CGImage? {
        let widthScaleRatio = targetWidth / CGFloat(image.width)
        let heightScaleRatio = targetHeight / CGFloat(image.height)
        let scaleFactor = min(widthScaleRatio, heightScaleRatio)

        let scaledWidth = CGFloat(image.width) * scaleFactor
        let scaledHeight = CGFloat(image.height) * scaleFactor
        let imageRect = CGRect(x: (targetWidth - scaledWidth) / 2, y: (targetHeight - scaledHeight) / 2, width: scaledWidth, height: scaledHeight)

        context.clear(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        context.interpolationQuality = .high
        context.draw(image, in: imageRect)

        return context.makeImage()
    }
}
