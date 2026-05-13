import CoreGraphics
import WubiEngine

public protocol CandidatePresenting: AnyObject {
    func show(candidates: [Candidate], at point: CGPoint)
    func navigatePage(_ delta: Int)
    func hide()
}
