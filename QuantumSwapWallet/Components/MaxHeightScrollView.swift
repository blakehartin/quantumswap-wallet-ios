// MaxHeightScrollView.swift
// Scroll box that wraps its content up to a runtime cap (desktop
// `.blocks-content { max-height: ...; overflow: auto }`): short lists
// take only the space they need, long lists scroll INSIDE the box so
// whatever sits below (the "Add Liquidity" / "Create Pair" links) stays
// visible without scrolling the page. Android reference:
// view/widget/MaxHeightScrollView.java

import UIKit

public final class MaxHeightScrollView: UIScrollView {

    private var capConstraint: NSLayoutConstraint?
    private var wrapConstraint: NSLayoutConstraint?
    private var reserveBelow: CGFloat = 0
    private var hasCap = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        showsVerticalScrollIndicator = true
        let wrap = heightAnchor.constraint(equalTo: contentLayoutGuide.heightAnchor)
        wrap.priority = .defaultHigh
        wrap.isActive = true
        wrapConstraint = wrap
        let cap = heightAnchor.constraint(lessThanOrEqualToConstant: 100_000)
        cap.priority = .required
        cap.isActive = true
        capConstraint = cap
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Host a vertical stack as the scrolling content.
    public func install(content: UIView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            content.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor)
        ])
    }

    public func setMaxHeight(_ points: CGFloat) {
        capConstraint?.constant = max(points, 0)
    }

    /// Cap so the box ends `reserveBelow` points above the bottom of
    /// the safe area, based on where the box sits on screen (floor
    /// 120pt). Re-evaluated on every layout pass.
    public func capToScreen(reserveBelow: CGFloat) {
        self.reserveBelow = reserveBelow
        hasCap = true
        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard hasCap, let window else { return }
        let top = convert(CGPoint.zero, to: window).y
        let bottomInset = window.safeAreaInsets.bottom
        let avail = window.bounds.height - bottomInset - top - reserveBelow
        let cap = max(avail, 120)
        if abs((capConstraint?.constant ?? 0) - cap) > 0.5 {
            capConstraint?.constant = cap
        }
    }
}
