import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Native, deterministic layout: the captured app screens are placed unchanged.
// Run from the repository root:
// swift -module-cache-path /tmp/scoor-artwork-module-cache design/app-store-2026-09-10/source/render.swift

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("design/app-store-2026-09-10")
let fm = FileManager.default
// One device at a time, to keep the local workload small.
let devices = Array(CommandLine.arguments.dropFirst()).isEmpty
    ? ["iphone-6.9"] : Array(CommandLine.arguments.dropFirst())
precondition(devices.count == 1 && ["iphone-6.9", "ipad-13"].contains(devices[0]))

func color(_ hex: String) -> NSColor {
    let n = UInt32(hex, radix: 16)!
    return NSColor(srgbRed: CGFloat((n >> 16) & 255) / 255,
                   green: CGFloat((n >> 8) & 255) / 255,
                   blue: CGFloat(n & 255) / 255, alpha: 1)
}
let red = color("CE3B22")
let white = color("FAF8F5")
let black = color("0A0A0B")

struct Copy {
    let slug: String
    let title: [String]
    let subtitle: String
}
let pages = [
    Copy(slug: "01-score", title: ["오늘 하루,", "몇 점인가요?"], subtitle: "0부터 100까지, 나의 하루를 기록해요."),
    Copy(slug: "02-records", title: ["점수와 한 줄로", "남기는 오늘"], subtitle: "그날의 점수와 이유를 함께 모아봐요."),
    Copy(slug: "03-stats", title: ["쌓인 기록에서", "나를 발견해요"], subtitle: "일별·주별·월별로 나의 흐름을 살펴요."),
    Copy(slug: "04-calendar", title: ["하루하루 쌓이는", "나만의 기록"], subtitle: "달력에서 그날의 마음을 다시 만나보세요.")
]

final class Canvas {
    let width: CGFloat
    let height: CGFloat
    let context: CGContext
    init(width: Int, height: Int) {
        self.width = CGFloat(width); self.height = CGFloat(height)
        context = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
                            space:CGColorSpace(name:CGColorSpace.sRGB)!,
                            bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext:context,flipped:false)
        NSGraphicsContext.current?.imageInterpolation = .high
    }
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: x, y: height-y-h, width: w, height: h)
    }
    func fill(_ c: NSColor) { c.setFill(); NSRect(x:0,y:0,width:width,height:height).fill() }
    func round(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat, _ c: NSColor) {
        c.setFill(); NSBezierPath(roundedRect:rect(x,y,w,h),xRadius:radius,yRadius:radius).fill()
    }
    func line(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ c: NSColor) {
        c.setFill(); rect(x,y,w,2).fill()
    }
    func text(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, color: NSColor,
              weight: NSFont.Weight = .bold, maxWidth: CGFloat? = nil, tracking: CGFloat = -2) {
        let face = weight == .regular ? "Pretendard-Regular" : weight == .medium ? "Pretendard-Medium" : "Pretendard-Bold"
        let font = NSFont(name: face, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
        let attrs: [NSAttributedString.Key: Any] = [.font:font, .foregroundColor:color, .kern:tracking]
        let s = NSAttributedString(string:text, attributes:attrs)
        let b = s.boundingRect(with: NSSize(width:10000,height:10000), options:[.usesLineFragmentOrigin,.usesFontLeading])
        if let maxWidth, b.width > maxWidth { fatalError("Text overflow: \(text) (\(b.width) > \(maxWidth))") }
        s.draw(in:rect(x,y,b.width+6,b.height+6))
    }
    func image(_ url: URL, x: CGFloat, y: CGFloat, width w: CGFloat, height h: CGFloat, radius: CGFloat = 0) {
        guard let image = NSImage(contentsOf:url) else { fatalError("Missing image: \(url.path)") }
        NSGraphicsContext.saveGraphicsState()
        if radius > 0 { NSBezierPath(roundedRect:rect(x,y,w,h), xRadius:radius,yRadius:radius).addClip() }
        image.draw(in:rect(x,y,w,h), from:.zero, operation:.sourceOver, fraction:1)
        NSGraphicsContext.restoreGraphicsState()
    }
    func save(_ url: URL) throws {
        NSGraphicsContext.restoreGraphicsState()
        let destination = CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(destination,context.makeImage()!,nil)
        precondition(CGImageDestinationFinalize(destination),"PNG export failed")
    }
}

let whiteLogo = root.appendingPathComponent("Scoor/Assets.xcassets/ScoorWordmarkWhite.imageset/ScoorWordmarkWhite.png")
let redLogo = root.appendingPathComponent("Scoor/Assets.xcassets/ScoorWordmark.imageset/ScoorWordmark.png")

for device in devices {
    let isPad = device == "ipad-13"
    let W = isPad ? 2064 : 1320
    let H = isPad ? 2752 : 2868
    let dir = output.appendingPathComponent("upload/ko-KR/\(device)")
    try fm.createDirectory(at:dir, withIntermediateDirectories:true)
    for (index, copy) in pages.enumerated() {
        // The iPad score sheet exposes the fixture's preview feed behind it.
        // Use the three full-page journal screens for the submission gallery.
        if isPad && index == 0 { continue }
        let canvas = Canvas(width:W,height:H)
        let light = index == 1 || index == 3
        canvas.fill(index == 0 ? red : light ? white : black)
        let ink = light ? black : white
        let margin: CGFloat = isPad ? 138 : 104
        let maxTextWidth = CGFloat(W) - 2*margin
        canvas.image(light ? redLogo : whiteLogo, x:margin,y:70,width:151,height:81)
        // Four quiet marks tie the gallery together without adding another message.
        for dot in 0..<(isPad ? 3 : 4) {
            canvas.round(CGFloat(W)-margin-124+CGFloat(dot)*32,102,20,5,2.5,
                         dot == (isPad ? index-1 : index) ? ink : ink.withAlphaComponent(0.22))
        }
        let titleY: CGFloat = isPad ? 197 : 229
        let titleSize: CGFloat = isPad ? 121 : 108
        let lineHeight: CGFloat = isPad ? 137 : 126
        for (line, value) in copy.title.enumerated() {
            canvas.text(value,x:margin,y:titleY+CGFloat(line)*lineHeight,size:titleSize,
                        color:line == 1 && index != 0 ? red : ink,maxWidth:maxTextWidth,tracking:-3.2)
        }
        canvas.text(copy.subtitle,x:margin,y:titleY+2*lineHeight+28,size:isPad ? 43 : 38,
                    color:ink.withAlphaComponent(0.72),weight:.regular,maxWidth:maxTextWidth,tracking:-0.8)

        let screenW: CGFloat = isPad ? 1548 : 966
        let screenH = screenW * CGFloat(H) / CGFloat(W)
        let screenX = (CGFloat(W)-screenW)/2
        let screenY: CGFloat = isPad ? 592 : 672
        let bezel: CGFloat = isPad ? 20 : 16
        let radius: CGFloat = isPad ? 40 : 92
        // A simple front-on frame keeps the app legible and its original proportions.
        canvas.round(screenX-bezel-3,screenY-bezel-3,screenW+2*bezel+6,screenH+2*bezel+6,
                     radius+bezel+3,light ? color("BDBAB6") : color("646163"))
        canvas.round(screenX-bezel,screenY-bezel,screenW+2*bezel,screenH+2*bezel,radius+bezel,color("141415"))
        let raw = output.appendingPathComponent("raw/ko-KR/\(device)/\(copy.slug).png")
        canvas.image(raw,x:screenX,y:screenY,width:screenW,height:screenH,radius:radius)
        try canvas.save(dir.appendingPathComponent("\(copy.slug).png"))
        print("Rendered \(device)/\(copy.slug).png \(W)×\(H)")
    }
}

for device in devices {
    let isPad = device == "ipad-13"
    let thumbW: CGFloat = isPad ? 348 : 294
    let thumbH = thumbW * (isPad ? 2752/2064.0 : 2868/1320.0)
    let count: CGFloat = isPad ? 3 : 4
    let overview = Canvas(width:Int(48*2 + thumbW*count + 24*(count-1)),height:Int(thumbH+184))
    overview.fill(color("E9E7E3"))
    overview.text("SCOOR / APP STORE",x:48,y:31,size:23,color:black,tracking:0.3)
    overview.text(isPad ? "iPad 13″ · 한국어" : "iPhone 6.9″ · 한국어",x:48,y:65,size:18,color:color("66615D"),weight:.regular,tracking:0)
    for (i,copy) in pages.enumerated() {
        if isPad && i == 0 { continue }
        let position = isPad ? i-1 : i
        let x = 48 + CGFloat(position)*(thumbW+24)
        overview.image(output.appendingPathComponent("upload/ko-KR/\(device)/\(copy.slug).png"),x:x,y:112,width:thumbW,height:thumbH)
        overview.text(String(format:"%02d",position+1),x:x,y:thumbH+128,size:16,color:color("66615D"),weight:.medium,tracking:0)
    }
    try overview.save(output.appendingPathComponent("preview-\(device).png"))
}
