import AppKit

let size = NSSize(width: 128, height: 128)
let rect = NSRect(origin: .zero, size: size)

let img = NSImage(size: size)
img.lockFocus()

NSColor.systemBlue.setFill()
NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28).fill()

let attr: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 80, weight: .bold),
    .foregroundColor: NSColor.white
]

let string = "虾"
let stringSize = string.size(withAttributes: attr)
let stringRect = NSRect(
    x: (size.width - stringSize.width) / 2,
    y: (size.height - stringSize.height) / 2,
    width: stringSize.width,
    height: stringSize.height
)

string.draw(in: stringRect, withAttributes: attr)

img.unlockFocus()

if let data = img.tiffRepresentation {
    let pdfData = NSMutableData()
    let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!
    var mediaBox = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height))
    let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!
    
    pdfContext.beginPage(mediaBox: &mediaBox)
    let ciImage = CIImage(data: data)!
    let context = CIContext()
    let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
    pdfContext.draw(cgImage, in: mediaBox)
    pdfContext.endPage()
    
    let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "wubi_icon.pdf"
    pdfData.write(toFile: outputPath, atomically: true)
    print("Icon saved to: \(outputPath)")
}

