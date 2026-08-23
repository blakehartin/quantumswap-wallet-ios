// DrawerView.swift
// Desktop burger menu / Android `linearLayout_home_drawer`: a 260pt
// panel sliding in from the leading edge with Wallets, Settings and
// Advanced rows (20pt white icon + 15pt label, pressed #0FFFFFFF, 8pt
// radius) over a scrim that closes it on tap.

import UIKit

public final class DrawerView: UIView {

    public enum Item { case wallets, settings, advanced }

    public var onSelect: ((Item) -> Void)?

    private let scrim = UIView()
    private let panel = UIView()
    private var leading: NSLayoutConstraint!
    private static let width: CGFloat = 260
    private(set) var isOpen = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        scrim.translatesAutoresizingMaskIntoConstraints = false
        scrim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(close)))
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(close))
        swipe.direction = .left
        addGestureRecognizer(swipe)

        panel.backgroundColor = .quantumPanel
        panel.translatesAutoresizingMaskIntoConstraints = false
        let L = Localization.shared
        let rows = UIStackView(arrangedSubviews: [
            makeRow(icon: UIImage(named: "m_wallets"), sfFallback: "wallet.pass",
                    title: L.getWalletsByLangValues(), item: .wallets),
            makeRow(icon: UIImage(named: "m_settings"), sfFallback: "gearshape",
                    title: L.getSettingsByLangValues(), item: .settings),
            makeRow(icon: nil, sfFallback: "keyboard",
                    title: L.lang("nav-advanced", fallback: "Advanced"), item: .advanced)
        ])
        rows.axis = .vertical
        rows.spacing = 0
        rows.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(rows)
        addSubview(scrim)
        addSubview(panel)
        leading = panel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -DrawerView.width)
        NSLayoutConstraint.activate([
            scrim.topAnchor.constraint(equalTo: topAnchor),
            scrim.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrim.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: trailingAnchor),
            panel.topAnchor.constraint(equalTo: topAnchor),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor),
            panel.widthAnchor.constraint(equalToConstant: DrawerView.width),
            leading,
            rows.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 56),
            rows.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 8),
            rows.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    private func makeRow(icon: UIImage?, sfFallback: String, title: String, item: Item) -> UIControl {
        let row = DrawerRowControl()
        row.layer.cornerRadius = 8
        let iv = UIImageView(image: (icon ?? UIImage(systemName: sfFallback))?.withRenderingMode(.alwaysTemplate))
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = title
        label.font = Typography.body(15)
        label.textColor = UIColor(argbHex: 0xD1FFFFFF)
        label.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iv)
        row.addSubview(label)
        NSLayoutConstraint.activate([
            iv.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            iv.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iv.widthAnchor.constraint(equalToConstant: 20),
            iv.heightAnchor.constraint(equalToConstant: 20),
            label.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -12),
            row.heightAnchor.constraint(equalToConstant: 44)
        ])
        row.addAction(UIAction { [weak self] _ in
            self?.close()
            self?.onSelect?(item)
        }, for: .touchUpInside)
        return row
    }

    public func open() {
        guard !isOpen else { return }
        isOpen = true
        isHidden = false
        scrim.alpha = 0
        superview?.layoutIfNeeded()
        leading.constant = 0
        UIView.animate(withDuration: 0.22) {
            self.scrim.alpha = 1
            self.superview?.layoutIfNeeded()
        }
    }

    @objc public func close() {
        guard isOpen else { return }
        isOpen = false
        leading.constant = -DrawerView.width
        UIView.animate(withDuration: 0.2, animations: {
            self.scrim.alpha = 0
            self.superview?.layoutIfNeeded()
        }, completion: { _ in
            if !self.isOpen { self.isHidden = true }
        })
    }
}

final class DrawerRowControl: UIControl {
    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? UIColor(argbHex: 0x0FFFFFFF) : .clear }
    }
}
