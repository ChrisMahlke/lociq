#!/usr/bin/env swift
//
//  generate_lociq_icon.swift
//  Lociq
//
//  Generates the Icon Composer source artwork for the LOC IQ app icon.
//
//  The output intentionally mirrors the in-app visual system: dark ink,
//  restrained white line work, a quiet demographic boundary, and the same
//  all-caps LOC IQ identity used in the bottom interface.
//

import AppKit
import CoreGraphics
import Foundation

private enum IconSpec {
    static let width = 1_024
    static let height = 1_024
    static let outputPath = "lociq.icon/Assets/icon.png"

    static let ink = NSColor(
        calibratedRed: 0.075,
        green: 0.075,
        blue: 0.072,
        alpha: 1.0
    )
    static let softWhite = NSColor(calibratedWhite: 1.0, alpha: 0.72)
    static let quietWhite = NSColor(calibratedWhite: 1.0, alpha: 0.38)
    static let boundaryWhite = NSColor(calibratedWhite: 1.0, alpha: 0.56)
    static let locationGold = NSColor(
        calibratedRed: 1.0,
        green: 0.82,
        blue: 0.22,
        alpha: 0.92
    )
}

private enum IconDrawing {
    /// Creates the bitmap-backed drawing surface used for reproducible icon output.
    static func makeCanvas() throws -> NSBitmapImageRep {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: IconSpec.width,
            pixelsHigh: IconSpec.height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw IconGenerationError.canvasUnavailable
        }

        bitmap.size = NSSize(width: IconSpec.width, height: IconSpec.height)
        return bitmap
    }

    /// Draws the complete LOC IQ icon into the provided bitmap.
    static func draw(in bitmap: NSBitmapImageRep) {
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context

        drawBackground()
        drawBoundary()
        drawIdentity()

        NSGraphicsContext.restoreGraphicsState()
    }

    /// Writes the bitmap as a PNG to the Icon Composer asset package.
    static func write(_ bitmap: NSBitmapImageRep) throws {
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw IconGenerationError.pngEncodingUnavailable
        }

        let url = URL(fileURLWithPath: IconSpec.outputPath)
        try data.write(to: url, options: .atomic)
    }

    /// Draws the dark app background and the subtle diagonal light plane.
    private static func drawBackground() {
        IconSpec.ink.setFill()
        NSRect(x: 0, y: 0, width: IconSpec.width, height: IconSpec.height).fill()

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: 618, yBy: 620)
        transform.rotate(byDegrees: -31)
        transform.concat()

        NSColor(calibratedWhite: 1.0, alpha: 0.046).setFill()
        NSRect(x: -132, y: -560, width: 264, height: 1_120).fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor(calibratedWhite: 1.0, alpha: 0.055).setStroke()
        let baseline = NSBezierPath()
        baseline.lineWidth = 2
        baseline.move(to: NSPoint(x: 224, y: 166))
        baseline.line(to: NSPoint(x: 800, y: 166))
        baseline.stroke()
    }

    /// Draws an abstract city boundary plus an approximate-location signal.
    private static func drawBoundary() {
        let points = [
            CGPoint(x: 0.46, y: 0.05),
            CGPoint(x: 0.25, y: 0.10),
            CGPoint(x: 0.12, y: 0.24),
            CGPoint(x: 0.08, y: 0.39),
            CGPoint(x: 0.14, y: 0.56),
            CGPoint(x: 0.10, y: 0.71),
            CGPoint(x: 0.28, y: 0.88),
            CGPoint(x: 0.45, y: 0.94),
            CGPoint(x: 0.61, y: 0.88),
            CGPoint(x: 0.76, y: 0.92),
            CGPoint(x: 0.91, y: 0.73),
            CGPoint(x: 0.84, y: 0.55),
            CGPoint(x: 0.93, y: 0.39),
            CGPoint(x: 0.78, y: 0.20),
            CGPoint(x: 0.62, y: 0.16)
        ]

        let frame = CGRect(x: 256, y: 390, width: 512, height: 374)
        let path = NSBezierPath()
        for (index, point) in points.enumerated() {
            let mapped = NSPoint(
                x: frame.minX + point.x * frame.width,
                y: frame.minY + point.y * frame.height
            )

            if index == 0 {
                path.move(to: mapped)
            } else {
                path.line(to: mapped)
            }
        }

        path.close()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = 3
        IconSpec.boundaryWhite.setStroke()
        path.stroke()

        NSColor(calibratedWhite: 1.0, alpha: 0.12).setStroke()
        let inner = NSBezierPath()
        inner.lineWidth = 1
        inner.move(to: NSPoint(x: 392, y: 488))
        inner.curve(
            to: NSPoint(x: 642, y: 626),
            controlPoint1: NSPoint(x: 476, y: 530),
            controlPoint2: NSPoint(x: 566, y: 578)
        )
        inner.stroke()

        let location = NSPoint(x: 536, y: 548)
        IconSpec.locationGold.setFill()
        NSBezierPath(ovalIn: NSRect(x: location.x - 9, y: location.y - 9, width: 18, height: 18)).fill()

        NSColor(
            calibratedRed: 1.0,
            green: 0.82,
            blue: 0.22,
            alpha: 0.18
        ).setStroke()
        let ring = NSBezierPath(ovalIn: NSRect(x: location.x - 44, y: location.y - 44, width: 88, height: 88))
        ring.lineWidth = 2
        ring.stroke()
    }

    /// Draws the LOC IQ identity and terse product descriptor.
    private static func drawIdentity() {
        let brandFont = NSFont.systemFont(ofSize: 118, weight: .ultraLight)
        let descriptorFont = NSFont.systemFont(ofSize: 27, weight: .light)

        drawCentered(
            "LOC IQ",
            in: NSRect(x: 96, y: 222, width: 832, height: 152),
            font: brandFont,
            color: IconSpec.softWhite
        )

        drawCentered(
            "CITY DEMOGRAPHICS",
            in: NSRect(x: 96, y: 178, width: 832, height: 44),
            font: descriptorFont,
            color: IconSpec.quietWhite
        )
    }

    /// Draws centered text with neutral letter spacing to match the app UI.
    private static func drawCentered(
        _ string: String,
        in rect: NSRect,
        font: NSFont,
        color: NSColor
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
            .kern: 0
        ]

        NSString(string: string).draw(in: rect, withAttributes: attributes)
    }
}

private enum IconGenerationError: Error {
    case canvasUnavailable
    case pngEncodingUnavailable
}

do {
    let bitmap = try IconDrawing.makeCanvas()
    IconDrawing.draw(in: bitmap)
    try IconDrawing.write(bitmap)
} catch {
    fputs("Failed to generate LOC IQ icon: \(error)\n", stderr)
    exit(1)
}
