// SegmentUnderlineControl.swift
// Desktop / Android table tabs (segment_underline.xml): no fill in any
// state; the active tab is BOLD with a 2pt #34D399 underline, the
// inactive tab is regular weight in the same colour. API-compatible
// subset of UISegmentedControl (`items:`, `selectedSegmentIndex`,
// `.valueChanged`) so the tokens / transactions screens keep their
// wiring.

import UIKit

public final class SegmentUnderlineControl: UIControl {

    public var textColor: UIColor = UIColor(named: "colorCommon6") ?? .white { didSet { render() } }
    public var selectedSegmentIndex: Int = 0 { didSet { if oldValue != selectedSegmentIndex { render() } } }

    private var buttons: [UIButton] = []
    private var underlines: [UIView] = []
    private let stack = UIStackView()

    public init(items: [String]) {
        super.init(frame: .zero)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
        for (i, title) in items.enumerated() {
            let b = UIButton(type: .custom)
            b.setTitle(title, for: .normal)
            b.titleLabel?.font = Typography.body(14)
            b.titleLabel?.adjustsFontSizeToFitWidth = true
            b.titleLabel?.minimumScaleFactor = 0.8
            b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 4, bottom: 10, right: 4)
            b.tag = i
            b.addAction(UIAction { [weak self] _ in self?.select(i) }, for: .touchUpInside)
            let underline = UIView()
            underline.backgroundColor = UIColor(rgbHex: 0x34D399)
            underline.translatesAutoresizingMaskIntoConstraints = false
            b.addSubview(underline)
            NSLayoutConstraint.activate([
                underline.leadingAnchor.constraint(equalTo: b.leadingAnchor),
                underline.trailingAnchor.constraint(equalTo: b.trailingAnchor),
                underline.bottomAnchor.constraint(equalTo: b.bottomAnchor),
                underline.heightAnchor.constraint(equalToConstant: 2)
            ])
            buttons.append(b)
            underlines.append(underline)
            stack.addArrangedSubview(b)
        }
        render()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func select(_ index: Int) {
        guard index != selectedSegmentIndex else { return }
        selectedSegmentIndex = index
        sendActions(for: .valueChanged)
    }

    private func render() {
        for (i, b) in buttons.enumerated() {
            let active = i == selectedSegmentIndex
            b.titleLabel?.font = active ? Typography.boldTitle(14) : Typography.body(14)
            b.setTitleColor(textColor, for: .normal)
            underlines[i].isHidden = !active
        }
    }
}
