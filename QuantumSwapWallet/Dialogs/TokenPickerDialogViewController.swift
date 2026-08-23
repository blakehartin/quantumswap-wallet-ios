// TokenPickerDialogViewController.swift
// Desktop token-picker modal (#modalTokenPicker): title + ×, search
// field ("Search name / symbol or paste address"), "Show unrecognized
// tokens" checkbox, status line, and a scrolling list of rows
// (● symbol badge / name / address / balance). An unmatched query that
// is a valid 0x+64hex address renders one selectable "custom" row.
// Android reference: view/widget/TokenPickerController.java +
// res/layout/token_picker_dialog.xml / token_picker_row.xml

import UIKit

public struct TokenPickerItem: Equatable {
    /// "Q" for the native coin, otherwise the 0x contract address.
    public var value: String
    public var symbol: String
    public var name: String
    /// nil until resolved through swapGetTokenMetadata (placeholders / custom).
    public var decimals: Int?
    public var recognized: Bool
    public var placeholder: Bool
    public var custom: Bool
    public var balanceText: String

    public var isNative: Bool { value == "Q" }

    public init(value: String, symbol: String, name: String = "", decimals: Int? = 18,
                recognized: Bool = true, placeholder: Bool = false, custom: Bool = false,
                balanceText: String = "") {
        self.value = value
        self.symbol = symbol
        self.name = name
        self.decimals = decimals
        self.recognized = recognized
        self.placeholder = placeholder
        self.custom = custom
        self.balanceText = balanceText
    }

    public static func == (a: TokenPickerItem, b: TokenPickerItem) -> Bool {
        a.value.caseInsensitiveCompare(b.value) == .orderedSame
    }
}

public final class TokenPickerDialogViewController: ModalDialogViewController {

    public var onSelect: ((TokenPickerItem) -> Void)?

    private let items: [TokenPickerItem]
    private let hasUnrecognized: Bool
    private var showUnrecognized = false

    private let searchField = UITextField()
    private let checkboxButton = UIButton(type: .custom)
    private let statusLabel = UILabel()
    private let listStack = UIStackView()
    private let listScroll = UIScrollView()

    public init(items: [TokenPickerItem], hasUnrecognized: Bool) {
        self.items = items
        self.hasUnrecognized = hasUnrecognized
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        let L = Localization.shared
        CardStyle.applyDexDialog(to: card)

        let title = UILabel()
        title.text = L.lang("select-a-token", fallback: "Select a token")
        title.font = Typography.boldTitle(18)
        title.textColor = .white
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let close = UIButton(type: .system)
        close.setTitle("×", for: .normal)
        close.titleLabel?.font = Typography.body(25)
        close.setTitleColor(.white, for: .normal)
        close.widthAnchor.constraint(equalToConstant: 32).isActive = true
        close.heightAnchor.constraint(equalToConstant: 32).isActive = true
        close.addTarget(self, action: #selector(tapClose), for: .touchUpInside)
        let titleRow = UIStackView(arrangedSubviews: [title, close])
        titleRow.axis = .horizontal
        titleRow.alignment = .center

        searchField.placeholder = L.lang("token-picker-search-placeholder",
                                         fallback: "Search name / symbol or paste address")
        searchField.font = Typography.body(14)
        searchField.textColor = .white
        searchField.autocapitalizationType = .none
        searchField.autocorrectionType = .no
        searchField.spellCheckingType = .no
        searchField.clearButtonMode = .whileEditing
        searchField.backgroundColor = UIColor(argbHex: 0x14FFFFFF)
        searchField.layer.cornerRadius = 8
        searchField.layer.borderWidth = 1
        searchField.layer.borderColor = UIColor(argbHex: 0x47FFFFFF).cgColor
        searchField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        searchField.leftViewMode = .always
        searchField.heightAnchor.constraint(equalToConstant: 42).isActive = true
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        searchField.addTarget(self, action: #selector(searchFocus), for: .editingDidBegin)
        searchField.addTarget(self, action: #selector(searchBlur), for: .editingDidEnd)

        checkboxButton.setTitle("  " + L.lang("show-unrecognized-tokens", fallback: "Show unrecognized tokens"),
                                for: .normal)
        checkboxButton.titleLabel?.font = Typography.body(12)
        checkboxButton.setTitleColor(UIColor(rgbHex: 0xDDD8E9), for: .normal)
        checkboxButton.tintColor = UIColor(rgbHex: 0x8C71FF)
        checkboxButton.contentHorizontalAlignment = .leading
        checkboxButton.addTarget(self, action: #selector(toggleUnrecognized), for: .touchUpInside)
        checkboxButton.isHidden = !hasUnrecognized
        refreshCheckbox()

        statusLabel.font = Typography.body(12)
        statusLabel.textColor = UIColor(rgbHex: 0xC7C1D9)
        statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 18).isActive = true

        let divider = UIView()
        divider.backgroundColor = UIColor(argbHex: 0x1FFFFFFF)
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        listStack.axis = .vertical
        listStack.spacing = 0
        listStack.translatesAutoresizingMaskIntoConstraints = false
        listScroll.translatesAutoresizingMaskIntoConstraints = false
        listScroll.showsVerticalScrollIndicator = false
        listScroll.keyboardDismissMode = .onDrag
        listScroll.addSubview(listStack)

        let stack = UIStackView(arrangedSubviews: [titleRow, searchField, checkboxButton, statusLabel, divider, listScroll])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(15, after: titleRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let wrap = listScroll.heightAnchor.constraint(equalTo: listScroll.contentLayoutGuide.heightAnchor)
        wrap.priority = .defaultHigh
        let cap = listScroll.heightAnchor.constraint(lessThanOrEqualToConstant: UIScreen.main.bounds.height * 0.5)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            listStack.topAnchor.constraint(equalTo: listScroll.contentLayoutGuide.topAnchor),
            listStack.bottomAnchor.constraint(equalTo: listScroll.contentLayoutGuide.bottomAnchor),
            listStack.leadingAnchor.constraint(equalTo: listScroll.contentLayoutGuide.leadingAnchor),
            listStack.trailingAnchor.constraint(equalTo: listScroll.contentLayoutGuide.trailingAnchor),
            listStack.widthAnchor.constraint(equalTo: listScroll.frameLayoutGuide.widthAnchor),
            wrap, cap,
            listScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            card.widthAnchor.constraint(equalToConstant: 340),
            card.heightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor, constant: -32)
        ])
        view.installPressFeedbackRecursive()
        render()
    }

    // MARK: - Filtering

    private func render() {
        let L = Localization.shared
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let query = (searchField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let q = query.lowercased()
        // Pool order: native Q, recognized, then unrecognized (when on).
        var pool = items.filter { $0.isNative }
        pool += items.filter { !$0.isNative && $0.recognized }
        if showUnrecognized { pool += items.filter { !$0.isNative && !$0.recognized } }
        var shown = pool.filter { item in
            q.isEmpty || item.symbol.lowercased().contains(q) || item.name.lowercased().contains(q)
                || item.value.lowercased().contains(q)
        }
        if shown.isEmpty, QuantumSwapAddress.isValid(query) {
            shown = [TokenPickerItem(value: query, symbol: "Token",
                                     name: L.lang("custom-contract-address", fallback: "Custom..."),
                                     decimals: nil, recognized: false, placeholder: true, custom: true)]
        }
        statusLabel.text = shown.isEmpty && !q.isEmpty
            ? L.lang("token-picker-no-results", fallback: "No tokens match your search.") : ""
        for item in shown {
            listStack.addArrangedSubview(makeRow(item))
        }
    }

    private func makeRow(_ item: TokenPickerItem) -> UIView {
        let L = Localization.shared
        let row = TokenPickerRowControl()
        row.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.dismiss(animated: true) { [onSelect] in onSelect?(item) }
        }, for: .touchUpInside)

        let dot = UILabel()
        dot.text = "●"
        dot.font = Typography.body(11)
        dot.textColor = UIColor(rgbHex: 0x7BDC9B)
        let symbol = UILabel()
        symbol.text = item.symbol
        symbol.font = Typography.boldTitle(15)
        symbol.textColor = .white
        let badge = PaddedLabel()
        badge.font = Typography.body(10)
        badge.layer.cornerRadius = 8
        badge.layer.masksToBounds = true
        if item.recognized || item.isNative {
            badge.text = L.lang("token-picker-default", fallback: "default")
            badge.textColor = UIColor(rgbHex: 0x7EE6A0)
            badge.backgroundColor = UIColor(argbHex: 0x3347CB74)
        } else {
            badge.text = L.lang("token-picker-unrecognized", fallback: "unrecognized")
            badge.textColor = UIColor(rgbHex: 0xFFC16E)
            badge.backgroundColor = UIColor(argbHex: 0x2EFFAE42)
        }
        let top = UIStackView(arrangedSubviews: [dot, symbol, badge, UIView()])
        top.axis = .horizontal
        top.spacing = 6
        top.alignment = .center

        let name = UILabel()
        name.text = item.name
        name.font = Typography.body(11)
        name.textColor = UIColor(rgbHex: 0xAAA4BB)
        name.isHidden = item.name.isEmpty
        let address = UILabel()
        address.text = item.value
        address.font = Typography.body(11)
        address.textColor = UIColor(rgbHex: 0xAAA4BB)
        address.lineBreakMode = .byTruncatingMiddle
        address.isHidden = item.isNative
        let left = UIStackView(arrangedSubviews: [top, name, address])
        left.axis = .vertical
        left.spacing = 2
        left.isUserInteractionEnabled = false

        let balance = UILabel()
        balance.text = item.balanceText.isEmpty ? "—" : item.balanceText
        balance.font = Typography.body(13)
        balance.textColor = .white
        balance.textAlignment = .right
        balance.setContentCompressionResistancePriority(.required, for: .horizontal)
        balance.isUserInteractionEnabled = false

        let h = UIStackView(arrangedSubviews: [left, balance])
        h.axis = .horizontal
        h.spacing = 8
        h.alignment = .center
        h.isUserInteractionEnabled = false
        h.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(h)
        NSLayoutConstraint.activate([
            h.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),
            h.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -8),
            h.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8),
            h.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
        return row
    }

    private func refreshCheckbox() {
        let name = showUnrecognized ? "checkmark.square.fill" : "square"
        checkboxButton.setImage(UIImage(systemName: name), for: .normal)
    }

    // MARK: - Actions

    @objc private func tapClose() { dismiss(animated: true) }
    @objc private func searchChanged() { render() }
    @objc private func searchFocus() { searchField.layer.borderColor = UIColor(rgbHex: 0x8C71FF).cgColor }
    @objc private func searchBlur() { searchField.layer.borderColor = UIColor(argbHex: 0x47FFFFFF).cgColor }
    @objc private func toggleUnrecognized() {
        showUnrecognized.toggle()
        refreshCheckbox()
        render()
    }
}

extension TokenPickerDialogViewController: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool {
        let current = textField.text ?? ""
        guard let r = Range(range, in: current) else { return true }
        return current.replacingCharacters(in: r, with: string).count <= 66
    }
}

/// Row background: transparent at rest, #2E8B70FF pressed.
final class TokenPickerRowControl: UIControl {
    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? UIColor(argbHex: 0x2E8B70FF) : .clear }
    }
}

final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right, height: s.height + insets.top + insets.bottom)
    }
}
