// YesNoDialogViewController.swift
// Shared Yes / No confirm on the center-container card: bold message,
// centered No (red glass) + Yes (green). Android reference:
// res/layout/yes_no_dialog.xml (swap early-phase warning,
// first-liquidity-provider warning).

import UIKit

public final class YesNoDialogViewController: ModalDialogViewController {

    public var onYes: (() -> Void)?
    public var onNo: (() -> Void)?

    private let message: String
    private var gradient: CAGradientLayer?

    public init(message: String) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        let L = Localization.shared
        gradient = CardStyle.applyCenterContainer(to: card)

        let label = UILabel()
        label.text = message
        label.font = Typography.boldTitle(16)
        label.textColor = UIColor(named: "colorCommon6") ?? .white
        label.numberOfLines = 0
        label.textAlignment = .center

        let no = GrayPillButton(type: .system)
        no.setTitle(L.lang("no", fallback: "No"), for: .normal)
        no.addTarget(self, action: #selector(tapNo), for: .touchUpInside)
        let yes = GreenPillButton(type: .system)
        yes.setTitle(L.lang("yes", fallback: "Yes"), for: .normal)
        yes.addTarget(self, action: #selector(tapYes), for: .touchUpInside)
        for b in [no, yes] {
            b.heightAnchor.constraint(equalToConstant: 43).isActive = true
            b.widthAnchor.constraint(greaterThanOrEqualToConstant: 70).isActive = true
        }
        let buttons = UIStackView(arrangedSubviews: [no, yes])
        buttons.axis = .horizontal
        buttons.spacing = 15
        buttons.alignment = .center
        let buttonWrap = UIStackView(arrangedSubviews: [UIView(), buttons, UIView()])
        buttonWrap.axis = .horizontal
        buttonWrap.distribution = .equalCentering

        let stack = UIStackView(arrangedSubviews: [label, buttonWrap])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            card.widthAnchor.constraint(equalToConstant: 320)
        ])
        view.installPressFeedbackRecursive()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CardStyle.layoutCenterContainer(gradient, in: card)
    }

    @objc private func tapYes() { dismiss(animated: true) { [onYes] in onYes?() } }
    @objc private func tapNo() { dismiss(animated: true) { [onNo] in onNo?() } }
}
