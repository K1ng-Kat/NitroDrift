import UIKit
import SceneKit

enum CityVisuals {
    static func roadMaterial() -> SCNMaterial {
        let image = texture(size: 256) { context, size in
            UIColor(red: 0.10, green: 0.105, blue: 0.125, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            var seed: UInt32 = 0x9AE310
            func random() -> CGFloat {
                seed = 1664525 &* seed &+ 1013904223
                return CGFloat(seed % 10_000) / 10_000
            }
            for _ in 0..<13_000 {
                let brightness = 0.07 + random() * 0.20
                UIColor(white: brightness, alpha: 0.18 + random() * 0.22).setFill()
                let x = random() * size.width
                let y = random() * size.height
                context.fill(CGRect(x: x, y: y, width: 0.5 + random() * 1.7,
                                    height: 0.5 + random() * 1.4))
            }
            UIColor(white: 0.20, alpha: 0.10).setStroke()
            for _ in 0..<30 {
                context.move(to: CGPoint(x: random() * size.width, y: random() * size.height))
                context.addLine(to: CGPoint(x: random() * size.width, y: random() * size.height))
            }
            context.strokePath()
        }
        let mat = SCNMaterial()
        mat.diffuse.contents = image
        mat.diffuse.wrapS = .repeat
        mat.diffuse.wrapT = .repeat
        mat.diffuse.contentsTransform = SCNMatrix4MakeScale(18, 18, 1)
        mat.roughness.contents = 0.77
        mat.metalness.contents = 0.08
        mat.lightingModel = .physicallyBased
        return mat
    }

    static func sky() -> UIImage {
        return texture(size: 512) { context, size in
            let colors = [
                UIColor(red: 0.006, green: 0.011, blue: 0.038, alpha: 1).cgColor,
                UIColor(red: 0.035, green: 0.045, blue: 0.10, alpha: 1).cgColor,
                UIColor(red: 0.115, green: 0.09, blue: 0.16, alpha: 1).cgColor
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors as CFArray, locations: [0, 0.58, 1])!
            context.drawLinearGradient(gradient, start: .zero,
                                       end: CGPoint(x: 0, y: size.height), options: [])
            var seed: UInt32 = 0xACED0121
            func random() -> CGFloat {
                seed = 1664525 &* seed &+ 1013904223
                return CGFloat(seed % 10_000) / 10_000
            }
            for _ in 0..<110 {
                let px = random() * size.width
                let py = random() * size.height * 0.66
                UIColor(white: 0.88, alpha: 0.08 + random() * 0.50).setFill()
                context.fill(CGRect(x: px, y: py, width: 1, height: 1))
            }
        }
    }

    private static func texture(size: Int, render: (CGContext, CGSize) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
            .image { renderer in render(renderer.cgContext, CGSize(width: size, height: size)) }
    }
}
