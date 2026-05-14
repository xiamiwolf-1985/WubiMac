// InputController.swift
// WubiMac — IMK 输入控制器

import Cocoa
import InputMethodKit
import WubiEngine
import WubiSupport

@objc(WubiInputController)
class WubiInputController: IMKInputController {
    
    private var dict: WubiDict
    private let punctuationTransformer = PunctuationTransformer()
    private var handledOtherKeySinceShift = false
    private var commitObserver: NSObjectProtocol?
    private var dictionaryChangeObserver: NSObjectProtocol?
    
    // 用来暂时持有被点击选中的 client，等通知来了再提交
    private var pendingClientForCommit: IMKTextInput?
    
    override init!(server: IMKServer!, delegate: Any!, client: Any!) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbPath = appSupport.appendingPathComponent("WubiMac/wubi86.db").path
        self.dict = WubiDict(dbPath: dbPath)
        try? self.dict.open()
        
        super.init(server: server, delegate: delegate, client: client)
        
        // 监听候选面板的鼠标点击选词通知
        self.commitObserver = NotificationCenter.default.addObserver(
            forName: .commitCandidate,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let text = note.object as? String,
                  let client = self?.pendingClientForCommit else { return }
            self?.commit(text, client: client)
            self?.pendingClientForCommit = nil
        }

        self.dictionaryChangeObserver = NotificationCenter.default.addObserver(
            forName: .wubiDictionaryDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadDictionary()
        }
    }
    
    deinit {
        if let obs = commitObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let obs = dictionaryChangeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        dict.close()
    }
    
    // 必须重写此方法以接收 flagsChanged（例如单一的 Shift 等修饰键事件）
    override func recognizedEvents(_ sender: Any!) -> Int {
        return Int(NSEvent.EventTypeMask.keyDown.rawValue | NSEvent.EventTypeMask.flagsChanged.rawValue)
    }
    
    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "WubiMac Settings")
        
        let clearItem = NSMenuItem(title: "四码无字时清空编码", action: #selector(toggleClearOnEmpty), keyEquivalent: "")
        clearItem.state = SettingsManager.shared.clearOnEmpty4thCode ? .on : .off
        // 设为 target self 才会被选中触发
        
        let smartPuncItem = NSMenuItem(title: "智能标点 (英文数字后半角)", action: #selector(toggleSmartPunc), keyEquivalent: "")
        smartPuncItem.state = SettingsManager.shared.smartPunctuation ? .on : .off
        
        let halfPuncItem = NSMenuItem(title: "全局半角标点", action: #selector(toggleHalfPunc), keyEquivalent: "")
        halfPuncItem.state = SettingsManager.shared.halfWidthPunctuation ? .on : .off

        let configItem = NSMenuItem(title: "配置...", action: #selector(openConfiguration), keyEquivalent: "")
        configItem.target = self
        
        menu.addItem(clearItem)
        menu.addItem(smartPuncItem)
        menu.addItem(halfPuncItem)
        menu.addItem(.separator())
        menu.addItem(configItem)
        return menu
    }
    
    @objc func toggleClearOnEmpty() { SettingsManager.shared.clearOnEmpty4thCode.toggle() }
    @objc func toggleSmartPunc() { SettingsManager.shared.smartPunctuation.toggle() }
    @objc func toggleHalfPunc() { SettingsManager.shared.halfWidthPunctuation.toggle() }
    @objc func openConfiguration() { ConfigurationWindowController.shared.showWindow(nil) }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let client = resolvedClient(from: sender) else { return false }
        
        if event.type == .flagsChanged {
            guard SettingsManager.shared.shiftTogglesEnglish else {
                handledOtherKeySinceShift = true
                return false
            }

            // 处理 Shift 单按切换中英文
            let modifiers = event.modifierFlags
            let hasShift = modifiers.contains(.shift)
            
            // 严谨检测：没有任何修饰键被按下，或者只有 Shift 被按下
            let otherModifiers = modifiers.intersection([.command, .option, .control])
            let onlyShiftPressed = hasShift && otherModifiers.isEmpty
            
            if onlyShiftPressed {
                // 只有 Shift 被按住
                handledOtherKeySinceShift = false
                return false
            } else if !hasShift && otherModifiers.isEmpty {
                // Shift 被释放，且没有其他修饰键干扰
                if !handledOtherKeySinceShift {
                    dict.toggleEnglish()
                    CandidatePanel.shared.hide()
                    handledOtherKeySinceShift = true // 防止重复触发
                    return true
                }
            } else {
                // 包含其他修饰键，或者是组合键，标记已处理
                handledOtherKeySinceShift = true
            }
            return false
        }
        
        if event.type != .keyDown { return false }
        
        // 标记有其他真实按键产生，防止抬起 Shift 时触发切换
        handledOtherKeySinceShift = true
        
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags
        
        // 忽略 Command 组合键
        if modifiers.contains(.command) { return false }
        
        // 增加 CapsLock 切换作为双重保险
        if keyCode == 57, SettingsManager.shared.capsLockTogglesEnglish {
            dict.toggleEnglish()
            CandidatePanel.shared.hide()
            return true
        }
        
        let chars = event.characters ?? ""
        
        if dict.englishMode { return false }
        
        // 处理退格
        if keyCode == 51 {
            if !dict.buffer.isEmpty {
                _ = dict.backspace()
                updateUI(client)
                return true
            }
            return false
        }
        
        // 处理 Esc
        if keyCode == 53 {
            if !dict.buffer.isEmpty {
                dict.clear()
                updateUI(client)
                return true
            }
            return false
        }
        
        // 处理空格
        if keyCode == 49 {
            if !dict.candidates.isEmpty {
                commit(dict.pick(at: 0)!, client: client)
                return true
            } else if !dict.buffer.isEmpty {
                // 有编码但没候选词时，输入空格应该把原编码上屏然后清空
                commit(dict.buffer, client: client)
                return true
            }
            return false
        }
        
        // 处理回车
        if keyCode == 36 {
            if !dict.buffer.isEmpty {
                commit(dict.buffer, client: client)
                return true
            }
            return false
        }
        
        if let pageDelta = pageNavigationDelta(for: keyCode) {
            if !dict.candidates.isEmpty {
                CandidatePanel.shared.navigatePage(pageDelta)
                return true
            }
        }
        
        // 处理数字选词
        if let char = chars.first, char.isNumber {
            let index = Int(String(char))! - 1
            if index >= 0 && index < dict.candidates.count {
                commit(dict.pick(at: index)!, client: client)
                return true
            }
        }
        
        // 标点符号映射
        if let char = chars.first, punctuationTransformer.supports(char) {
            let hadPendingComposition = !dict.buffer.isEmpty
            if hadPendingComposition {
                flushPendingComposition(client)
            }

            let useHalfWidth = !hadPendingComposition && punctuationTransformer.shouldUseHalfWidth(
                for: char,
                globalHalfWidth: SettingsManager.shared.halfWidthPunctuation,
                smartPunctuation: SettingsManager.shared.smartPunctuation,
                precedingCharacter: precedingCharacter(in: client)
            )

            if useHalfWidth {
                client.insertText(String(char), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                return true
            }

            guard let mapped = punctuationTransformer.transformed(char) else {
                return false
            }

            client.insertText(mapped, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            return true
        }
        
        // 处理字母输入
        if let char = chars.first, char.isLetter {
            if dict.buffer.count == 4 {
                // 如果已经有4码，自动将当前首选词上屏，然后将新字母作为下一个词的首码
                if !dict.candidates.isEmpty {
                    commit(dict.pick(at: 0)!, client: client)
                } else {
                    if SettingsManager.shared.clearOnEmpty4thCode {
                        dict.clear()
                        updateUI(client)
                    } else {
                        commit(dict.buffer, client: client)
                    }
                }
            }
            
            if dict.append(char) {
                updateUI(client)
                return true
            }
        }
        
        // 当按键未被输入法显式处理时（例如输入了不在映射表的符号，或者是越界的数字），
        // 如果此时缓冲区还有编码，我们应当将首选词自动上屏，然后再把这个按键交给系统处理以防止残留
        if !dict.buffer.isEmpty {
            flushPendingComposition(client)
        }

        return false
    }

    private func updateUI(_ client: IMKTextInput) {
        client.setMarkedText(dict.buffer, selectionRange: NSRange(location: dict.buffer.count, length: 0), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        
        if dict.candidates.isEmpty {
            CandidatePanel.shared.hide()
        } else {
            CandidatePanel.shared.show(candidates: dict.candidates, at: candidateAnchorPoint(for: client))
        }
    }
    
    private func commit(_ text: String, client: IMKTextInput) {
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        dict.clear()
        CandidatePanel.shared.hide()
    }
    
    // 输入法被注销或切换走时
    override func deactivateServer(_ sender: Any!) {
        let client = resolvedClient(from: sender)
        if let client = client, !dict.buffer.isEmpty {
            // 将未完成的输入强制提交上屏，防止在 Safari 中"吞"字母
            client.insertText(dict.buffer, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
        dict.clear()
        CandidatePanel.shared.hide()
        super.deactivateServer(sender)
    }
    
    // 输入焦点变换（例如从 Safari 地址栏点进网页内部）
    @objc func selectionChanged(_ sender: Any!) {
        // 如果缓冲区有内容，说明刚才的输入未完成，但在新的焦点下应当重置
        if !dict.buffer.isEmpty {
            dict.clear()
            CandidatePanel.shared.hide()
            // 通知客户端清除标记文字
            resolvedClient(from: sender)?.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
    }
    
    // 强制提交
    override func commitComposition(_ sender: Any!) {
        let client = resolvedClient(from: sender)
        if let client = client, !dict.buffer.isEmpty {
            client.insertText(dict.buffer, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            dict.clear()
            CandidatePanel.shared.hide()
        }
        super.commitComposition(sender)
    }
    
    private func flushPendingComposition(_ client: IMKTextInput) {
        guard !dict.buffer.isEmpty else { return }
        if !dict.candidates.isEmpty {
            commit(dict.pick(at: 0)!, client: client)
            return
        }
        if SettingsManager.shared.clearOnEmpty4thCode {
            dict.clear()
            updateUI(client)
        } else {
            commit(dict.buffer, client: client)
        }
    }

    private func precedingCharacter(in client: IMKTextInput) -> Character? {
        let selRange = client.selectedRange()
        guard selRange.location != NSNotFound && selRange.location > 0 else { return nil }
        return client.attributedSubstring(from: NSRange(location: selRange.location - 1, length: 1))?.string.last
    }

    private func pageNavigationDelta(for keyCode: UInt16) -> Int? {
        switch SettingsManager.shared.candidatePageKeySet {
        case .brackets:
            if keyCode == 33 { return -1 }
            if keyCode == 30 { return 1 }
        case .minusEqual:
            if keyCode == 27 { return -1 }
            if keyCode == 24 { return 1 }
        case .commaPeriod:
            if keyCode == 43 { return -1 }
            if keyCode == 47 { return 1 }
        }
        return nil
    }

    private func reloadDictionary() {
        dict.close()
        dict.clear()
        try? dict.open()
        CandidatePanel.shared.hide()
        pendingClientForCommit = nil
    }

    private func resolvedClient(from sender: Any?) -> IMKTextInput? {
        if let client = sender as? IMKTextInput {
            return client
        }
        return self.client() as? IMKTextInput
    }

    private func candidateAnchorPoint(for client: IMKTextInput) -> NSPoint {
        let markedRange = client.markedRange()
        let selectedRange = client.selectedRange()
        var candidateIndices: [Int] = []

        if markedRange.location != NSNotFound, selectedRange.location != NSNotFound {
            let relativeIndex = max(0, selectedRange.location - markedRange.location)
            candidateIndices.append(min(dict.buffer.count, relativeIndex))
        }

        candidateIndices.append(dict.buffer.count)
        candidateIndices.append(max(0, dict.buffer.count - 1))
        candidateIndices.append(0)

        for index in candidateIndices {
            var rect = NSRect.zero
            client.attributes(forCharacterIndex: index, lineHeightRectangle: &rect)
            if !rect.isEmpty {
                return NSPoint(x: rect.minX, y: rect.minY)
            }
        }

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visibleFrame = screen.visibleFrame
            return NSPoint(x: visibleFrame.minX + 32, y: visibleFrame.maxY - 64)
        }

        return .zero
    }
}
