import WubiEngine

public protocol WubiInputEngine: AnyObject {
    var buffer: String { get }
    var candidates: [Candidate] { get }
    var englishMode: Bool { get }

    func open() throws
    func close()
    @discardableResult func append(_ ch: Character) -> Bool
    @discardableResult func backspace() -> Bool
    func clear()
    func pick(at idx: Int) -> String?
    func toggleEnglish()
}

extension WubiDict: WubiInputEngine {}
