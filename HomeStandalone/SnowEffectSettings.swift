import Foundation
import Security

enum PullRefreshEffectKind: String, Codable, CaseIterable, Hashable {
    case snow
    case leaves
    case emoji
    case confetti
}

struct SnowEffectSettings: Equatable, Codable {
    static let defaultEmojiSymbol = "🍂"
    static let maxEmojiSymbols = 6

    private struct PresetSettings: Equatable, Codable {
        var emojiSymbol: String = SnowEffectSettings.defaultEmojiSymbol
        var emissionDuration: Double = 2.0
        var densityMultiplier: Double = 1.0
        var speedMultiplier: Double = 1.0
        var scaleMultiplier: Double = 1.0
        var alphaMultiplier: Double = 1.0
        var turbulenceMultiplier: Double = 1.0
        var overlayHeightPercent: Double = 25.0
        var blurMultiplier: Double = 1.0

        static let `default` = PresetSettings()

        var normalized: PresetSettings {
            PresetSettings(
                emojiSymbol: SnowEffectSettings.normalizedEmojiInput(emojiSymbol),
                emissionDuration: emissionDuration.clamped(to: 1.0...3.5),
                densityMultiplier: densityMultiplier.clamped(to: 0.25...2.5),
                speedMultiplier: speedMultiplier.clamped(to: 0.45...1.9),
                scaleMultiplier: scaleMultiplier.clamped(to: 0.55...1.8),
                alphaMultiplier: alphaMultiplier.clamped(to: 0.35...2.5),
                turbulenceMultiplier: turbulenceMultiplier.clamped(to: 0...1.8),
                overlayHeightPercent: overlayHeightPercent.clamped(to: 0...100),
                blurMultiplier: blurMultiplier.clamped(to: 0...2)
            )
        }
    }

    var isEnabled: Bool = true
    var effectKind: PullRefreshEffectKind = .snow
    private var snowPreset: PresetSettings = .default
    private var leavesPreset: PresetSettings = .default
    private var emojiPreset: PresetSettings = .default
    private var confettiPreset: PresetSettings = .default

    static let `default` = SnowEffectSettings()

    init(
        isEnabled: Bool = true,
        effectKind: PullRefreshEffectKind = .snow,
        emojiSymbol: String = Self.defaultEmojiSymbol,
        emissionDuration: Double = 2.0,
        densityMultiplier: Double = 1.0,
        speedMultiplier: Double = 1.0,
        scaleMultiplier: Double = 1.0,
        alphaMultiplier: Double = 1.0,
        turbulenceMultiplier: Double = 1.0,
        overlayHeightPercent: Double = 25.0,
        blurMultiplier: Double = 1.0
    ) {
        self.isEnabled = isEnabled
        self.effectKind = effectKind
        let activePreset = PresetSettings(
            emojiSymbol: emojiSymbol,
            emissionDuration: emissionDuration,
            densityMultiplier: densityMultiplier,
            speedMultiplier: speedMultiplier,
            scaleMultiplier: scaleMultiplier,
            alphaMultiplier: alphaMultiplier,
            turbulenceMultiplier: turbulenceMultiplier,
            overlayHeightPercent: overlayHeightPercent,
            blurMultiplier: blurMultiplier
        )
        setPreset(activePreset, for: effectKind)
    }

    private init(
        isEnabled: Bool,
        effectKind: PullRefreshEffectKind,
        snowPreset: PresetSettings,
        leavesPreset: PresetSettings,
        emojiPreset: PresetSettings,
        confettiPreset: PresetSettings
    ) {
        self.isEnabled = isEnabled
        self.effectKind = effectKind
        self.snowPreset = snowPreset
        self.leavesPreset = leavesPreset
        self.emojiPreset = emojiPreset
        self.confettiPreset = confettiPreset
    }

    var emojiSymbol: String {
        get { preset(for: effectKind).emojiSymbol }
        set { updatePreset(for: effectKind) { $0.emojiSymbol = newValue } }
    }

    var emissionDuration: Double {
        get { preset(for: effectKind).emissionDuration }
        set { updatePreset(for: effectKind) { $0.emissionDuration = newValue } }
    }

    var densityMultiplier: Double {
        get { preset(for: effectKind).densityMultiplier }
        set { updatePreset(for: effectKind) { $0.densityMultiplier = newValue } }
    }

    var speedMultiplier: Double {
        get { preset(for: effectKind).speedMultiplier }
        set { updatePreset(for: effectKind) { $0.speedMultiplier = newValue } }
    }

    var scaleMultiplier: Double {
        get { preset(for: effectKind).scaleMultiplier }
        set { updatePreset(for: effectKind) { $0.scaleMultiplier = newValue } }
    }

    var alphaMultiplier: Double {
        get { preset(for: effectKind).alphaMultiplier }
        set { updatePreset(for: effectKind) { $0.alphaMultiplier = newValue } }
    }

    var turbulenceMultiplier: Double {
        get { preset(for: effectKind).turbulenceMultiplier }
        set { updatePreset(for: effectKind) { $0.turbulenceMultiplier = newValue } }
    }

    var overlayHeightPercent: Double {
        get { preset(for: effectKind).overlayHeightPercent }
        set { updatePreset(for: effectKind) { $0.overlayHeightPercent = newValue } }
    }

    var blurMultiplier: Double {
        get { preset(for: effectKind).blurMultiplier }
        set { updatePreset(for: effectKind) { $0.blurMultiplier = newValue } }
    }

    static var persisted: SnowEffectSettings {
        if let userDefaultsSettings = loadFromUserDefaults() {
            return userDefaultsSettings.normalized
        }

        if let keychainSettings = loadFromKeychain() {
            let normalizedSettings = keychainSettings.normalized
            normalizedSettings.saveToUserDefaults()
            return normalizedSettings
        }

        return .default
    }

    func persist() {
        let normalizedSettings = normalized
        normalizedSettings.saveToUserDefaults()
        normalizedSettings.saveToKeychain()
    }

    mutating func resetCurrentPreset() {
        setPreset(.default, for: effectKind)
    }

    var resolvedEmojiSymbols: [String] {
        let symbols = Self.emojiSymbols(from: emojiSymbol)
        return symbols.isEmpty ? [Self.defaultEmojiSymbol] : symbols
    }

    var resolvedEmojiSymbol: String {
        resolvedEmojiSymbols.first ?? Self.defaultEmojiSymbol
    }

    private var normalized: SnowEffectSettings {
        SnowEffectSettings(
            isEnabled: isEnabled,
            effectKind: effectKind,
            snowPreset: snowPreset.normalized,
            leavesPreset: leavesPreset.normalized,
            emojiPreset: emojiPreset.normalized,
            confettiPreset: confettiPreset.normalized
        )
    }

    private func preset(for kind: PullRefreshEffectKind) -> PresetSettings {
        switch kind {
        case .snow:
            snowPreset
        case .leaves:
            leavesPreset
        case .emoji:
            emojiPreset
        case .confetti:
            confettiPreset
        }
    }

    private mutating func setPreset(_ preset: PresetSettings, for kind: PullRefreshEffectKind) {
        switch kind {
        case .snow:
            snowPreset = preset
        case .leaves:
            leavesPreset = preset
        case .emoji:
            emojiPreset = preset
        case .confetti:
            confettiPreset = preset
        }
    }

    private mutating func updatePreset(
        for kind: PullRefreshEffectKind,
        _ update: (inout PresetSettings) -> Void
    ) {
        switch kind {
        case .snow:
            update(&snowPreset)
        case .leaves:
            update(&leavesPreset)
        case .emoji:
            update(&emojiPreset)
        case .confetti:
            update(&confettiPreset)
        }
    }

    private static let storageKey = "snowEffectSettings.v1"
    private static let keychainAccount = "snowEffectSettings"

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case effectKind
        case snowPreset
        case leavesPreset
        case emojiPreset
        case confettiPreset
        case emojiSymbol
        case emissionDuration
        case densityMultiplier
        case speedMultiplier
        case scaleMultiplier
        case alphaMultiplier
        case turbulenceMultiplier
        case overlayHeightPercent
        case blurMultiplier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedIsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        let decodedEffectKind = try container.decodeIfPresent(PullRefreshEffectKind.self, forKey: .effectKind) ?? .snow

        let decodedSnowPreset = try container.decodeIfPresent(PresetSettings.self, forKey: .snowPreset)
        let decodedLeavesPreset = try container.decodeIfPresent(PresetSettings.self, forKey: .leavesPreset)
        let decodedEmojiPreset = try container.decodeIfPresent(PresetSettings.self, forKey: .emojiPreset)
        let decodedConfettiPreset = try container.decodeIfPresent(PresetSettings.self, forKey: .confettiPreset)

        if decodedSnowPreset != nil || decodedLeavesPreset != nil || decodedEmojiPreset != nil || decodedConfettiPreset != nil {
            self.init(
                isEnabled: decodedIsEnabled,
                effectKind: decodedEffectKind,
                snowPreset: decodedSnowPreset ?? .default,
                leavesPreset: decodedLeavesPreset ?? .default,
                emojiPreset: decodedEmojiPreset ?? .default,
                confettiPreset: decodedConfettiPreset ?? .default
            )
            return
        }

        let legacyPreset = PresetSettings(
            emojiSymbol: try container.decodeIfPresent(String.self, forKey: .emojiSymbol) ?? Self.defaultEmojiSymbol,
            emissionDuration: try container.decodeIfPresent(Double.self, forKey: .emissionDuration) ?? 2.0,
            densityMultiplier: try container.decodeIfPresent(Double.self, forKey: .densityMultiplier) ?? 1.0,
            speedMultiplier: try container.decodeIfPresent(Double.self, forKey: .speedMultiplier) ?? 1.0,
            scaleMultiplier: try container.decodeIfPresent(Double.self, forKey: .scaleMultiplier) ?? 1.0,
            alphaMultiplier: try container.decodeIfPresent(Double.self, forKey: .alphaMultiplier) ?? 1.0,
            turbulenceMultiplier: try container.decodeIfPresent(Double.self, forKey: .turbulenceMultiplier) ?? 1.0,
            overlayHeightPercent: try container.decodeIfPresent(Double.self, forKey: .overlayHeightPercent) ?? 25.0,
            blurMultiplier: try container.decodeIfPresent(Double.self, forKey: .blurMultiplier) ?? 1.0
        )

        self.init(
            isEnabled: decodedIsEnabled,
            effectKind: decodedEffectKind,
            snowPreset: decodedEffectKind == .snow ? legacyPreset : .default,
            leavesPreset: decodedEffectKind == .leaves ? legacyPreset : .default,
            emojiPreset: decodedEffectKind == .emoji ? legacyPreset : .default,
            confettiPreset: decodedEffectKind == .confetti ? legacyPreset : .default
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(effectKind, forKey: .effectKind)
        try container.encode(snowPreset, forKey: .snowPreset)
        try container.encode(leavesPreset, forKey: .leavesPreset)
        try container.encode(emojiPreset, forKey: .emojiPreset)
        try container.encode(confettiPreset, forKey: .confettiPreset)
    }

    private static var keychainService: String {
        "\(Bundle.main.bundleIdentifier ?? "HomeStandalone").snowEffectSettings"
    }

    private static func loadFromUserDefaults() -> SnowEffectSettings? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(SnowEffectSettings.self, from: data)
    }

    private static func normalizedEmojiInput(_ symbol: String) -> String {
        let nonWhitespaceCharacters = symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { character in
                !character.unicodeScalars.allSatisfy {
                    CharacterSet.whitespacesAndNewlines.contains($0)
                }
            }

        return String(nonWhitespaceCharacters.prefix(maxEmojiSymbols))
    }

    private static func emojiSymbols(from symbol: String) -> [String] {
        normalizedEmojiInput(symbol).map(String.init)
    }

    private func saveToUserDefaults() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func loadFromKeychain() -> SnowEffectSettings? {
        guard let data = loadDataFromKeychain() else { return nil }
        return try? JSONDecoder().decode(SnowEffectSettings.self, from: data)
    }

    private func saveToKeychain() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.saveDataToKeychain(data)
    }

    private static func loadDataFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func saveDataToKeychain(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        guard updateStatus == errSecItemNotFound else { return }

        var addAttributes = query
        addAttributes[kSecValueData as String] = data
        addAttributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addAttributes as CFDictionary, nil)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
