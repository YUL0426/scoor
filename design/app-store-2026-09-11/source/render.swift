import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Native, deterministic layout: the captured app screens are placed unchanged.
// Run from the repository root:
// swift -module-cache-path /tmp/scoor-artwork-module-cache design/app-store-2026-09-11/source/render.swift

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("design/app-store-2026-09-11")
let fm = FileManager.default
// One device at a time, to keep the local workload small.
let arguments = Array(CommandLine.arguments.dropFirst())
let devices = [arguments.first ?? "iphone-6.9"]
let locale = arguments.count > 1 ? arguments[1] : "ko-KR"
precondition(["ko-KR", "en-US"].contains(locale), "Choose one locale at a time")
let isKorean = locale == "ko-KR"
precondition(devices == ["iphone-6.9"], "This revision is the iPhone gallery")

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
let pages = isKorean ? [
    Copy(slug: "01-score", title: ["오늘 하루,", "몇 점인가요?"], subtitle: "0부터 100까지, 나의 하루를 기록해요."),
    Copy(slug: "02-world", title: ["세상의 토픽을", "함께 발견해요"], subtitle: "일상부터 문화·테크까지, 관심사로 이어져요."),
    Copy(slug: "03-perspectives", title: ["같은 토픽,", "다양한 시선."], subtitle: "점수와 한 줄에서 새로운 관점을 발견해요."),
    Copy(slug: "04-connection", title: ["멀리 있어도,", "이어지는 공감."], subtitle: "서로의 이야기를 읽고, 나의 생각도 남겨요."),
    Copy(slug: "05-records", title: ["나의 하루도,", "차곡차곡."], subtitle: "오늘의 점수와 한 줄을 기록으로 모아봐요.")
] : [
    Copy(slug: "01-score", title: ["How was", "your day?"], subtitle: "A score and a few words. Make today yours."),
    Copy(slug: "02-world", title: ["Explore the world.", "One topic at a time."], subtitle: "From culture to tech, see what others think."),
    Copy(slug: "03-perspectives", title: ["One topic.", "Many perspectives."], subtitle: "Discover a new point of view in every score."),
    Copy(slug: "04-connection", title: ["Different places.", "Shared feelings."], subtitle: "Read their stories. Add your perspective."),
    Copy(slug: "05-records", title: ["Your days,", "worth keeping."], subtitle: "Keep your scores and the moments behind them.")
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
    let dir = output.appendingPathComponent("upload/\(locale)/\(device)")
    try fm.createDirectory(at:dir, withIntermediateDirectories:true)
    for (index, copy) in pages.enumerated() {
        let canvas = Canvas(width:W,height:H)
        let light = index == 1 || index == 3
        canvas.fill(index == 0 ? red : light ? white : black)
        let ink = light ? black : white
        let margin: CGFloat = isPad ? 138 : 104
        let maxTextWidth = CGFloat(W) - 2*margin
        canvas.image(light ? redLogo : whiteLogo, x:margin,y:70,width:151,height:81)
        // Five quiet marks tie the gallery together.
        for dot in 0..<pages.count {
            canvas.round(CGFloat(W)-margin-156+CGFloat(dot)*32,102,20,5,2.5,
                         dot == index ? ink : ink.withAlphaComponent(0.22))
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
        let raw = output.appendingPathComponent("raw/\(locale)/\(device)/\(copy.slug).png")
        canvas.image(raw,x:screenX,y:screenY,width:screenW,height:screenH,radius:radius)
        if (1...3).contains(index) {
            canvas.text(isKorean ? "예시 토픽과 반응으로 구성한 화면입니다." : "Illustrative topics and reactions.",x:margin,y:2814,size:27,
                        color:ink.withAlphaComponent(0.55),weight:.regular,maxWidth:maxTextWidth,tracking:-0.5)
        }
        try canvas.save(dir.appendingPathComponent("\(copy.slug).png"))
        print("Rendered \(device)/\(copy.slug).png \(W)×\(H)")
    }
}

for device in devices {
    let isPad = device == "ipad-13"
    let thumbW: CGFloat = isPad ? 348 : 294
    let thumbH = thumbW * (isPad ? 2752/2064.0 : 2868/1320.0)
    let count = CGFloat(pages.count)
    let overview = Canvas(width:Int(48*2 + thumbW*count + 24*(count-1)),height:Int(thumbH+184))
    overview.fill(color("E9E7E3"))
    overview.text("SCOOR / APP STORE",x:48,y:31,size:23,color:black,tracking:0.3)
    overview.text(isKorean ? "iPhone 6.9″ · 한국어" : "iPhone 6.9″ · English",x:48,y:65,size:18,color:color("66615D"),weight:.regular,tracking:0)
    for (i,copy) in pages.enumerated() {
        let position = i
        let x = 48 + CGFloat(position)*(thumbW+24)
        overview.image(output.appendingPathComponent("upload/\(locale)/\(device)/\(copy.slug).png"),x:x,y:112,width:thumbW,height:thumbH)
        overview.text(String(format:"%02d",position+1),x:x,y:thumbH+128,size:16,color:color("66615D"),weight:.medium,tracking:0)
    }
    try overview.save(output.appendingPathComponent(isKorean ? "preview-\(device).png" : "preview-\(device)-en-US.png"))
}
