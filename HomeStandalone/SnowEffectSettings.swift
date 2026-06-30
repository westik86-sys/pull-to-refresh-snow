import Foundation
import Security

enum PullRefreshEffectKind: String, Codable, CaseIterable, Hashable {
    case snow
    case emoji
    case confetti

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = PullRefreshEffectKind(rawValue: rawValue) ?? .snow
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum ConfettiParticleMode: String, Codable, CaseIterable, Hashable {
    case confetti
    case customShape
    case emoji
}

enum ConfettiCustomShape: String, Codable, CaseIterable, Hashable {
    case star
    case heart
    case plus
    case spark
    case diamond
}

struct SnowEffectSettings: Equatable, Codable {
    static let defaultEmojiSymbol = "🍂"
    static let defaultConfettiEmojiSymbol = "🎉"
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
        var emojiSpin: Double = 1.0
        var confettiParticleMode: ConfettiParticleMode = .confetti
        var confettiCustomShape: ConfettiCustomShape = .star
        var confettiWind: Double = 0.18
        var confettiGravity: Double = 1.0
        var confettiSpin: Double = 1.0

        static let `default` = PresetSettings()
        static let confettiDefault = PresetSettings(emojiSymbol: SnowEffectSettings.defaultConfettiEmojiSymbol)

        init(
            emojiSymbol: String = SnowEffectSettings.defaultEmojiSymbol,
            emissionDuration: Double = 2.0,
            densityMultiplier: Double = 1.0,
            speedMultiplier: Double = 1.0,
            scaleMultiplier: Double = 1.0,
            alphaMultiplier: Double = 1.0,
            turbulenceMultiplier: Double = 1.0,
            overlayHeightPercent: Double = 25.0,
            blurMultiplier: Double = 1.0,
            emojiSpin: Double = 1.0,
            confettiParticleMode: ConfettiParticleMode = .confetti,
            confettiCustomShape: ConfettiCustomShape = .star,
            confettiWind: Double = 0.18,
            confettiGravity: Double = 1.0,
            confettiSpin: Double = 1.0
        ) {
            self.emojiSymbol = emojiSymbol
            self.emissionDuration = emissionDuration
            self.densityMultiplier = densityMultiplier
            self.speedMultiplier = speedMultiplier
            self.scaleMultiplier = scaleMultiplier
            self.alphaMultiplier = alphaMultiplier
            self.turbulenceMultiplier = turbulenceMultiplier
            self.overlayHeightPercent = overlayHeightPercent
            self.blurMultiplier = blurMultiplier
            self.emojiSpin = emojiSpin
            self.confettiParticleMode = confettiParticleMode
            self.confettiCustomShape = confettiCustomShape
            self.confettiWind = confettiWind
            self.confettiGravity = confettiGravity
            self.confettiSpin = confettiSpin
        }

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
                blurMultiplier: blurMultiplier.clamped(to: 0...2),
                emojiSpin: emojiSpin.clamped(to: 0...2.6),
                confettiParticleMode: confettiParticleMode,
                confettiCustomShape: confettiCustomShape,
                confettiWind: confettiWind.clamped(to: -1.0...1.0),
                confettiGravity: confettiGravity.clamped(to: 0.4...1.8),
                confettiSpin: confettiSpin.clamped(to: 0.2...2.6)
            )
        }

        private enum CodingKeys: String, CodingKey {
            case emojiSymbol
            case emissionDuration
            case densityMultiplier
            case speedMultiplier
            case scaleMultiplier
            case alphaMultiplier
            case turbulenceMultiplier
            case overlayHeightPercent
            case blurMultiplier
            case emojiSpin
            case confettiParticleMode
            case confettiCustomShape
            case confettiWind
            case confettiGravity
            case confettiSpin
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            emojiSymbol = try container.decodeIfPresent(String.self, forKey: .emojiSymbol) ?? SnowEffectSettings.defaultEmojiSymbol
            emissionDuration = try container.decodeIfPresent(Double.self, forKey: .emissionDuration) ?? 2.0
            densityMultiplier = try container.decodeIfPresent(Double.self, forKey: .densityMultiplier) ?? 1.0
            speedMultiplier = try container.decodeIfPresent(Double.self, forKey: .speedMultiplier) ?? 1.0
            scaleMultiplier = try container.decodeIfPresent(Double.self, forKey: .scaleMultiplier) ?? 1.0
            alphaMultiplier = try container.decodeIfPresent(Double.self, forKey: .alphaMultiplier) ?? 1.0
            turbulenceMultiplier = try container.decodeIfPresent(Double.self, forKey: .turbulenceMultiplier) ?? 1.0
            overlayHeightPercent = try container.decodeIfPresent(Double.self, forKey: .overlayHeightPercent) ?? 25.0
            blurMultiplier = try container.decodeIfPresent(Double.self, forKey: .blurMultiplier) ?? 1.0
            emojiSpin = try container.decodeIfPresent(Double.self, forKey: .emojiSpin) ?? 1.0
            confettiParticleMode = try container.decodeIfPresent(ConfettiParticleMode.self, forKey: .confettiParticleMode) ?? .confetti
            confettiCustomShape = try container.decodeIfPresent(ConfettiCustomShape.self, forKey: .confettiCustomShape) ?? .star
            confettiWind = try container.decodeIfPresent(Double.self, forKey: .confettiWind) ?? 0.18
            confettiGravity = try container.decodeIfPresent(Double.self, forKey: .confettiGravity) ?? 1.0
            confettiSpin = try container.decodeIfPresent(Double.self, forKey: .confettiSpin) ?? 1.0
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(emojiSymbol, forKey: .emojiSymbol)
            try container.encode(emissionDuration, forKey: .emissionDuration)
            try container.encode(densityMultiplier, forKey: .densityMultiplier)
            try container.encode(speedMultiplier, forKey: .speedMultiplier)
            try container.encode(scaleMultiplier, forKey: .scaleMultiplier)
            try container.encode(alphaMultiplier, forKey: .alphaMultiplier)
            try container.encode(turbulenceMultiplier, forKey: .turbulenceMultiplier)
            try container.encode(overlayHeightPercent, forKey: .overlayHeightPercent)
            try container.encode(blurMultiplier, forKey: .blurMultiplier)
            try container.encode(emojiSpin, forKey: .emojiSpin)
            try container.encode(confettiParticleMode, forKey: .confettiParticleMode)
            try container.encode(confettiCustomShape, forKey: .confettiCustomShape)
            try container.encode(confettiWind, forKey: .confettiWind)
            try container.encode(confettiGravity, forKey: .confettiGravity)
            try container.encode(confettiSpin, forKey: .confettiSpin)
        }
    }

    var isEnabled: Bool = true
    var effectKind: PullRefreshEffectKind = .snow
    private var snowPreset: PresetSettings = .default
    private var emojiPreset: PresetSettings = .default
    private var confettiPreset: PresetSettings = .confettiDefault

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
        emojiPreset: PresetSettings,
        confettiPreset: PresetSettings
    ) {
        self.isEnabled = isEnabled
        self.effectKind = effectKind
        self.snowPreset = snowPreset
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

    var emojiSpin: Double {
        get { preset(for: effectKind).emojiSpin }
        set { updatePreset(for: effectKind) { $0.emojiSpin = newValue } }
    }

    var confettiParticleMode: ConfettiParticleMode {
        get { preset(for: effectKind).confettiParticleMode }
        set { updatePreset(for: effectKind) { $0.confettiParticleMode = newValue } }
    }

    var confettiCustomShape: ConfettiCustomShape {
        get { preset(for: effectKind).confettiCustomShape }
        set { updatePreset(for: effectKind) { $0.confettiCustomShape = newValue } }
    }

    var confettiWind: Double {
        get { preset(for: effectKind).confettiWind }
        set { updatePreset(for: effectKind) { $0.confettiWind = newValue } }
    }

    var confettiGravity: Double {
        get { preset(for: effectKind).confettiGravity }
        set { updatePreset(for: effectKind) { $0.confettiGravity = newValue } }
    }

    var confettiSpin: Double {
        get { preset(for: effectKind).confettiSpin }
        set { updatePreset(for: effectKind) { $0.confettiSpin = newValue } }
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
        setPreset(Self.defaultPreset(for: effectKind), for: effectKind)
    }

    var resolvedEmojiSymbols: [String] {
        let symbols = Self.emojiSymbols(from: emojiSymbol)
        return symbols.isEmpty ? [Self.defaultEmojiSymbol] : symbols
    }

    var resolvedEmojiSymbol: String {
        resolvedEmojiSymbols.first ?? Self.defaultEmojiSymbol
    }

    var resolvedConfettiEmojiSymbol: String {
        let normalizedSymbol = Self.normalizedEmojiInput(emojiSymbol)
        return normalizedSymbol.isEmpty ? Self.defaultConfettiEmojiSymbol : String(normalizedSymbol.prefix(1))
    }

    private var normalized: SnowEffectSettings {
        SnowEffectSettings(
            isEnabled: isEnabled,
            effectKind: effectKind,
            snowPreset: snowPreset.normalized,
            emojiPreset: emojiPreset.normalized,
            confettiPreset: confettiPreset.normalized
        )
    }

    private func preset(for kind: PullRefreshEffectKind) -> PresetSettings {
        switch kind {
        case .snow:
            snowPreset
        case .emoji:
            emojiPreset
        case .confetti:
            confettiPreset
        }
    }

    private static func defaultPreset(for kind: PullRefreshEffectKind) -> PresetSettings {
        switch kind {
        case .confetti:
            .confettiDefault
        case .snow, .emoji:
            .default
        }
    }

    private mutating func setPreset(_ preset: PresetSettings, for kind: PullRefreshEffectKind) {
        switch kind {
        case .snow:
            snowPreset = preset
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
        case legacyLeavesPreset = "leavesPreset"
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
        let decodedLegacyLeavesPreset = try container.decodeIfPresent(PresetSettings.self, forKey: .legacyLeavesPreset)
        let decodedEmojiPreset = try container.decodeIfPresent(PresetSettings.self, forKey: .emojiPreset)
        let decodedConfettiPreset = try container.decodeIfPresent(PresetSettings.self, forKey: .confettiPreset)

        if decodedSnowPreset != nil || decodedLegacyLeavesPreset != nil || decodedEmojiPreset != nil || decodedConfettiPreset != nil {
            self.init(
                isEnabled: decodedIsEnabled,
                effectKind: decodedEffectKind,
                snowPreset: decodedSnowPreset ?? decodedLegacyLeavesPreset ?? .default,
                emojiPreset: decodedEmojiPreset ?? .default,
                confettiPreset: decodedConfettiPreset ?? .confettiDefault
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
            emojiPreset: decodedEffectKind == .emoji ? legacyPreset : .default,
            confettiPreset: decodedEffectKind == .confetti ? legacyPreset : .confettiDefault
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(effectKind, forKey: .effectKind)
        try container.encode(snowPreset, forKey: .snowPreset)
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
