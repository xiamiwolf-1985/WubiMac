import Foundation
import WubiSupport

@objc
final class SettingsManager: NSObject, SettingsProviding {
    static let shared = SettingsManager()

    private let store: any SettingsProviding

    init(store: any SettingsProviding = UserDefaultsSettingsStore()) {
        self.store = store
        super.init()
    }

    var clearOnEmpty4thCode: Bool {
        get { store.clearOnEmpty4thCode }
        set { store.clearOnEmpty4thCode = newValue }
    }

    var smartPunctuation: Bool {
        get { store.smartPunctuation }
        set { store.smartPunctuation = newValue }
    }

    var halfWidthPunctuation: Bool {
        get { store.halfWidthPunctuation }
        set { store.halfWidthPunctuation = newValue }
    }

    var shiftTogglesEnglish: Bool {
        get { store.shiftTogglesEnglish }
        set { store.shiftTogglesEnglish = newValue }
    }

    var capsLockTogglesEnglish: Bool {
        get { store.capsLockTogglesEnglish }
        set { store.capsLockTogglesEnglish = newValue }
    }

    var candidatePageKeySet: CandidatePageKeySet {
        get { store.candidatePageKeySet }
        set { store.candidatePageKeySet = newValue }
    }

    var candidatePageSize: Int {
        get { store.candidatePageSize }
        set { store.candidatePageSize = newValue }
    }
}
