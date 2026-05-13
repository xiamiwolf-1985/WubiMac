import WubiEngine

public enum PendingCompositionResolution: Equatable {
    case none
    case commitCandidate(index: Int)
    case commitBuffer
    case clear
}

public struct CompositionResolver {
    public init() {}

    public func resolve(buffer: String, candidates: [Candidate], clearOnEmpty4thCode: Bool) -> PendingCompositionResolution {
        guard !buffer.isEmpty else {
            return .none
        }

        if !candidates.isEmpty {
            return .commitCandidate(index: 0)
        }

        return clearOnEmpty4thCode ? .clear : .commitBuffer
    }
}
