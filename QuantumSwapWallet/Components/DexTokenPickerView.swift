// DexTokenPickerView.swift
// Token picker trigger for the DEX screens (Swap / Liquidity / Pools):
// a button showing the selection ("Select token" / "Q" /
// "SYM (0x123456...abcd)") that opens `TokenPickerDialogViewController`
// (search, recognized / unrecognized badges, balances, custom address).
// Mirrors desktop `tokenPicker()` + Android `TokenPickerController`.
//
//  - `preselectNative` (default true): Q is selected on load. Swap
//    passes false on both sides (desktop parity: "Select token").
//  - `alwaysIncludeRecognized`: list the full recognized allow-list even
//    when the account holds none of them (swap "To" box); placeholder
//    rows resolve decimals / symbol through swapGetTokenMetadata before
//    any quote or submit (`needsMetadata` / `setResolvedMeta`).
// Android reference: view/widget/TokenPickerController.java

import UIKit

public final class DexTokenPickerView: UIView {

    public var onChanged: (() -> Void)?

    private let button = UIButton(type: .custom)
    private let customLabel: String
    private let preselectNative: Bool
    private let alwaysIncludeRecognized: Bool
    private var items: [TokenPickerItem] = []
    private var selected: TokenPickerItem?
    private var walletAddress = ""

    public init(customLabel: String, preselectNative: Bool = true,
                alwaysIncludeRecognized: Bool = false) {
        self.customLabel = customLabel
        self.preselectNative = preselectNative
        self.alwaysIncludeRecognized = alwaysIncludeRecognized
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.font = Typography.body(14)
        button.titleLabel?.lineBreakMode = .byTruncatingMiddle
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(argbHex: 0x1AFFFFFF)
        button.layer.cornerRadius = 7
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(argbHex: 0x4DFFFFFF).cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 7, left: 12, bottom: 7, right: 36)
        let caret = UIImageView(image: UIImage(named: "caret_down_outline")?.withRenderingMode(.alwaysTemplate))
        caret.tintColor = .white
        caret.contentMode = .scaleAspectFit
        caret.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(caret)
        button.addTarget(self, action: #selector(tapPicker), for: .touchUpInside)
        button.addTarget(self, action: #selector(pressDown), for: [.touchDown, .touchDragEnter])
        button.addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            caret.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12),
            caret.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            caret.widthAnchor.constraint(equalToConstant: 14),
            caret.heightAnchor.constraint(equalToConstant: 14)
        ])
        if preselectNative { selected = nativeItem() }
        refreshButtonTitle()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Data

    /// Full account token list (already stablecoin-filtered); the
    /// picker partitions it into recognized / unrecognized itself.
    public func setTokens(_ list: [AccountTokenSummary], walletAddress: String = "") {
        self.walletAddress = walletAddress
        var out: [TokenPickerItem] = []
        var seen = Set<String>()
        for t in list {
            guard let addr = t.contractAddress, !addr.isEmpty else { continue }
            seen.insert(addr.lowercased())
            let recognized = RecognizedTokens.isRecognized(addr)
            let symbol = DexBridgeResult.sanitizeSymbol(
                recognized ? (RecognizedTokens.displaySymbol(addr) ?? t.symbol) : t.symbol)
            out.append(TokenPickerItem(
                value: addr,
                symbol: symbol.isEmpty ? DexBridgeResult.shortAddr(addr) : symbol,
                name: DexBridgeResult.sanitizeSymbol(t.name),
                decimals: t.decimals ?? 18,
                recognized: recognized,
                balanceText: Self.formatBalance(t.balance, decimals: t.decimals ?? 18)))
        }
        if alwaysIncludeRecognized {
            for entry in RecognizedTokens.listed where !seen.contains(entry.address.lowercased()) {
                out.append(TokenPickerItem(value: entry.address, symbol: entry.symbol, name: "",
                                           decimals: nil, recognized: true, placeholder: true,
                                           balanceText: "0"))
            }
        }
        items = out
        // Keep a still-valid selection; otherwise restore the default.
        if let sel = selected, !sel.isNative, !sel.custom, let fresh = items.first(where: { $0 == sel }) {
            selected = fresh
        } else if selected?.custom != true {
            selected = preselectNative ? nativeItem() : nil
        }
        refreshButtonTitle()
        onChanged?()
    }

    private func nativeItem() -> TokenPickerItem {
        TokenPickerItem(value: "Q", symbol: "Q", name: "QuantumCoin", decimals: 18, recognized: true,
                        balanceText: NativeBalanceCache.formatted(for: walletAddress) ?? "0")
    }

    // MARK: - Selection API

    public var isEmpty: Bool { selected == nil }
    public var isNative: Bool { selected?.isNative ?? false }
    public var isCustomSelected: Bool { selected?.custom ?? false }

    /// "Q", a contract address, or "" when nothing is selected.
    public func tokenValue() -> String { selected?.value ?? "" }

    public func decimals() -> Int { selected?.decimals ?? 18 }

    public func symbol() -> String {
        guard let s = selected else { return "" }
        if s.isNative { return "Q" }
        return s.symbol.isEmpty ? DexBridgeResult.shortAddr(s.value) : s.symbol
    }

    public func name() -> String { selected?.name ?? "" }

    /// Placeholder / custom rows need swapGetTokenMetadata before a
    /// quote or submit.
    public func needsMetadata() -> Bool {
        guard let s = selected, !s.isNative else { return false }
        return s.decimals == nil
    }

    public func setResolvedMeta(address: String, symbol: String, decimals: Int) {
        guard var s = selected, s.value.caseInsensitiveCompare(address) == .orderedSame else { return }
        s.decimals = decimals
        if !symbol.isEmpty { s.symbol = DexBridgeResult.sanitizeSymbol(symbol) }
        s.placeholder = false
        selected = s
        refreshButtonTitle()
    }

    /// Opaque selection snapshot (swap flip exchanges both sides).
    public func captureSelection() -> TokenPickerItem? { selected }

    public func restoreSelection(_ item: TokenPickerItem?) {
        selected = item
        refreshButtonTitle()
    }

    /// Balance text for the currently selected token ("0" when unknown).
    public func balanceText() -> String {
        guard let s = selected else { return "0" }
        if s.isNative { return NativeBalanceCache.formatted(for: walletAddress) ?? "0" }
        return s.balanceText.isEmpty ? "0" : s.balanceText
    }

    // MARK: - UI

    private func refreshButtonTitle() {
        let title: String
        if let s = selected {
            title = s.isNative ? "Q" : "\(symbol()) (\(DexBridgeResult.shortAddr(s.value)))"
        } else {
            title = Localization.shared.lang("select-token", fallback: "Select token")
        }
        button.setTitle(title, for: .normal)
    }

    @objc private func pressDown() {
        button.backgroundColor = UIColor(argbHex: 0x26FFFFFF)
        button.layer.borderColor = UIColor(rgbHex: 0x8C71FF).cgColor
    }

    @objc private func pressUp() {
        button.backgroundColor = UIColor(argbHex: 0x1AFFFFFF)
        button.layer.borderColor = UIColor(argbHex: 0x4DFFFFFF).cgColor
    }

    @objc private func tapPicker() {
        var list = [nativeItem()] + items
        if let s = selected, s.custom, !list.contains(s) { list.append(s) }
        let hasUnrecognized = items.contains { !$0.recognized }
        let dlg = TokenPickerDialogViewController(items: list, hasUnrecognized: hasUnrecognized)
        dlg.onSelect = { [weak self] item in
            guard let self else { return }
            var picked = item
            if picked.custom {
                picked.name = self.customLabel
            }
            self.selected = picked
            self.refreshButtonTitle()
            self.onChanged?()
        }
        nearestViewController()?.present(dlg, animated: true)
    }

    private func nearestViewController() -> UIViewController? {
        var r: UIResponder? = self
        while let cur = r {
            if let vc = cur as? UIViewController { return vc }
            r = cur.next
        }
        return nil
    }

    /// Parse a hex / decimal balance, scale by decimals, cap at 6 dp
    /// (round down) and strip trailing zeros.
    static func formatBalance(_ raw: String?, decimals: Int) -> String {
        let s = CoinUtils.formatUnits(raw, decimals: decimals)
        guard let dot = s.firstIndex(of: ".") else { return s }
        let frac = s[s.index(after: dot)...]
        var out = String(s[..<dot]) + "." + String(frac.prefix(6))
        while out.hasSuffix("0") { out.removeLast() }
        if out.hasSuffix(".") { out.removeLast() }
        return out
    }
}
