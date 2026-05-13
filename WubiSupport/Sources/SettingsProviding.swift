import Foundation

public enum CandidatePageKeySet: String, CaseIterable {
    case brackets
    case minusEqual
    case commaPeriod

    public var displayName: String {
        switch self {
        case .brackets: return "[ / ]"
        case .minusEqual: return "- / ="
        case .commaPeriod: return ", / ."
        }
    }
}

public protocol SettingsProviding: AnyObject {
    var clearOnEmpty4thCode: Bool { get set }
    var smartPunctuation: Bool { get set }
    var halfWidthPunctuation: Bool { get set }
    var shiftTogglesEnglish: Bool { get set }
    var capsLockTogglesEnglish: Bool { get set }
    var candidatePageKeySet: CandidatePageKeySet { get set }
    var candidatePageSize: Int { get set }
}

public final class UserDefaultsSettingsStore: SettingsProviding {
    private enum Keys {
        static let clearOnEmpty4thCode = "clearOnEmpty4thCode"
        static let smartPunctuation = "smartPunctuation"
        static let halfWidthPunctuation = "halfWidthPunctuation"
        static let shiftTogglesEnglish = "shiftTogglesEnglish"
        static let capsLockTogglesEnglish = "capsLockTogglesEnglish"
        static let candidatePageKeySet = "candidatePageKeySet"
        static let candidatePageSize = "candidatePageSize"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var clearOnEmpty4thCode: Bool {
        get { defaults.object(forKey: Keys.clearOnEmpty4thCode) == nil ? true : defaults.bool(forKey: Keys.clearOnEmpty4thCode) }
        set { defaults.set(newValue, forKey: Keys.clearOnEmpty4thCode) }
    }

    public var smartPunctuation: Bool {
        get { defaults.object(forKey: Keys.smartPunctuation) == nil ? true : defaults.bool(forKey: Keys.smartPunctuation) }
        set { defaults.set(newValue, forKey: Keys.smartPunctuation) }
    }

    public var halfWidthPunctuation: Bool {
        get { defaults.bool(forKey: Keys.halfWidthPunctuation) }
        set { defaults.set(newValue, forKey: Keys.halfWidthPunctuation) }
    }

    public var shiftTogglesEnglish: Bool {
        get { defaults.object(forKey: Keys.shiftTogglesEnglish) == nil ? true : defaults.bool(forKey: Keys.shiftTogglesEnglish) }
        set { defaults.set(newValue, forKey: Keys.shiftTogglesEnglish) }
    }

    public var capsLockTogglesEnglish: Bool {
        get { defaults.object(forKey: Keys.capsLockTogglesEnglish) == nil ? true : defaults.bool(forKey: Keys.capsLockTogglesEnglish) }
        set { defaults.set(newValue, forKey: Keys.capsLockTogglesEnglish) }
    }

    public var candidatePageKeySet: CandidatePageKeySet {
        get {
            guard let rawValue = defaults.string(forKey: Keys.candidatePageKeySet) else {
                return .brackets
            }
            return CandidatePageKeySet(rawValue: rawValue) ?? .brackets
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.candidatePageKeySet) }
    }

    public var candidatePageSize: Int {
        get {
            let storedValue = defaults.integer(forKey: Keys.candidatePageSize)
            return storedValue == 0 ? 9 : min(9, max(3, storedValue))
        }
        set { defaults.set(min(9, max(3, newValue)), forKey: Keys.candidatePageSize) }
    }
}
