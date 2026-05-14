import AppKit
import CoreText

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let glyph = "虾"

struct AppIconVariant {
    let filePrefix: String
    let backgroundColor: NSColor
    let foregroundColor: NSColor
    let cornerRatio: CGFloat
    let glyphScale: CGFloat
    let verticalOffsetRatio: CGFloat
}

let variant = AppIconVariant(
    filePrefix: "wubi_icon",
    backgroundColor: NSColor(calibratedWhite: 0.08, alpha: 1.0),
    foregroundColor: .white,
    cornerRatio: 0.23,
    glyphScale: 0.58,
    verticalOffsetRatio: 0.01
)

func iconFont(for size: CGFloat) -> NSFont {
    NSFont(name: "PingFang SC Semibold", size: size)
        ?? NSFont.systemFont(ofSize: size, weight: .semibold)
}

func drawRoundedBackground(in rect: NSRect, color: NSColor, cornerRadius: CGFloat) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
}

func drawGlyph(_ glyph: String, in rect: NSRect, scale: CGFloat, verticalOffsetRatio: CGFloat, color: NSColor) {
    let fontSize = rect.width * scale
    let attributes: [NSAttributedString.Key: Any] = [
        .font: iconFont(for: fontSize),
        .foregroundColor: color
    ]
    let attributed = NSAttributedString(string: glyph, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributed)
    let context = NSGraphicsContext.current!.cgContext
    let bounds = CTLineGetImageBounds(line, context)
    let x = (rect.width - bounds.width) / 2 - bounds.minX
    let y = (rect.height - bounds.height) / 2 - bounds.minY + rect.height * verticalOffsetRatio
    context.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, context)
}

func renderIcon(size: Int, variant: AppIconVariant) -> NSBitmapImageRep {
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

    let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    rect.fill()

    drawRoundedBackground(
        in: rect,
        color: variant.backgroundColor,
        cornerRadius: CGFloat(size) * variant.cornerRatio
    )
    drawGlyph(
        glyph,
        in: rect,
        scale: variant.glyphScale,
        verticalOffsetRatio: variant.verticalOffsetRatio,
        color: variant.foregroundColor
    )

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

var pngsBySize: [Int: Data] = [:]

for size in sizes {
    let bitmap = renderIcon(size: size, variant: variant)
    guard let data = bitmap.representation(using: .png, properties: [:]) else { continue }
    pngsBySize[size] = data

    let filename = size <= 32
        ? "\(variant.filePrefix)_\(size)x\(size).png"
        : "\(variant.filePrefix)_\(size).png"
    let path = "\(outputDirectory)/\(filename)"
    try data.write(to: URL(fileURLWithPath: path))
    print("Generated: \(path)")
}

try writeICNS(named: variant.filePrefix, pngs: pngsBySize)
print("Done!")
