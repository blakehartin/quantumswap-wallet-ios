// PoolsViewController.swift
// Desktop pools screen (src/app/advanced.ts) / Android
// `PoolsFragment.java`:
//   - list panel (default): pool table (scrolling box, symbols link to
//     the explorer) with a "Create Pair" link below;
//   - form panel: Token A / Token B + a screen-level gas chip (desktop
//     #divCreatePairGasIcon, 2 s debounce on token change) + Create Pair;
//   - one-step plan "Create Pair" (review: contract / to = factory,
//     Quantity (Q) "0") through TxStepsDialogViewController.

import UIKit

public final class PoolsViewController: UIViewController, HomeScreenViewTypeProviding {

    public var screenViewType: ScreenViewType { .innerFragment }

    private var walletAddress = ""
    private let listPanel = UIStackView()
    private let formPanel = UIStackView()
    private let poolsStack = UIStackView()
    private let poolsScroll = MaxHeightScrollView()
    private let emptyLabel = UILabel()
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var tokenAPicker: DexTokenPickerView!
    private var tokenBPicker: DexTokenPickerView!
    private let createButton = GreenPillButton(type: .system)
    private var gasChip: GasChipController?
    private var stepsDialog: TxStepsDialogViewController?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "colorBackground") ?? .systemBackground
        let L = Localization.shared
        walletAddress = DexScreenChrome.currentWalletAddress()

        let backBar = makeBackBar(action: #selector(tapBack))
        let title = UILabel()
        title.text = L.lang("pools", fallback: "Pools")
        title.font = Typography.boldTitle(20)
        title.textColor = UIColor(named: "colorCommon6") ?? .label

        // ---- List panel -------------------------------------------------
        let listTitle = UILabel()
        listTitle.text = L.lang("all-pools", fallback: "All pools")
        listTitle.font = Typography.boldTitle(16)
        listTitle.textColor = UIColor(named: "colorCommon1") ?? .label
        let refresh = UIButton(type: .system)
        refresh.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        refresh.tintColor = UIColor(named: "colorCommon6") ?? .label
        refresh.addTarget(self, action: #selector(loadPools), for: .touchUpInside)
        spinner.hidesWhenStopped = true
        let header = UIStackView(arrangedSubviews: [listTitle, UIView(), refresh, spinner])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8

        emptyLabel.text = L.lang("no-pools", fallback: "No pools yet.")
        emptyLabel.font = Typography.body(13)
        emptyLabel.textColor = UIColor(named: "colorCommon10") ?? .secondaryLabel

        poolsStack.axis = .vertical
        poolsStack.spacing = 4
        poolsScroll.install(content: poolsStack)
        poolsScroll.capToScreen(reserveBelow: 70)

        let createLink = DexScreenChrome.makeLink(L.lang("create-pair", fallback: "Create Pair"),
                                                  underline: true, target: self, action: #selector(showCreatePanel))
        let linkRow = UIStackView(arrangedSubviews: [UIView(), createLink, UIView()])
        linkRow.axis = .horizontal
        linkRow.distribution = .equalCentering

        listPanel.axis = .vertical
        listPanel.spacing = 10
        [header, emptyLabel, poolsScroll, linkRow].forEach { listPanel.addArrangedSubview($0) }

        // ---- Form panel -------------------------------------------------
        let createTitle = UILabel()
        createTitle.text = L.lang("create-pair", fallback: "Create Pair")
        createTitle.font = Typography.boldTitle(16)
        createTitle.textColor = UIColor(named: "colorCommon1") ?? .label
        createTitle.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let chipView = GasChipView()
        let titleRow = UIStackView(arrangedSubviews: [createTitle, chipView])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 12
        gasChip = GasChipController(host: self, walletAddress: walletAddress, chip: chipView, kind: .createPair)

        let customLabel = L.lang("custom-contract-address", fallback: "Custom...")
        tokenAPicker = DexTokenPickerView(customLabel: customLabel)
        tokenBPicker = DexTokenPickerView(customLabel: customLabel)
        tokenAPicker.onChanged = { [weak self] in self?.scheduleGasEstimate() }
        tokenBPicker.onChanged = { [weak self] in self?.scheduleGasEstimate() }
        createButton.setTitle(L.lang("create-pair", fallback: "Create Pair"), for: .normal)
        createButton.addTarget(self, action: #selector(startCreate), for: .touchUpInside)
        let createRow = UIStackView(arrangedSubviews: [UIView(), createButton, UIView()])
        createRow.axis = .horizontal
        createRow.distribution = .equalCentering

        statusLabel.font = Typography.body(12)
        statusLabel.textColor = UIColor(named: "colorCommon10") ?? .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true

        formPanel.axis = .vertical
        formPanel.spacing = 10
        formPanel.isHidden = true
        [titleRow,
         DexScreenChrome.makeLabel(L.lang("token-a", fallback: "Token A")), tokenAPicker,
         DexScreenChrome.makeLabel(L.lang("token-b", fallback: "Token B")), tokenBPicker,
         statusLabel, createRow].forEach { formPanel.addArrangedSubview($0) }

        let content = UIStackView(arrangedSubviews: [backBar, title, DexScreenChrome.makeDivider(), listPanel, formPanel])
        content.axis = .vertical
        content.spacing = 10
        content.setCustomSpacing(8, after: backBar)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        Task { [weak self] in
            guard let self else { return }
            let tokens = await DexScreenChrome.loadAccountTokens(for: self.walletAddress)
            await MainActor.run {
                self.tokenAPicker.setTokens(tokens, walletAddress: self.walletAddress)
                self.tokenBPicker.setTokens(tokens, walletAddress: self.walletAddress)
            }
        }
        loadPools()
        view.installPressFeedbackRecursive()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stepsDialog?.dismissSteps()
        stepsDialog = nil
    }

    /// Desktop: back from the create form returns to the pool list;
    /// back from the list leaves the screen.
    @objc private func tapBack() {
        if !formPanel.isHidden {
            showListPanel()
            return
        }
        (parent as? HomeViewController)?.beginTransactionNow(AdvancedViewController())
    }

    // MARK: - Panels

    /// Desktop showPoolsCreatePanel: swap to the form with a clean slate.
    @objc private func showCreatePanel() {
        tokenAPicker.restoreSelection(nil)
        tokenBPicker.restoreSelection(nil)
        statusLabel.isHidden = true
        gasChip?.reset()
        listPanel.isHidden = true
        formPanel.isHidden = false
    }

    private func showListPanel() {
        formPanel.isHidden = true
        listPanel.isHidden = false
        loadPools()
    }

    // MARK: - Pool list

    @objc private func loadPools() {
        setBusy(true)
        Task { [weak self] in
            guard let self else { return }
            do {
                let json = try await JsBridge.shared.dexCallAsync(method: "liquidityListPools", payload: DexPayloads.base())
                let data = try DexBridgeResult.unwrapData(json)
                let pools: [[String: Any]] = {
                    if let arr = data["pools"] as? [[String: Any]] { return arr }
                    if let arr = data["pools"] as? [Any] { return arr.compactMap { $0 as? [String: Any] } }
                    return []
                }()
                await MainActor.run {
                    self.setBusy(false)
                    self.renderPools(pools)
                }
            } catch {
                await MainActor.run { self.failFlow("\(error)") }
            }
        }
    }

    private func renderPools(_ pools: [[String: Any]]) {
        poolsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emptyLabel.isHidden = !pools.isEmpty
        poolsScroll.isHidden = pools.isEmpty
        let L = Localization.shared
        for pool in pools {
            let row = UIStackView()
            row.axis = .vertical
            row.spacing = 4
            row.isLayoutMarginsRelativeArrangement = true
            row.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)

            let sym0 = DexBridgeResult.sanitizeSymbol(pool["symbol0"] as? String)
            let sym1 = DexBridgeResult.sanitizeSymbol(pool["symbol1"] as? String)
            let token0 = (pool["token0"] as? String) ?? ""
            let token1 = (pool["token1"] as? String) ?? ""
            // Symbols link to the token contract on the block explorer.
            let pair = ExplorerLinks.makePairLabel(
                symA: sym0.isEmpty ? DexBridgeResult.shortAddr(token0) : sym0, tokenA: token0,
                symB: sym1.isEmpty ? DexBridgeResult.shortAddr(token1) : sym1, tokenB: token1)

            let addr = UILabel()
            addr.text = DexBridgeResult.shortAddr(pool["pairAddress"] as? String)
            addr.font = Typography.body(12)
            addr.textColor = UIColor(named: "colorCommon3") ?? .secondaryLabel

            let dec0 = (pool["decimals0"] as? Int) ?? (pool["decimals0"] as? NSNumber)?.intValue ?? 18
            let dec1 = (pool["decimals1"] as? Int) ?? (pool["decimals1"] as? NSNumber)?.intValue ?? 18
            let reserves = UILabel()
            reserves.text = L.lang("pool-reserves", fallback: "Reserves") + ": "
                + CoinUtils.formatUnits(pool["reserve0"] as? String, decimals: dec0) + " / "
                + CoinUtils.formatUnits(pool["reserve1"] as? String, decimals: dec1)
            reserves.font = Typography.body(13)
            reserves.textColor = UIColor(named: "colorCommon3") ?? .secondaryLabel

            [pair, addr, reserves, DexScreenChrome.makeDivider()].forEach { row.addArrangedSubview($0) }
            poolsStack.addArrangedSubview(row)
        }
    }

    // MARK: - Gas chip (desktop scheduleCreatePairGasEstimate)

    private func createPairPayload() -> [String: Any] {
        ["tokenAValue": tokenAPicker.tokenValue(), "tokenBValue": tokenBPicker.tokenValue(),
         "ownerAddress": walletAddress]
    }

    private func scheduleGasEstimate() {
        gasChip?.schedule { [weak self] in
            guard let self else { return nil }
            let a = self.tokenAPicker.tokenValue(), b = self.tokenBPicker.tokenValue()
            guard !a.isEmpty, !b.isEmpty, a.caseInsensitiveCompare(b) != .orderedSame else { return nil }
            return self.createPairPayload()
        }
    }

    // MARK: - Create

    @objc private func startCreate() {
        let L = Localization.shared
        if tokenAPicker.isEmpty || tokenBPicker.isEmpty {
            DexScreenChrome.presentError(from: self, message: L.lang("select-both-tokens", fallback: "Select both tokens."))
            return
        }
        if tokenAPicker.tokenValue().caseInsensitiveCompare(tokenBPicker.tokenValue()) == .orderedSame {
            DexScreenChrome.presentError(from: self, message: L.err("identicalTokens", fallback: "Token A and Token B must differ."))
            return
        }
        setBusy(true)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await DexScreenChrome.resolveMeta(self.tokenAPicker, walletAddress: self.walletAddress)
                try await DexScreenChrome.resolveMeta(self.tokenBPicker, walletAddress: self.walletAddress)
                var payload = DexPayloads.base()
                payload["tokenAValue"] = self.tokenAPicker.tokenValue()
                payload["tokenBValue"] = self.tokenBPicker.tokenValue()
                let json = try await JsBridge.shared.dexCallAsync(method: "liquidityGetPairInfo", payload: payload)
                let data = try DexBridgeResult.unwrapData(json)
                if (data["exists"] as? Bool) == true {
                    await MainActor.run {
                        self.failFlow(L.lang("pair-exists", fallback: "A pool already exists for this pair."))
                    }
                    return
                }
                await MainActor.run {
                    self.setBusy(false)
                    self.showCreateSteps()
                }
            } catch {
                await MainActor.run { self.failFlow("\(error)") }
            }
        }
    }

    /// Desktop createPair flow: one "Create Pair" step; review rows
    /// contract/to = factory, Quantity (Q) "0".
    private func showCreateSteps() {
        let L = Localization.shared
        let label = L.lang("create-pair", fallback: "Create Pair")
        let release = ReleaseStore.readActive()
        let symA = DexBridgeResult.sanitizeSymbol(tokenAPicker.symbol())
        let symB = DexBridgeResult.sanitizeSymbol(tokenBPicker.symbol())
        let base = ReviewSpec()
            .action(label + ": " + symA + " / " + symB)
            .contractAddress(release.factory)
            .fromAddress(walletAddress)
            .toAddress(release.factory)
            .quantityValue("0")
            .networkText(ReviewSpec.networkText())
        let a = tokenAPicker.tokenValue(), b = tokenBPicker.tokenValue()
        let owner = walletAddress
        let steps = [TxStep(label: label, kind: .createPair,
                            estimatePayload: { ["tokenAValue": a, "tokenBValue": b, "ownerAddress": owner] },
                            submitMethod: "poolsSubmitCreatePair",
                            submitPayload: { ["tokenAValue": a, "tokenBValue": b] })]
        let dlg = TxStepsDialogViewController(title: label, walletAddress: walletAddress,
                                              steps: steps, baseReview: base)
        dlg.onClose = { [weak self] in
            guard let self else { return }
            self.stepsDialog = nil
            self.showListPanel()
        }
        stepsDialog = dlg
        dlg.show(from: self)
    }

    // MARK: - Helpers

    private func setBusy(_ busy: Bool) {
        if busy { spinner.startAnimating() } else { spinner.stopAnimating() }
    }

    private func failFlow(_ error: String?) {
        setBusy(false)
        statusLabel.isHidden = true
        if let error, !error.isEmpty {
            DexScreenChrome.presentError(from: self, message: error)
        }
    }
}
