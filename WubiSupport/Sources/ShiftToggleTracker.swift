public enum ModifierHandlingResult: Equatable {
    case passthrough
    case toggleEnglish
}

public struct ShiftToggleTracker {
    private(set) var handledOtherKeySinceShift = false

    public init() {}

    public mutating func recordKeyPress() {
        handledOtherKeySinceShift = true
    }

    public mutating func handleModifierChange(hasShift: Bool, hasOtherModifiers: Bool) -> ModifierHandlingResult {
        if hasShift && !hasOtherModifiers {
            handledOtherKeySinceShift = false
            return .passthrough
        }

        if !hasShift && !hasOtherModifiers {
            guard !handledOtherKeySinceShift else {
                return .passthrough
            }

            handledOtherKeySinceShift = true
            return .toggleEnglish
        }

        handledOtherKeySinceShift = true
        return .passthrough
    }
}
