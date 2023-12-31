//
//  ImageUtils.swift
//  rem
//
//  Created by Stefan Eletzhofer on 31.12.23.
//

import Foundation
import Cocoa

// Function to create a cropped NSImage from CGImage
func croppedImage(from cgImage: CGImage, frame: CGRect) -> NSImage? {
    // Create a new NSImage with the CGImage
    let nsImage = NSImage(cgImage: cgImage, size: NSZeroSize)

    // Begin a new image context to draw the cropped image
    let imageRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(frame.width),
        pixelsHigh: Int(frame.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: NSColorSpaceName.deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: imageRep!)
    
    // Set the context to the portion of the image we want to draw
    let context = NSGraphicsContext.current!.cgContext
    context.draw(cgImage, in: CGRect(x: -frame.origin.x, y: frame.origin.y - (nsImage.size.height - frame.height), width: nsImage.size.width, height: nsImage.size.height))

    NSGraphicsContext.restoreGraphicsState()

    // Create a new NSImage from the image representation
    let croppedImage = NSImage(size: frame.size)
    croppedImage.addRepresentation(imageRep!)

    return croppedImage
}
