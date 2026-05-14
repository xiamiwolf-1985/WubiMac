import AppKit
import CoreText

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let glyph = "虾"

struct IconVariant {
    let name: String
    let background: NSColor
    let foreground: NSColor
}

let variants = [
    IconVariant(
        name: "wubi_menu_icon",
        background: NSColor(calibratedWhite: 0.08, alpha: 1.0),
        foreground: .white
    ),
    IconVariant(
        name: "wubi_menu_icon_alt",
        background: NSColor(calibratedWhite: 0.12, alpha: 1.0),
        foreground: NSColor(calibratedWhite: 0.96, alpha: 1.0)
    )
]

func font(for size: CGFloat) -> NSFont {
    NSFont(name: "PingFang SC Semibold", size: size)
        ?? NSFont.systemFont(ofSize: size, weight: .semibold)
}

func drawMenuIcon(size: Int, variant: IconVariant) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: size, height: size)
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let scale = CGFloat(size)

    let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    rect.fill()

    let cornerRadius = scale * 0.24
    variant.background.setFill()
    NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()

    let fontSize = scale * 0.72
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font(for: fontSize),
        .foregroundColor: variant.foreground
    ]
    let attributed = NSAttributedString(string: glyph, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributed)
    let context = NSGraphicsContext.current!.cgContext
    let inkBounds = CTLineGetImageBounds(line, context)

    let margin = max(1, scale * 0.12)
    let availableSize = scale - margin * 2
    let x = margin + (availableSize - inkBounds.width) / 2 - inkBounds.minX
    let y = margin + (availableSize - inkBounds.height) / 2 - inkBounds.minY + scale * 0.01

    context.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, context)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func appendFourCC(_ value: String, to data: inout Data) {
    data.append(value.data(using: .ascii)!)
}

func appendBigEndianUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

func writeICNS(named name: String, pngs: [Int: Data]) throws {
    let typesBySize = [
        16: "icp4",
        32: "icp5",
        64: "icp6",
        128: "ic07",
        256: "ic08",
        512: "ic09",
        1024: "ic10"
    ]

    var body = Data()
    for size in sizes {
        guard let type = typesBySize[size], let png = pngs[size] else { continue }
        appendFourCC(type, to: &body)
        appendBigEndianUInt32(UInt32(png.count + 8), to: &body)
        body.append(png)
    }

    var icns = Data()
    appendFourCC("icns", to: &icns)
    appendBigEndianUInt32(UInt32(body.count + 8), to: &icns)
    icns.append(body)

    let path = "\(outputDirectory)/\(name).icns"
    try icns.write(to: URL(fileURLWithPath: path), options: .atomic)
    print("Generated: \(path)")
}

for variant in variants {
    var pngsBySize: [Int: Data] = [:]

    for size in sizes {
        let bitmap = drawMenuIcon(size: size, variant: variant)
        if let data = bitmap.representation(using: .png, properties: [:]) {
            pngsBySize[size] = data
            let filename = size <= 32
                ? "\(variant.name)_\(size)x\(size).png"
                : "\(variant.name)_\(size).png"
            let path = "\(outputDirectory)/\(filename)"
            try data.write(to: URL(fileURLWithPath: path))
            print("Generated: \(path)")
        }
    }

    try writeICNS(named: variant.name, pngs: pngsBySize)
}

print("Done!")
