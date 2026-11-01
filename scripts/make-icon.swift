import AppKit

let output = CommandLine.arguments[1]
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 1024)
        transform.concat()
        NSColor(calibratedWhite: 0.14, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900), xRadius: 202, yRadius: 202).fill()
        NSColor(calibratedWhite: 0.90, alpha: 1).setStroke()
        let socket = NSBezierPath(roundedRect: NSRect(x: 270, y: 365, width: 484, height: 294), xRadius: 44, yRadius: 44)
        socket.lineWidth = 36
        socket.stroke()
        let contacts = NSBezierPath()
        for x in [360.0, 460.0, 560.0, 660.0] {
            contacts.move(to: NSPoint(x: x, y: 557))
            contacts.line(to: NSPoint(x: x, y: 615))
        }
        contacts.lineWidth = 25
        contacts.lineCapStyle = .round
        contacts.stroke()
        let cable = NSBezierPath()
        cable.move(to: NSPoint(x: 512, y: 365))
        cable.line(to: NSPoint(x: 512, y: 245))
        cable.lineWidth = 36
        cable.stroke()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output)
            .appendingPathComponent("icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"))
    }
}
