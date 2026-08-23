// CardStyle.swift
// Shared card surfaces ported from the Android drawables:
//   - token_picker_dialog_bg.xml: #17151F fill, 1pt #8F8AAA stroke, 16pt
//     radius (token picker, tx-steps, gas-config dialogs).
//   - center_container.xml (v24): vertical gradient #1F1D35 -> #10121F ->
//     #0B0E18, 1pt #8F8AAA stroke, 22pt radius (home card, token /
//     transaction tables, review dialog, yes/no dialog).

import UIKit

public enum CardStyle {

    public static func applyDexDialog(to card: UIView) {
        card.backgroundColor = UIColor(rgbHex: 0x17151F)
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(rgbHex: 0x8F8AAA).cgColor
        card.layer.masksToBounds = true
    }

    /// Installs the center-container gradient as a background sublayer.
    /// Callers must call `layoutCenterContainer(_:in:)` from their
    /// layout pass so the gradient tracks the card bounds.
    @discardableResult
    public static func applyCenterContainer(to card: UIView) -> CAGradientLayer {
        card.backgroundColor = UIColor(rgbHex: 0x10121F)
        card.layer.cornerRadius = 22
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(rgbHex: 0x8F8AAA).cgColor
        card.layer.masksToBounds = true
        let g = CAGradientLayer()
        g.colors = [UIColor(rgbHex: 0x1F1D35).cgColor,
                    UIColor(rgbHex: 0x10121F).cgColor,
                    UIColor(rgbHex: 0x0B0E18).cgColor]
        g.locations = [0, 0.5, 1]
        g.startPoint = CGPoint(x: 0.5, y: 0)
        g.endPoint = CGPoint(x: 0.5, y: 1)
        g.cornerRadius = 22
        g.frame = card.bounds
        card.layer.insertSublayer(g, at: 0)
        return g
    }

    public static func layoutCenterContainer(_ gradient: CAGradientLayer?, in card: UIView) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient?.frame = card.bounds
        CATransaction.commit()
    }
}

/// A view whose background is the center-container gradient card.
public final class CenterContainerView: UIView {
    private var gradient: CAGradientLayer?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        gradient = CardStyle.applyCenterContainer(to: self)
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CardStyle.layoutCenterContainer(gradient, in: self)
    }
}
