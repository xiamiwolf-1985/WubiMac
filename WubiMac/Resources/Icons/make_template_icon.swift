import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1.0)

for size in sizes {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let img = NSImage(size: rect.size)

    img.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let cornerRadius = CGFloat(size) * 0.23
    backgroundColor.setFill()
    NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()

    let fontSize = CGFloat(size) * 0.58
    let font = NSFont(name: "PingFang SC Semibold", size: fontSize)
        ?? NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    let attr: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]

    let string = "虾"
    let stringSize = string.size(withAttributes: attr)
    let stringRect = NSRect(
        x: (rect.width - stringSize.width) / 2,
        y: (rect.height - stringSize.height) / 2 + CGFloat(size) * 0.01,
        width: stringSize.width,
        height: stringSize.height
    )

    string.draw(in: stringRect, withAttributes: attr)
    img.unlockFocus()

    if let tiff = img.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let data = bitmap.representation(using: .png, properties: [:]) {
        let filename = size <= 32 ? "wubi_icon_\(size)x\(size).png" : "wubi_icon_\(size).png"
        let outputPath = CommandLine.arguments.count > 1
            ? "\(CommandLine.arguments[1])/\(filename)"
            : filename
        try? data.write(to: URL(fileURLWithPath: outputPath))
        print("Generated: \(outputPath)")
    }
}

print("Done!")
