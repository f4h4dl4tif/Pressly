import AppKit
// Renders the Pressly icon: a graphite squircle holding a single cream keycap.
let out = CommandLine.arguments[1]
let sizes: [(String, Int)] = [("16x16",16),("16x16@2x",32),("32x32",32),("32x32@2x",64),("128x128",128),("128x128@2x",256),("256x256",256),("256x256@2x",512),("512x512",512),("512x512@2x",1024)]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: 1) }
for (name, px) in sizes {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.1
    let body = NSRect(x: inset, y: inset, width: s - 2*inset, height: s - 2*inset)
    let squircle = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
    NSGradient(colors: [c(58, 59, 66), c(26, 27, 31)])!.draw(in: squircle, angle: -90)
    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()
    // Keycap: shadow, skirt, top.
    let k = body.width * 0.56
    let capRect = NSRect(x: body.midX - k/2, y: body.midY - k/2 - body.width*0.02, width: k, height: k)
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.55); shadow.shadowBlurRadius = s*0.05; shadow.shadowOffset = NSSize(width: 0, height: -s*0.03)
    NSGraphicsContext.current?.saveGraphicsState()
    shadow.set()
    let skirt = NSBezierPath(roundedRect: capRect, xRadius: k*0.2, yRadius: k*0.2)
    NSGradient(colors: [c(214, 200, 168), c(160, 142, 108)])!.draw(in: skirt, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()
    let topRect = NSRect(x: capRect.minX + k*0.12, y: capRect.minY + k*0.2, width: k*0.76, height: k*0.7)
    let top = NSBezierPath(roundedRect: topRect, xRadius: k*0.15, yRadius: k*0.15)
    NSGradient(colors: [c(250, 245, 232), c(232, 220, 194)])!.draw(in: top, angle: -60)
    NSColor.white.withAlphaComponent(0.5).setStroke(); top.lineWidth = max(0.5, s*0.004); top.stroke()
    // Sound arcs to the right of the cap.
    let center = NSPoint(x: capRect.maxX + body.width*0.02, y: capRect.midY + k*0.05)
    for (i, r) in [0.1, 0.17].enumerated() {
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: body.width*CGFloat(r), startAngle: -40, endAngle: 40)
        arc.lineWidth = max(1, body.width*0.028); arc.lineCapStyle = .round
        c(201, 164, 106).withAlphaComponent(0.95 - Double(i)*0.3).setStroke(); arc.stroke()
    }
    NSGraphicsContext.current?.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
