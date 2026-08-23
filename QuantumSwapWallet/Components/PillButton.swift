// PillButton.swift
// Shared action buttons restyled to the desktop / Android "glass"
// chrome (app/src/main/res/drawable):
//   - GreenPillButton  -> button_green_shadow.xml: teal glass #2914B8A6
//     fill, #A614B8A6 1pt stroke, 9pt radius, white bold title.
//   - GrayPillButton   -> button_network_cancel_selector.xml (the
//     secondary / Cancel action): red glass #1FFF5A64 fill, #73FF5A64
//     stroke, pressed #3DFF5A64 / #B3FF5A64.
//   - SolidTealPillButton -> button_solid_teal_selector.xml: opaque
//     quantumTeal (pressed #0E9384) for LIGHT surfaces (QR scan dialog).
// All share the same geometry so they line up side-by-side.

import UIKit

open class GlassPillButton: UIButton {
    var restFill: UIColor = .clear
    var restStroke: UIColor = .clear
    var pressedFill: UIColor = .clear
    var pressedStroke: UIColor = .clear

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
        applyStyle()
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
        applyStyle()
    }

    open func configure() { }

    private func applyStyle() {
        backgroundColor = restFill
        layer.cornerRadius = 9
        layer.borderWidth = 1
        layer.borderColor = restStroke.cgColor
        layer.masksToBounds = true
        setTitleColor(.white, for: .normal)
        setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .disabled)
        titleLabel?.font = Typography.boldTitle(16)
        contentEdgeInsets = UIEdgeInsets(top: 5, left: 16, bottom: 5, right: 16)
    }

    public override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? pressedFill : restFill
            layer.borderColor = (isHighlighted ? pressedStroke : restStroke).cgColor
        }
    }
}

/// Primary action (desktop .proceed / Android button_green_shadow).
public final class GreenPillButton: GlassPillButton {
    public override func configure() {
        restFill = UIColor(argbHex: 0x2914B8A6)
        restStroke = UIColor(argbHex: 0xA614B8A6)
        pressedFill = UIColor(argbHex: 0x4714B8A6)
        pressedStroke = UIColor(argbHex: 0xFF14B8A6)
    }
}

/// Secondary / Cancel action (desktop .cancel / Android
/// button_network_cancel_selector).
public final class GrayPillButton: GlassPillButton {
    public override func configure() {
        restFill = UIColor(argbHex: 0x1FFF5A64)
        restStroke = UIColor(argbHex: 0x73FF5A64)
        pressedFill = UIColor(argbHex: 0x3DFF5A64)
        pressedStroke = UIColor(argbHex: 0xB3FF5A64)
    }
}

/// Opaque teal for light backdrops (Android button_solid_teal_selector).
public final class SolidTealPillButton: GlassPillButton {
    public override func configure() {
        restFill = .quantumTeal
        restStroke = .quantumTeal
        pressedFill = UIColor(rgbHex: 0x0E9384)
        pressedStroke = UIColor(rgbHex: 0x0E9384)
    }
}
