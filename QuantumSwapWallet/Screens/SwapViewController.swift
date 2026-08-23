// SwapViewController.swift
// Desktop swap form (src/app/swap.ts) / Android `SwapFragment.java`:
//   - two token pickers (no Q preselect; the "To" picker always lists
//     the recognized allow-list);
//   - From / To boxes (balance row + editable amount) and the flip
//     button appear only once BOTH tokens are selected;
//   - bidirectional quote with a 400 ms debounce (swapGetAmountsOut /
//     swapGetAmountsIn); tapping a balance fills that side;
//   - route line "Route: A > B > C";
//   - Next -> allowance check -> tx-steps dialog [Approve FROM]? [Swap
//     FROM -> TO] with per-step gas estimate, review (+ "i agree" ->
//     unlock) and scan-API confirmation.

import UIKit

public final class SwapViewController: UIViewController, HomeScreenViewTypeProviding {

    public var screenViewType: ScreenViewType { .innerFragment }

    private static let quoteDebounceMs: UInt64 = 400

    private var walletAddress = ""
    private var fromPicker: DexTokenPickerView!
    private var toPicker: DexTokenPickerView!
    private let fromBox = UIStackView()
    private let toBox = UIStackView()
    private let flipRow = UIStackView()
    private let fromBalanceButton = UIButton(type: .system)
    private let toBalanceButton = UIButton(type: .system)
    private let amountInField = DexScreenChrome.makeField(placeholder: "", keyboard: .decimalPad)
    private let amountOutField = DexScreenChrome.makeField(placeholder: "", keyboard: .decimalPad)
    private let slippageField = DexScreenChrome.makeField(placeholder: "1", keyboard: .decimalPad)
    private let routeLabel = UILabel()
    private let statusLabel = UILabel()
    private let nextButton = GreenPillButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    private var lastQuotedAmountOut: String?
    private var flowInFlight = false
    private var syncingAmounts = false
    private var quoteTask: Task<Void, Never>?
    private var stepsDialog: TxStepsDialogViewController?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "colorBackground") ?? .systemBackground
        let L = Localization.shared
        walletAddress = DexScreenChrome.currentWalletAddress()

        let backBar = makeBackBar(action: #selector(tapBack))
        let title = UILabel()
        title.text = L.lang("swap", fallback: "Swap")
        title.font = Typography.boldTitle(20)
        title.textColor = UIColor(named: "colorCommon6") ?? .label

        let releaseBanner = UILabel()
        releaseBanner.font = Typography.body(12)
        releaseBanner.textColor = UIColor(named: "colorCommon10") ?? .secondaryLabel
        releaseBanner.numberOfLines = 0
        let active = ReleaseStore.readActive()
        if !active.builtin {
            releaseBanner.text = L.lang("custom-release-banner-prefix",
                fallback: "Custom release contracts: ") + active.name
        } else {
            releaseBanner.isHidden = true
        }

        let customLabel = L.lang("custom-contract-address", fallback: "Custom...")
        fromPicker = DexTokenPickerView(customLabel: customLabel, preselectNative: false,
                                        alwaysIncludeRecognized: false)
        toPicker = DexTokenPickerView(customLabel: customLabel, preselectNative: false,
                                      alwaysIncludeRecognized: true)
        fromPicker.onChanged = { [weak self] in self?.onTokensChanged() }
        toPicker.onChanged = { [weak self] in self?.onTokensChanged() }

        buildBox(fromBox, balanceButton: fromBalanceButton, field: amountInField, fromSide: true)
        buildBox(toBox, balanceButton: toBalanceButton, field: amountOutField, fromSide: false)

        // Flip button (desktop swap-flip): 40pt oval.
        let flip = UIButton(type: .custom)
        flip.setImage(UIImage(systemName: "arrow.up.arrow.down")?.withRenderingMode(.alwaysTemplate), for: .normal)
        flip.tintColor = .white
        flip.backgroundColor = UIColor(rgbHex: 0x1C1F2F)
        flip.layer.cornerRadius = 20
        flip.layer.borderWidth = 1
        flip.layer.borderColor = UIColor(argbHex: 0x99917DCF).cgColor
        flip.widthAnchor.constraint(equalToConstant: 40).isActive = true
        flip.heightAnchor.constraint(equalToConstant: 40).isActive = true
        flip.addTarget(self, action: #selector(flipTokens), for: .touchUpInside)
        flipRow.axis = .horizontal
        flipRow.alignment = .center
        flipRow.addArrangedSubview(UIView())
        flipRow.addArrangedSubview(flip)
        flipRow.addArrangedSubview(UIView())
        flipRow.distribution = .equalCentering

        slippageField.text = "1"

        routeLabel.font = Typography.body(12)
        routeLabel.textColor = UIColor(named: "colorCommon10") ?? .secondaryLabel
        routeLabel.numberOfLines = 0
        routeLabel.isHidden = true

        statusLabel.font = Typography.body(12)
        statusLabel.textColor = UIColor(named: "colorCommon10") ?? .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true

        nextButton.setTitle(L.lang("next", fallback: "Next"), for: .normal)
        nextButton.addTarget(self, action: #selector(tapNext), for: .touchUpInside)
        spinner.hidesWhenStopped = true
        let footerSpacer = UIView()
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttonRow = UIStackView(arrangedSubviews: [footerSpacer, spinner, nextButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.alignment = .center

        let content = UIStackView(arrangedSubviews: [
            backBar, title, DexScreenChrome.makeDivider(), releaseBanner,
            DexScreenChrome.makeLabel(L.lang("swap-from-token", fallback: "From token")),
            fromPicker,
            fromBox,
            flipRow,
            DexScreenChrome.makeLabel(L.lang("swap-to-token", fallback: "To token")),
            toPicker,
            toBox,
            routeLabel,
            DexScreenChrome.makeLabel(L.lang("slippage", fallback: "Slippage")),
            slippageField,
            buttonRow,
            statusLabel
        ])
        content.axis = .vertical
        content.spacing = 10
        content.setCustomSpacing(8, after: backBar)
        content.setCustomSpacing(4, after: flipRow)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .interactive
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        onTokensChanged()
        Task { [weak self] in
            guard let self else { return }
            let tokens = await DexScreenChrome.loadAccountTokens(for: self.walletAddress)
            await MainActor.run {
                self.fromPicker.setTokens(tokens, walletAddress: self.walletAddress)
                self.toPicker.setTokens(tokens, walletAddress: self.walletAddress)
            }
        }
        view.installPressFeedbackRecursive()
    }

    private func buildBox(_ box: UIStackView, balanceButton: UIButton, field: UITextField, fromSide: Bool) {
        let L = Localization.shared
        let balanceLabel = UILabel()
        balanceLabel.text = L.getBalanceByLangValues() + ":"
        balanceLabel.font = Typography.body(12)
        balanceLabel.textColor = UIColor(named: "colorCommon3") ?? .secondaryLabel
        balanceButton.setTitle("0", for: .normal)
        balanceButton.titleLabel?.font = Typography.body(12)
        balanceButton.setTitleColor(UIColor(named: "colorCommon6") ?? .label, for: .normal)
        balanceButton.addAction(UIAction { [weak self] _ in self?.fillFromBalance(fromSide: fromSide) },
                                for: .touchUpInside)
        let balanceRow = UIStackView(arrangedSubviews: [balanceLabel, balanceButton, UIView()])
        balanceRow.axis = .horizontal
        balanceRow.spacing = 6
        balanceRow.alignment = .center
        field.placeholder = L.lang(fromSide ? "swap-from-quantity" : "swap-to-quantity",
                                   fallback: fromSide ? "From quantity" : "To quantity")
        field.addAction(UIAction { [weak self] _ in self?.amountEdited(fromSide: fromSide) }, for: .editingChanged)
        box.axis = .vertical
        box.spacing = 6
        box.addArrangedSubview(balanceRow)
        box.addArrangedSubview(field)
        box.isHidden = true
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Desktop: early-phase warning on every screen open.
        let L = Localization.shared
        let warn = YesNoDialogViewController(message: L.lang("swapEarlyPhaseWarn",
            fallback: "This is a feature still in early phases of testing. Do you want to continue?"))
        warn.onNo = { [weak self] in self?.tapBack() }
        present(warn, animated: true)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        quoteTask?.cancel()
        stepsDialog?.dismissSteps()
        stepsDialog = nil
    }

    @objc private func tapBack() {
        (parent as? HomeViewController)?.showMain()
    }

    // MARK: - Token / amount changes (desktop updateSwapScreenInfo)

    private func onTokensChanged() {
        quoteTask?.cancel()
        lastQuotedAmountOut = nil
        setAmountSilently(amountInField, "")
        setAmountSilently(amountOutField, "")
        routeLabel.isHidden = true
        updateBalances()
        let ready = !fromPicker.isEmpty && !toPicker.isEmpty
        fromBox.isHidden = !ready
        toBox.isHidden = !ready
        flipRow.isHidden = !ready
        guard ready, fromPicker.tokenValue().caseInsensitiveCompare(toPicker.tokenValue()) != .orderedSame else { return }
        setBusy(true)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await DexScreenChrome.resolveMeta(self.fromPicker, walletAddress: self.walletAddress)
                try await DexScreenChrome.resolveMeta(self.toPicker, walletAddress: self.walletAddress)
                try await self.fetchRoute(alertWhenMissing: true)
            } catch {
                await MainActor.run { self.failFlow("\(error)") }
            }
        }
    }

    private func updateBalances() {
        fromBalanceButton.setTitle(fromPicker.balanceText(), for: .normal)
        toBalanceButton.setTitle(toPicker.balanceText(), for: .normal)
    }

    private func fillFromBalance(fromSide: Bool) {
        let picker = fromSide ? fromPicker! : toPicker!
        let field = fromSide ? amountInField : amountOutField
        let v = picker.balanceText()
        guard v != "0", !v.isEmpty else { return }
        field.text = v
        amountEdited(fromSide: fromSide)
    }

    @objc private func flipTokens() {
        let a = fromPicker.captureSelection()
        let b = toPicker.captureSelection()
        let oldOut = text(amountOutField)
        quoteTask?.cancel()
        fromPicker.restoreSelection(b)
        toPicker.restoreSelection(a)
        onTokensChanged()
        if !oldOut.isEmpty {
            setAmountSilently(amountInField, oldOut)
            scheduleQuote(fromChanged: true)
        }
    }

    private func setAmountSilently(_ field: UITextField, _ value: String) {
        syncingAmounts = true
        field.text = value
        syncingAmounts = false
    }

    private func amountEdited(fromSide: Bool) {
        guard !syncingAmounts else { return }
        scheduleQuote(fromChanged: fromSide)
    }

    // MARK: - Quote (bidirectional, 400 ms debounce)

    private func scheduleQuote(fromChanged: Bool) {
        quoteTask?.cancel()
        quoteTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: SwapViewController.quoteDebounceMs * 1_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.runQuote(fromChanged: fromChanged)
        }
    }

    private func runQuote(fromChanged: Bool) async {
        guard !fromPicker.isEmpty, !toPicker.isEmpty,
              fromPicker.tokenValue().caseInsensitiveCompare(toPicker.tokenValue()) != .orderedSame else { return }
        let source = text(fromChanged ? amountInField : amountOutField)
        let target = fromChanged ? amountOutField : amountInField
        guard Self.isPositiveAmount(source) else {
            setAmountSilently(target, "")
            lastQuotedAmountOut = nil
            return
        }
        setBusy(true)
        do {
            try await DexScreenChrome.resolveMeta(fromPicker, walletAddress: walletAddress)
            try await DexScreenChrome.resolveMeta(toPicker, walletAddress: walletAddress)
            var payload = DexPayloads.base()
            payload["fromTokenValue"] = fromPicker.tokenValue()
            payload["toTokenValue"] = toPicker.tokenValue()
            payload["fromDecimals"] = fromPicker.decimals()
            payload["toDecimals"] = toPicker.decimals()
            if fromChanged {
                payload["amountIn"] = source
                let json = try await JsBridge.shared.dexCallAsync(method: "swapGetAmountsOut", payload: payload)
                let data = try DexBridgeResult.unwrapData(json)
                let out = (data["amountOut"] as? String) ?? ""
                guard !Task.isCancelled else { return }
                lastQuotedAmountOut = out
                setAmountSilently(amountOutField, out)
            } else {
                payload["amountOut"] = source
                let json = try await JsBridge.shared.dexCallAsync(method: "swapGetAmountsIn", payload: payload)
                let data = try DexBridgeResult.unwrapData(json)
                let input = (data["amountIn"] as? String) ?? ""
                guard !Task.isCancelled else { return }
                lastQuotedAmountOut = source
                setAmountSilently(amountInField, input)
            }
            setBusy(false)
        } catch {
            failFlow("\(error)")
        }
    }

    private func fetchRoute(alertWhenMissing: Bool) async throws {
        var payload = DexPayloads.base()
        payload["fromTokenValue"] = fromPicker.tokenValue()
        payload["toTokenValue"] = toPicker.tokenValue()
        let json = try await JsBridge.shared.dexCallAsync(method: "swapCheckPairExists", payload: payload)
        let data = try DexBridgeResult.unwrapData(json)
        let exists = (data["exists"] as? Bool) ?? false
        let path = data["path"] as? [Any]
        let symbols = data["pathSymbols"] as? [Any]
        await MainActor.run {
            self.setBusy(false)
            let L = Localization.shared
            guard exists, let path, !path.isEmpty else {
                self.routeLabel.isHidden = true
                if alertWhenMissing {
                    DexScreenChrome.presentError(from: self, message: L.lang("swap-no-pair",
                        fallback: "No swap route exists between these two tokens (max 3 hops)"))
                }
                return
            }
            var parts: [String] = []
            for i in 0..<path.count {
                let sym = (symbols?[safe: i] as? String)
                let addr = (path[i] as? String) ?? ""
                if let sym, !sym.isEmpty, sym != "null" {
                    parts.append(DexBridgeResult.sanitizeSymbol(sym))
                } else {
                    parts.append(DexBridgeResult.shortAddr(addr))
                }
            }
            self.routeLabel.text = L.lang("swap-route", fallback: "Route") + ": " + parts.joined(separator: " > ")
            self.routeLabel.isHidden = false
        }
    }

    // MARK: - Next -> allowance check -> steps

    /// Desktop onSwapNextClick: post-click validation (the button is
    /// never disabled), then the allowance check decides the plan.
    @objc private func tapNext() {
        let amountIn = text(amountInField)
        guard validateInputs(amountIn) else { return }
        if lastQuotedAmountOut == nil || lastQuotedAmountOut?.isEmpty == true {
            lastQuotedAmountOut = text(amountOutField)
        }
        if flowInFlight { return }
        setBusy(true)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await DexScreenChrome.resolveMeta(self.fromPicker, walletAddress: self.walletAddress)
                try await DexScreenChrome.resolveMeta(self.toPicker, walletAddress: self.walletAddress)
                var payload = DexPayloads.base()
                payload["fromTokenValue"] = self.fromPicker.tokenValue()
                payload["fromDecimals"] = self.fromPicker.decimals()
                payload["requiredAmount"] = amountIn
                payload["ownerAddress"] = self.walletAddress
                let json = try await JsBridge.shared.dexCallAsync(method: "swapCheckAllowance", payload: payload)
                let data = try DexBridgeResult.unwrapData(json)
                let sufficient = (data["sufficient"] as? Bool) ?? false
                await MainActor.run {
                    self.setBusy(false)
                    self.showStepsDialog(needsApproval: !sufficient)
                }
            } catch {
                await MainActor.run { self.failFlow("\(error)") }
            }
        }
    }

    /// Desktop createSwapWorkflowStepPlan: optional "Approve FROM",
    /// always "Swap FROM -> TO".
    private func showStepsDialog(needsApproval: Bool) {
        let L = Localization.shared
        let fromSym = DexBridgeResult.sanitizeSymbol(fromPicker.symbol())
        let toSym = DexBridgeResult.sanitizeSymbol(toPicker.symbol())
        let amountIn = text(amountInField)
        let amountOut = lastQuotedAmountOut ?? ""
        let release = ReleaseStore.readActive()
        let fromContract = DexScreenChrome.resolveTokenContract(fromPicker.tokenValue(), release: release)
        let toContract = DexScreenChrome.resolveTokenContract(toPicker.tokenValue(), release: release)
        let fromNative = fromPicker.isNative
        let forWord = L.lang("swap-for", fallback: "for")

        var routeSuffix = ""
        if !routeLabel.isHidden, let route = routeLabel.text, let r = route.range(of: ": "),
           route.contains(" > ") {
            routeSuffix = " (" + route[r.upperBound...].replacingOccurrences(of: " > ", with: " -> ") + ")"
        }
        let base = ReviewSpec()
            .action(L.lang("swap", fallback: "Swap") + " " + fromSym + " " + forWord + " " + toSym + routeSuffix)
            .fromTokenContract(fromContract)
            .toTokenContract(toContract)
            .fromAddress(walletAddress)
            .toAddress(release.router)
            .quantityValue(fromNative ? amountIn : "0")
            .tokenQuantityValue(amountIn + " " + fromSym + " " + forWord + " " + amountOut + " " + toSym)
            .networkText(ReviewSpec.networkText())

        let fromValue = fromPicker.tokenValue()
        let fromDecimals = fromPicker.decimals()
        let swapArgs: () -> [String: Any] = { [weak self] in
            guard let self else { return [:] }
            return [
                "fromTokenValue": self.fromPicker.tokenValue(),
                "toTokenValue": self.toPicker.tokenValue(),
                "fromDecimals": self.fromPicker.decimals(),
                "toDecimals": self.toPicker.decimals(),
                "amountIn": amountIn,
                "lastChanged": "from",
                "slippagePercent": self.slippagePercent(),
                "recipientAddress": self.walletAddress
            ]
        }

        var steps: [TxStep] = []
        if needsApproval {
            let approveReview = ReviewSpec()
                .action(L.lang("approve", fallback: "Approve") + " " + fromSym)
                .fromTokenContractLabelKey("approval-token-contract")
                .toTokenContract(ReviewSpec.HIDE)
                .toAddress(fromContract)
                .quantityValue("0")
                .tokenQuantityLabelKey("approval-token-quantity")
                .tokenQuantityValue(amountIn + " " + fromSym)
            let approvePayload: () -> [String: Any] = {
                ["fromTokenValue": fromValue, "fromDecimals": fromDecimals, "amount": amountIn]
            }
            steps.append(TxStep(label: L.lang("approve", fallback: "Approve") + " " + fromSym,
                                kind: .approve, estimatePayload: approvePayload,
                                submitMethod: "swapSubmitApproval", submitPayload: approvePayload,
                                reviewOverride: approveReview))
        }
        steps.append(TxStep(label: L.lang("swap", fallback: "Swap") + " " + fromSym + " -> " + toSym,
                            kind: .swap, estimatePayload: swapArgs,
                            submitMethod: "swapSubmitSwap", submitPayload: swapArgs))

        flowInFlight = true
        let dlg = TxStepsDialogViewController(title: L.lang("swap", fallback: "Swap"),
                                              walletAddress: walletAddress, steps: steps, baseReview: base)
        dlg.onClose = { [weak self] in
            guard let self else { return }
            self.stepsDialog = nil
            self.flowInFlight = false
            self.lastQuotedAmountOut = nil
            self.setAmountSilently(self.amountInField, "")
            self.setAmountSilently(self.amountOutField, "")
            self.updateBalances()
        }
        stepsDialog = dlg
        dlg.show(from: self)
    }

    // MARK: - Helpers

    private func validateInputs(_ amountIn: String) -> Bool {
        let L = Localization.shared
        if fromPicker.isEmpty || toPicker.isEmpty {
            DexScreenChrome.presentError(from: self, message: L.lang("select-both-tokens",
                fallback: "Select both tokens."))
            return false
        }
        if fromPicker.tokenValue().caseInsensitiveCompare(toPicker.tokenValue()) == .orderedSame {
            DexScreenChrome.presentError(from: self, message: L.err(
                "identicalTokens", fallback: "From and To tokens must differ."))
            return false
        }
        if !Self.isPositiveAmount(amountIn) {
            DexScreenChrome.presentError(from: self, message: L.err(
                "invalidQuantity", fallback: "Enter a valid quantity."))
            return false
        }
        return true
    }

    private static func isPositiveAmount(_ s: String) -> Bool {
        !s.isEmpty && s.range(of: #"^\d*\.?\d+$"#, options: .regularExpression) != nil
            && (Double(s) ?? 0) > 0
    }

    private func slippagePercent() -> Double {
        let v = Double(text(slippageField)) ?? 1
        return max(0, min(100, v))
    }

    private func text(_ f: UITextField) -> String {
        f.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func setBusy(_ busy: Bool) {
        if busy { spinner.startAnimating() } else { spinner.stopAnimating() }
    }

    private func failFlow(_ error: String?) {
        flowInFlight = false
        setBusy(false)
        statusLabel.isHidden = true
        if let error, !error.isEmpty {
            DexScreenChrome.presentError(from: self, message: error)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
