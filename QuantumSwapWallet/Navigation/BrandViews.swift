// BrandViews.swift
// Desktop / Android brand chrome drawn in code:
//   - LogoMarkView: silver ring (white -> #F2F3F5 -> #A8ADB8 diagonal
//     sweep) + two white satellite dots on a transparent background
//     (Android drawable-v24/logo_mark.xml, 48 viewport).
//   - GradientWordmarkLabel: the "QuantumSwap" wordmark painted with the
//     white -> #C084FC -> #00E5FF sweep (HomeActivity
//     applyBrandWordmarkGradient).
//   - BurgerIcon: three white rounded 3pt bars (drawable/ic_burger.xml).
//   - AmbientBackgroundView: #050508 base + violet / cyan radial orbs
//     (drawable-v24/body_ambient.xml, 360x780 viewport).

import UIKit

public final class LogoMarkView: UIView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError() }

    public override func draw(_ rect: CGRect) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        let s = min(bounds.width, bounds.height) / 48
        c.scaleBy(x: s, y: s)
        // Ring via even-odd fill, clipped to the diagonal gradient.
        let ring = UIBezierPath(ovalIn: CGRect(x: 5.5, y: 5.5, width: 37, height: 37))
        ring.append(UIBezierPath(ovalIn: CGRect(x: 11.5, y: 11.5, width: 25, height: 25)))
        ring.usesEvenOddFillRule = true
        c.saveGState()
        c.addPath(ring.cgPath)
        c.clip(using: .evenOdd)
        let colors = [UIColor.white.cgColor, UIColor(rgbHex: 0xF2F3F5).cgColor, UIColor(rgbHex: 0xA8ADB8).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.45, 1]) {
            c.drawLinearGradient(g, start: CGPoint(x: 10, y: 6), end: CGPoint(x: 38, y: 42), options: [])
        }
        c.restoreGState()
        c.setFillColor(UIColor.white.cgColor)
        c.fillEllipse(in: CGRect(x: 5.6, y: 3.6, width: 5.8, height: 5.8))
        c.fillEllipse(in: CGRect(x: 31.2, y: 29.9, width: 9.6, height: 9.6))
    }
}

public final class GradientWordmarkLabel: UILabel {
    private var lastSize = CGSize.zero

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastSize, bounds.width > 0, bounds.height > 0 else { return }
        lastSize = bounds.size
        // Paint the glyphs with a horizontal gradient pattern sized to the
        // label (white -> white -> #C084FC -> #00E5FF at 0 / .45 / .7 / 1).
        let image = UIGraphicsImageRenderer(size: bounds.size).image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.cgColor,
                          UIColor(rgbHex: 0xC084FC).cgColor, UIColor(rgbHex: 0x00E5FF).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                  locations: [0, 0.45, 0.7, 1]) {
                ctx.cgContext.drawLinearGradient(g, start: .zero,
                    end: CGPoint(x: bounds.width, y: 0), options: [])
            }
        }
        textColor = UIColor(patternImage: image)
    }
}

public enum BurgerIcon {
    public static func image(size: CGFloat = 36) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let c = ctx.cgContext
            let s = size / 36
            c.scaleBy(x: s, y: s)
            c.setStrokeColor(UIColor.white.cgColor)
            c.setLineWidth(3)
            c.setLineCap(.round)
            for y in [10.0, 18.0, 26.0] {
                c.move(to: CGPoint(x: 7, y: y))
                c.addLine(to: CGPoint(x: 29, y: y))
            }
            c.strokePath()
        }.withRenderingMode(.alwaysOriginal)
    }
}

public final class AmbientBackgroundView: UIView {
    private let violet = CAGradientLayer()
    private let cyan = CAGradientLayer()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(rgbHex: 0x050508)
        isUserInteractionEnabled = false
        for g in [violet, cyan] {
            g.type = .radial
            g.startPoint = CGPoint(x: 0.5, y: 0.5)
            g.endPoint = CGPoint(x: 1, y: 1)
            layer.addSublayer(g)
        }
        violet.colors = [UIColor(argbHex: 0x8C6D15FF).cgColor, UIColor(argbHex: 0x5F5C0FF3).cgColor,
                         UIColor(argbHex: 0x005C0FF3).cgColor]
        violet.locations = [0, 0.42, 0.7]
        cyan.colors = [UIColor(argbHex: 0x6619E6FF).cgColor, UIColor(argbHex: 0x3800E5FF).cgColor,
                       UIColor(argbHex: 0x0000E5FF).cgColor]
        cyan.locations = [0, 0.4, 0.7]
    }
    required init?(coder: NSCoder) { fatalError() }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // Scale the 360x780 viewport orbs to the view.
        let sx = bounds.width / 360, sy = bounds.height / 780
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        place(violet, cx: 10, cy: 45, r: 230, sx: sx, sy: sy)
        place(cyan, cx: 345, cy: 750, r: 260, sx: sx, sy: sy)
        CATransaction.commit()
    }

    private func place(_ g: CAGradientLayer, cx: CGFloat, cy: CGFloat, r: CGFloat, sx: CGFloat, sy: CGFloat) {
        let rx = r * sx, ry = r * sy
        g.frame = CGRect(x: cx * sx - rx, y: cy * sy - ry, width: rx * 2, height: ry * 2)
    }
}
