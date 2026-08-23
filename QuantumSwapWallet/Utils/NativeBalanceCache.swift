// NativeBalanceCache.swift
// Last formatted native ("Q") balance per wallet address, written by
// the home balance fetch and read by the token picker's "Q" row.
// Android reference: GlobalMethods.CURRENT_WALLET_BALANCE_FORMATTED /
// CURRENT_WALLET_BALANCE_ADDRESS.

import Foundation

public enum NativeBalanceCache {
    private static let lock = NSLock()
    private static var address = ""
    private static var formatted = ""

    public static func store(address: String, formatted: String) {
        lock.lock(); defer { lock.unlock() }
        self.address = address
        self.formatted = formatted
    }

    /// Formatted balance for `address`, nil when unknown / for another wallet.
    public static func formatted(for address: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        guard !formatted.isEmpty, self.address.caseInsensitiveCompare(address) == .orderedSame else { return nil }
        return formatted == CoinUtils.UNKNOWN_BALANCE_PLACEHOLDER ? nil : formatted
    }
}
