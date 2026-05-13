import Cocoa
import InputMethodKit
import WubiEngine
import WubiSupport

@objc(WubiInputController)
final class WubiInputController: IMKInputController {
    private let dict: any WubiInputEngine
    private let settings: any SettingsProviding
    private let candidatePresenter: any CandidatePresenting
    private let punctuationTransformer: PunctuationTransformer

    private var handledOtherKeySinceShift = false
    private var commitObserver: NSObjectProtocol?
    private weak var pendingClientForCommit: IMKTextInput?

    override init!(server: IMKServer!, delegate: Any!, client: Any!) {
        dict = Self.makeDefaultEngine()
        settings = SettingsManager.shared
        candidatePresenter = CandidatePanel.shared
        punctuationTransformer = PunctuationTransformer()
        super.init(server: server, delegate: delegate, client: client)
        startObservingCandidateCommits()
    }

    deinit {
        if let commitObserver {
            NotificationCenter.default.removeObserver(commitObserver)
        }
        dict.close()
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue | NSEvent.EventTypeMask.flagsChanged.rawValue)
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "WubiMac Settings")

        let clearItem = NSMenuItem(title: "四码无字时清空编码", action: #selector(toggleClearOnEmpty), keyEquivalent: "")
        clearItem.state = settings.clearOnEmpty4thCode ? .on : .off

        let smartPunctuationItem = NSMenuItem(title: "智能标点 (英文数字后半角)", action: #selector(toggleSmartPunc), keyEquivalent: "")
        smartPunctuationItem.state = settings.smartPunctuation ? .on : .off

        let halfWidthItem = NSMenuItem(title: "全局半角标点", action: #selector(toggleHalfPunc), keyEquivalent: "")
        halfWidthItem.state = settings.halfWidthPunctuation ? .on : .off

        menu.addItem(clearItem)
        menu.addItem(smartPunctuationItem)
        menu.addItem(halfWidthItem)
        return menu
    }

    @objc private func toggleClearOnEmpty() {
        settings.clearOnEmpty4thCode.toggle()
    }

    @objc private func toggleSmartPunc() {
        settings.smartPunctuation.toggle()
    }

    @objc private func toggleHalfPunc() {
        settings.halfWidthPunctuation.toggle()
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput else {
            return false
        }

        if event.type == .flagsChanged {
            return handleModifierEvent(event)
        }

        guard event.type == .keyDown else {
            return false
        }

        handledOtherKeySinceShift = true

        if event.modifierFlags.contains(.command) {
            return false
        }

        if event.keyCode == 57 {
            dict.toggleEnglish()
            candidatePresenter.hide()
            pendingClientForCommit = nil
            return true
        }

        if dict.englishMode {
            return false
        }

        let keyCode = event.keyCode
        let characters = event.characters ?? ""

        switch keyCode {
        case 51:
            return handleBackspace(client)
        case 53:
            return handleEscape(client)
        case 49:
            return handleSpace(client)
        case 36:
            return handleEnter(client)
        case 33:
            return handlePageNavigation(-1)
        case 30:
            return handlePageNavigation(1)
        default:
            break
        }

        if let numberSelection = numberSelectionIndex(from: characters), commitCandidate(at: numberSelection, client: client) {
            return true
        }

        if let character = characters.first, handlePunctuation(character, client: client) {
            return true
        }

        if let character = characters.first, character.isLetter, handleLetter(character, client: client) {
            return true
        }

        flushCompositionForExternalKey(client)
        return false
    }

    override func deactivateServer(_ sender: Any!) {
        let client = (sender as? IMKTextInput) ?? self.client()
        if let client, !dict.buffer.isEmpty {
            client.insertText(dict.buffer, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
        clearComposition()
        super.deactivateServer(sender)
    }

    @objc func selectionChanged(_ sender: Any!) {
        guard !dict.buffer.isEmpty else {
            return
        }

        dict.clear()
        updateUI(sender as? IMKTextInput)
    }

    override func commitComposition(_ sender: Any!) {
        let client = (sender as? IMKTextInput) ?? self.client()
        if let client, !dict.buffer.isEmpty {
            client.insertText(dict.buffer, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            clearComposition()
        }
        super.commitComposition(sender)
    }

    private static func makeDefaultEngine() -> any WubiInputEngine {
        let dict = WubiDict(dbPath: DatabasePathResolver().databasePath)
        try? dict.open()
        return dict
    }

    private func startObservingCandidateCommits() {
        commitObserver = NotificationCenter.default.addObserver(forName: .commitCandidate, object: nil, queue: .main) { [weak self] notification in
            guard let self,
                  let text = notification.object as? String,
                  let client = self.pendingClientForCommit else {
                return
            }

            self.insertCommittedText(text, client: client)
            self.pendingClientForCommit = nil
        }
    }

    private func handleModifierEvent(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags
        let hasShift = modifiers.contains(.shift)
        let otherModifiers = modifiers.intersection([.command, .option, .control])
        let onlyShiftPressed = hasShift && otherModifiers.isEmpty

        if onlyShiftPressed {
            handledOtherKeySinceShift = false
            return false
        }

        if !hasShift && otherModifiers.isEmpty {
            guard !handledOtherKeySinceShift else {
                return false
            }

            dict.toggleEnglish()
            candidatePresenter.hide()
            pendingClientForCommit = nil
            handledOtherKeySinceShift = true
            return true
        }

        handledOtherKeySinceShift = true
        return false
    }

    private func handleBackspace(_ client: IMKTextInput) -> Bool {
        guard !dict.buffer.isEmpty else {
            return false
        }

        _ = dict.backspace()
        updateUI(client)
        return true
    }

    private func handleEscape(_ client: IMKTextInput) -> Bool {
        guard !dict.buffer.isEmpty else {
            return false
        }

        dict.clear()
        updateUI(client)
        return true
    }

    private func handleSpace(_ client: IMKTextInput) -> Bool {
        if commitCandidate(at: 0, client: client) {
            return true
        }

        guard !dict.buffer.isEmpty else {
            return false
        }

        insertCommittedText(dict.buffer, client: client)
        return true
    }

    private func handleEnter(_ client: IMKTextInput) -> Bool {
        guard !dict.buffer.isEmpty else {
            return false
        }

        insertCommittedText(dict.buffer, client: client)
        return true
    }

    private func handlePageNavigation(_ delta: Int) -> Bool {
        guard !dict.candidates.isEmpty else {
            return false
        }

        candidatePresenter.navigatePage(delta)
        return true
    }

    private func handlePunctuation(_ character: Character, client: IMKTextInput) -> Bool {
        guard punctuationTransformer.supports(character) else {
            return false
        }

        let hadPendingComposition = !dict.buffer.isEmpty
        if hadPendingComposition {
            flushCompositionForExternalKey(client)
        }

        let useHalfWidth = !hadPendingComposition && punctuationTransformer.shouldUseHalfWidth(
            for: character,
            globalHalfWidth: settings.halfWidthPunctuation,
            smartPunctuation: settings.smartPunctuation,
            precedingCharacter: precedingCharacter(in: client)
        )

        if useHalfWidth {
            client.insertText(String(character), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            return true
        }

        guard let mapped = punctuationTransformer.transformed(character) else {
            return false
        }

        client.insertText(mapped, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        return true
    }

    private func handleLetter(_ character: Character, client: IMKTextInput) -> Bool {
        if dict.buffer.count == 4 {
            resolvePendingComposition(client)
        }

        guard dict.append(character) else {
            return false
        }

        updateUI(client)
        return true
    }

    private func numberSelectionIndex(from characters: String) -> Int? {
        guard let character = characters.first, character.isNumber else {
            return nil
        }
        return Int(String(character)).map { $0 - 1 }
    }

    private func commitCandidate(at index: Int, client: IMKTextInput) -> Bool {
        guard let text = dict.pick(at: index) else {
            return false
        }

        insertCommittedText(text, client: client)
        return true
    }

    private func resolvePendingComposition(_ client: IMKTextInput) {
        if commitCandidate(at: 0, client: client) {
            return
        }

        if settings.clearOnEmpty4thCode {
            dict.clear()
            updateUI(client)
            return
        }

        insertCommittedText(dict.buffer, client: client)
    }

    private func flushCompositionForExternalKey(_ client: IMKTextInput) {
        guard !dict.buffer.isEmpty else {
            return
        }

        resolvePendingComposition(client)
    }

    private func updateUI(_ client: IMKTextInput?) {
        guard let client else {
            clearComposition()
            return
        }

        client.setMarkedText(dict.buffer, selectionRange: NSRange(location: dict.buffer.count, length: 0), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))

        guard !dict.candidates.isEmpty else {
            pendingClientForCommit = nil
            candidatePresenter.hide()
            return
        }

        pendingClientForCommit = client
        var rect = NSRect.zero
        client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        candidatePresenter.show(candidates: dict.candidates, at: rect.origin)
    }

    private func clearComposition() {
        dict.clear()
        pendingClientForCommit = nil
        candidatePresenter.hide()
    }

    private func insertCommittedText(_ text: String, client: IMKTextInput) {
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        clearComposition()
    }

    private func precedingCharacter(in client: IMKTextInput) -> Character? {
        let selectedRange = client.selectedRange()
        guard selectedRange.location != NSNotFound, selectedRange.location > 0 else {
            return nil
        }

        return client.attributedSubstring(from: NSRange(location: selectedRange.location - 1, length: 1))?.string.last
    }
}
