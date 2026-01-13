
import Cocoa
import CoreGraphics

// 配置
let fileManager = FileManager.default
let currentDirectory = fileManager.currentDirectoryPath

// 辅助函数：保存图像
func saveImage(_ image: CGImage, to url: URL) {
    let bitmapRep = NSBitmapImageRep(cgImage: image)
    guard let data = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Error creating PNG data")
        return
    }
    do {
        try data.write(to: url)
        print("Saved: \(url.lastPathComponent)")
    } catch {
        print("Error saving file: \(error)")
    }
}

// 辅助函数：绘制盾牌路径
func createShieldPath(in rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    let w = rect.width
    let h = rect.height
    
    // 简单的盾牌形状
    // 顶部宽，底部尖
    let topWidth = w * 0.8
    let bottomPoint = CGPoint(x: w * 0.5, y: h * 0.9)
    let topLeft = CGPoint(x: (w - topWidth) / 2, y: h * 0.15)
    let topRight = CGPoint(x: w - (w - topWidth) / 2, y: h * 0.15)
    
    path.move(to: CGPoint(x: w * 0.5, y: h * 0.15)) // Top center (slight dip?) No, simple flat top or curved
    // Let's do a curved top
    path.move(to: topLeft)
    path.addQuadCurve(to: topRight, control: CGPoint(x: w * 0.5, y: h * 0.25)) // Curve down slightly in middle
    // path.addLine(to: topRight)
    
    // Sides curving to bottom
    path.addCurve(to: bottomPoint, 
                  control1: CGPoint(x: topRight.x, y: h * 0.6), 
                  control2: CGPoint(x: w * 0.5, y: h * 0.75))
                  
    path.addCurve(to: topLeft, 
                  control1: CGPoint(x: w * 0.5, y: h * 0.75), 
                  control2: CGPoint(x: topLeft.x, y: h * 0.6))
    
    path.closeSubpath()
    return path
}

enum IconStyle {
    case light
    case dark
    case tinted
    case launch
}

func generateIcon(size: Int, style: IconStyle, filename: String) {
    let width = size
    let height = size
    let rect = CGRect(x: 0, y: 0, width: width, height: height)
    
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    
    // 1. Background
    context.saveGState()
    switch style {
    case .light:
        context.setFillColor(CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(rect)
    case .dark:
        context.setFillColor(CGColor(srgbRed: 0.1, green: 0.1, blue: 0.12, alpha: 1.0))
        context.fill(rect)
    case .tinted:
        // Transparent background
        context.clear(rect)
    case .launch:
         // Transparent, just the symbol
        context.clear(rect)
    }
    context.restoreGState()
    
    // 2. Shield Symbol
    context.saveGState()
    
    // Scale and center the shield
    let scale: CGFloat = style == .launch ? 0.9 : 0.8
    let shieldSize = CGSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
    let origin = CGPoint(x: (CGFloat(width) - shieldSize.width) / 2, y: (CGFloat(height) - shieldSize.height) / 2)
    let shieldRect = CGRect(origin: origin, size: shieldSize)
    
    let path = createShieldPath(in: shieldRect)
    context.addPath(path)
    
    switch style {
    case .light:
        // Gradient Blue
        let colors = [
            CGColor(srgbRed: 0.0, green: 0.4, blue: 0.8, alpha: 1.0),
            CGColor(srgbRed: 0.0, green: 0.7, blue: 1.0, alpha: 1.0)
        ] as CFArray
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
        context.clip()
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: CGFloat(height)), options: [])
        
    case .dark:
        // Bright Blue/Cyan
         let colors = [
            CGColor(srgbRed: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),
            CGColor(srgbRed: 0.0, green: 0.8, blue: 0.9, alpha: 1.0)
        ] as CFArray
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
        context.clip()
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: CGFloat(height)), options: [])
        
    case .tinted:
        // Solid Black (for alpha mask) or Grey
        // For 'tinted', iOS expects the alpha to define the shape. 
        // Typically a semi-transparent fill or solid fill.
        context.setFillColor(CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0))
        context.fillPath()
        
    case .launch:
        // Matching the Light mode style usually, or single color
        context.setFillColor(CGColor(srgbRed: 0.0, green: 0.5, blue: 1.0, alpha: 1.0))
        context.fillPath()
    }
    
    context.restoreGState()
    
    if let image = context.makeImage() {
        let url = URL(fileURLWithPath: currentDirectory).appendingPathComponent(filename)
        saveImage(image, to: url)
    }
}

// Generate
generateIcon(size: 1024, style: .light, filename: "AppIcon-Light.png")
generateIcon(size: 1024, style: .dark, filename: "AppIcon-Dark.png")
generateIcon(size: 1024, style: .tinted, filename: "AppIcon-Tinted.png")
generateIcon(size: 256, style: .launch, filename: "LaunchIcon.png")
