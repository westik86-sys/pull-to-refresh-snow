import Foundation
import Security

enum PullRefreshEffectKind: String, Codable, CaseIterable, Hashable {
    case snow
    case leaves
}

struct SnowEffectSettings: Equatable, Codable {
    var isEnabled: Bool = true
    var effectKind: PullRefreshEffectKind = .snow
    var emissionDuration: Double = 2.0
    var densityMultiplier: Double = 1.0
    var speedMultiplier: Double = 1.0
    var scaleMultiplier: Double = 1.0
    var alphaMultiplier: Double = 1.0
    var turbulenceMultiplier: Double = 1.0
    var overlayHeightPercent: Double = 25.0
    var blurMultiplier: Double = 1.0

    static let `default` = SnowEffectSettings()

    init(
        isEnabled: Bool = true,
        effectKind: PullRefreshEffectKind = .snow,
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
        self.emissionDuration = emissionDuration
        self.densityMultiplier = densityMultiplier
        self.speedMultiplier = speedMultiplier
        self.scaleMultiplier = scaleMultiplier
        self.alphaMultiplier = alphaMultiplier
        self.turbulenceMultiplier = turbulenceMultiplier
        self.overlayHeightPercent = overlayHeightPercent
        self.blurMultiplier = blurMultiplier
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

    private var normalized: SnowEffectSettings {
        SnowEffectSettings(
            isEnabled: isEnabled,
            effectKind: effectKind,
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

    private static let storageKey = "snowEffectSettings.v1"
    private static let keychainAccount = "snowEffectSettings"

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case effectKind
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
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        effectKind = try container.decodeIfPresent(PullRefreshEffectKind.self, forKey: .effectKind) ?? .snow
        emissionDuration = try container.decodeIfPresent(Double.self, forKey: .emissionDuration) ?? 2.0
        densityMultiplier = try container.decodeIfPresent(Double.self, forKey: .densityMultiplier) ?? 1.0
        speedMultiplier = try container.decodeIfPresent(Double.self, forKey: .speedMultiplier) ?? 1.0
        scaleMultiplier = try container.decodeIfPresent(Double.self, forKey: .scaleMultiplier) ?? 1.0
        alphaMultiplier = try container.decodeIfPresent(Double.self, forKey: .alphaMultiplier) ?? 1.0
        turbulenceMultiplier = try container.decodeIfPresent(Double.self, forKey: .turbulenceMultiplier) ?? 1.0
        overlayHeightPercent = try container.decodeIfPresent(Double.self, forKey: .overlayHeightPercent) ?? 25.0
        blurMultiplier = try container.decodeIfPresent(Double.self, forKey: .blurMultiplier) ?? 1.0
    }

    private static var keychainService: String {
        "\(Bundle.main.bundleIdentifier ?? "HomeStandalone").snowEffectSettings"
    }

    private static func loadFromUserDefaults() -> SnowEffectSettings? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(SnowEffectSettings.self, from: data)
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
