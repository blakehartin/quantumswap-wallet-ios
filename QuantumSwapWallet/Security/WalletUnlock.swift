// WalletUnlock.swift
// Shared "unlock → load signing credentials" path used by every
// transaction flow (Send, Swap, Liquidity, Pools, Token create). The
// password gate itself is `DexUnlockPrompt` (UnlockDialog +
// UnlockAttemptLimiter); this type owns the key load and the key-type
// detection the gas math needs. Android reference:
// app/src/main/java/com/quantumswap/app/security/WalletUnlock.java

import Foundation

public struct Credentials {
    public var privateKey: Data
    public var publicKey: Data
    public let advancedSigning: Bool
    /// 3 or 5, from the public-key byte length.
    public let keyType: Int

    public init(privateKey: Data, publicKey: Data, advancedSigning: Bool, keyType: Int) {
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.advancedSigning = advancedSigning
        self.keyType = keyType
    }

    /// Zeroize key material as soon as the signing call returns.
    public mutating func wipe() {
        if !privateKey.isEmpty { privateKey.resetBytes(in: 0..<privateKey.count) }
        if !publicKey.isEmpty { publicKey.resetBytes(in: 0..<publicKey.count) }
    }
}

public enum WalletUnlock {

    /// Load keys for `walletAddress` from the (already unlocked)
    /// strongbox. Background-thread / Task.detached only. Also caches
    /// the key type so fee previews match before the next unlock.
    public static func loadCredentials(walletAddress: String) throws -> Credentials {
        let (priv, pub) = try DexUnlockPrompt.loadWalletKeys(walletAddress: walletAddress)
        let keyType = GasFee.keyType(fromPublicKeyByteCount: pub.count)
        GasFee.cacheKeyType(address: walletAddress, keyType: keyType)
        let advanced = PrefConnect.shared.readBool(PrefKeys.ADVANCED_SIGNING_ENABLED_KEY)
        return Credentials(privateKey: priv, publicKey: pub,
                           advancedSigning: advanced, keyType: keyType)
    }
}
