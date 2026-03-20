import SwiftUI
import AppKit

enum LineColors {
    // Basel BVB/BLT tram line colors (official)
    private static let hex: [String: UInt] = [
        "1":  0x8B6914, // dark gold/brown
        "2":  0x7B5B8D, // purple
        "3":  0x8B8C2A, // olive green
        "6":  0x4A8C6E, // dark green
        "8":  0xD08050, // salmon/orange
        "10": 0xD0A030, // golden yellow
        "11": 0xC83838, // red
        "14": 0xD07098, // pink
        "15": 0xC87838, // orange
        "16": 0xC89838, // dark golden
        "17": 0x48A080, // teal
        "21": 0x50B060, // green
    ]

    private static func fromHex(_ hex: UInt) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        (
            r: CGFloat((hex >> 16) & 0xFF) / 255.0,
            g: CGFloat((hex >> 8) & 0xFF) / 255.0,
            b: CGFloat(hex & 0xFF) / 255.0
        )
    }

    static let colors: [String: Color] = {
        var result: [String: Color] = [:]
        for (line, h) in hex {
            let c = fromHex(h)
            result[line] = Color(red: c.r, green: c.g, blue: c.b)
        }
        return result
    }()

    static let nsColors: [String: NSColor] = {
        var result: [String: NSColor] = [:]
        for (line, h) in hex {
            let c = fromHex(h)
            result[line] = NSColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
        }
        return result
    }()

    static let busColor = Color(red: 0x3D / 255.0, green: 0x7A / 255.0, blue: 0x3D / 255.0)
    static let busNSColor = NSColor(red: 0x3D / 255.0, green: 0x7A / 255.0, blue: 0x3D / 255.0, alpha: 1)

    static func color(for line: String, category: String = "T") -> Color {
        if category == "B" || category == "NFB" || category == "bus" {
            return busColor
        }
        return colors[line] ?? .gray
    }

    static func nsColor(for line: String, category: String = "T") -> NSColor {
        if category == "B" || category == "NFB" || category == "bus" {
            return busNSColor
        }
        return nsColors[line] ?? .gray
    }

    /// Renders a colored line badge as an NSImage suitable for the menu bar
    static func menuBarIcon(line: String, category: String = "T", height: CGFloat = 18) -> NSImage {
        let text = line as NSString
        let fontSize: CGFloat = line.count > 1 ? 10 : 11
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]

        let textSize = text.size(withAttributes: attributes)
        let padding: CGFloat = 4
        let width = max(height, textSize.width + padding * 2)
        let size = NSSize(width: width, height: height)
        let cornerRadius: CGFloat = 4

        let image = NSImage(size: size, flipped: false) { rect in
            let bgColor = LineColors.nsColor(for: line, category: category)
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            bgColor.setFill()
            path.fill()

            let textRect = NSRect(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
            return true
        }

        image.isTemplate = false
        return image
    }
}
