import Cocoa
import UniformTypeIdentifiers
import WubiEngine
import WubiSupport

extension Notification.Name {
    static let wubiDictionaryDidChange = Notification.Name("WubiDictionaryDidChange")
}

final class ConfigurationWindowController: NSWindowController {
    static let shared = ConfigurationWindowController()

    private init() {
        let contentViewController = ConfigurationViewController()
        let window = NSWindow(contentViewController: contentViewController)
        window.title = "虾米五笔"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 860, height: 600))
        window.minSize = NSSize(width: 760, height: 520)
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private enum SettingsSection: Int, CaseIterable {
    case dictionary
    case shortcuts
    case habits

    var title: String {
        switch self {
        case .dictionary: return "词库"
        case .shortcuts: return "快捷键"
        case .habits: return "使用习惯"
        }
    }

    var subtitle: String {
        switch self {
        case .dictionary: return "导入、导出与维护码表"
        case .shortcuts: return "切换和候选翻页"
        case .habits: return "候选、标点与输入行为"
        }
    }

    var symbolName: String {
        switch self {
        case .dictionary: return "text.book.closed"
        case .shortcuts: return "keyboard"
        case .habits: return "slider.horizontal.3"
        }
    }
}

private final class ConfigurationViewController: NSViewController {
    private let sidebar = NSStackView()
    private let contentContainer = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private var sidebarButtons: [SettingsSection: SidebarButton] = [:]
    private var currentContentView: NSView?

    override func loadView() {
        view = NSView()
        buildUI()
        select(.dictionary)
    }

    private func buildUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let sidebarContainer = NSView()
        sidebarContainer.wantsLayer = true
        sidebarContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sidebarContainer)

        let appTitle = NSTextField(labelWithString: "虾米五笔")
        appTitle.font = .systemFont(ofSize: 20, weight: .semibold)
        appTitle.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(appTitle)

        let appSubtitle = NSTextField(labelWithString: "输入法设置")
        appSubtitle.font = .systemFont(ofSize: 12, weight: .regular)
        appSubtitle.textColor = .secondaryLabelColor
        appSubtitle.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(appSubtitle)

        sidebar.orientation = .vertical
        sidebar.alignment = .leading
        sidebar.spacing = 6
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(sidebar)

        for section in SettingsSection.allCases {
            let button = SidebarButton(section: section)
            button.target = self
            button.action = #selector(sectionClicked(_:))
            sidebarButtons[section] = button
            sidebar.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: sidebar.widthAnchor).isActive = true
        }

        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(subtitleLabel)

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            sidebarContainer.topAnchor.constraint(equalTo: view.topAnchor),
            sidebarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarContainer.widthAnchor.constraint(equalToConstant: 216),

            appTitle.topAnchor.constraint(equalTo: sidebarContainer.topAnchor, constant: 42),
            appTitle.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor, constant: 22),
            appTitle.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor, constant: -18),

            appSubtitle.topAnchor.constraint(equalTo: appTitle.bottomAnchor, constant: 2),
            appSubtitle.leadingAnchor.constraint(equalTo: appTitle.leadingAnchor),
            appSubtitle.trailingAnchor.constraint(equalTo: appTitle.trailingAnchor),

            sidebar.topAnchor.constraint(equalTo: appSubtitle.bottomAnchor, constant: 26),
            sidebar.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor, constant: 12),
            sidebar.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor, constant: -12),

            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 36),
            header.leadingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor, constant: 32),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            header.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.topAnchor.constraint(equalTo: header.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            contentContainer.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 18),
            contentContainer.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -28),
        ])
    }

    @objc private func sectionClicked(_ sender: SidebarButton) {
        select(sender.section)
    }

    private func select(_ section: SettingsSection) {
        sidebarButtons.forEach { key, button in
            button.isSelected = key == section
        }

        titleLabel.stringValue = section.title
        subtitleLabel.stringValue = section.subtitle
        currentContentView?.removeFromSuperview()

        let newView: NSView
        switch section {
        case .dictionary:
            newView = DictionarySettingsView()
        case .shortcuts:
            newView = ShortcutSettingsView()
        case .habits:
            newView = HabitSettingsView()
        }

        newView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(newView)
        NSLayoutConstraint.activate([
            newView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            newView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            newView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            newView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        currentContentView = newView
    }
}

private final class SidebarButton: NSButton {
    let section: SettingsSection
    var isSelected = false {
        didSet { updateAppearance() }
    }

    init(section: SettingsSection) {
        self.section = section
        super.init(frame: .zero)
        title = ""
        isBordered = false
        bezelStyle = .regularSquare
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        heightAnchor.constraint(equalToConstant: 48).isActive = true
        setupContent()
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: section.symbolName, accessibilityDescription: section.title)
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        imageView.contentTintColor = .secondaryLabelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        let titleLabel = NSTextField(labelWithString: section.title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: section.subtitle)
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 22),
            imageView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
        ])
    }

    private func updateAppearance() {
        layer?.cornerRadius = 8
        layer?.backgroundColor = isSelected
            ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.16).cgColor
            : NSColor.clear.cgColor
    }
}

private final class DictionarySettingsView: NSView, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let resolver = DatabasePathResolver()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let searchField = NSSearchField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let countBadge = NSTextField(labelWithString: "0")
    private let codeField = NSTextField()
    private let wordField = NSTextField()
    private let freqField = NSTextField()
    private let updateButton = NSButton()
    private let clearSelectionButton = NSButton()

    private var entries: [WubiDictEntry] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
        reloadEntries()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)

        let actionGroup = SettingsGroupView(title: "词库文件", subtitle: "支持 UTF-8 文本，格式为 编码、词条、词频 三列")
        let importButton = makeButton(title: "导入...", action: #selector(importDictionary), symbolName: "square.and.arrow.down")
        let exportButton = makeButton(title: "导出...", action: #selector(exportDictionary), symbolName: "square.and.arrow.up")
        let refreshButton = makeButton(title: "刷新", action: #selector(refreshDictionary), symbolName: "arrow.clockwise")
        let fileActions = NSStackView(views: [importButton, exportButton, refreshButton])
        fileActions.orientation = .horizontal
        fileActions.spacing = 8
        fileActions.alignment = .centerY
        actionGroup.addFullWidthView(fileActions)
        root.addArrangedSubview(actionGroup)
        actionGroup.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let editorGroup = SettingsGroupView(title: "词条编辑", subtitle: "可新增词条，也可选中下方词条后修改词频")
        codeField.placeholderString = "编码"
        wordField.placeholderString = "词条"
        freqField.placeholderString = "词频"
        freqField.stringValue = "0"
        let addButton = makeButton(title: "增加", action: #selector(addEntry), symbolName: "plus")
        updateButton.title = "保存修改"
        updateButton.target = self
        updateButton.action = #selector(updateSelectedEntry)
        updateButton.bezelStyle = .rounded
        updateButton.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "保存修改")
        updateButton.imagePosition = .imageLeading
        updateButton.isEnabled = false
        clearSelectionButton.title = "取消选择"
        clearSelectionButton.target = self
        clearSelectionButton.action = #selector(clearSelection)
        clearSelectionButton.bezelStyle = .rounded
        clearSelectionButton.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "取消选择")
        clearSelectionButton.imagePosition = .imageLeading
        clearSelectionButton.isEnabled = false
        let deleteButton = makeButton(title: "删除选中", action: #selector(deleteSelectedEntry), symbolName: "trash")
        let editBar = NSStackView(views: [codeField, wordField, freqField, addButton, updateButton, clearSelectionButton, deleteButton])
        editBar.orientation = .horizontal
        editBar.spacing = 8
        editBar.alignment = .centerY
        editorGroup.addFullWidthView(editBar)
        root.addArrangedSubview(editorGroup)
        editorGroup.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let listGroup = SettingsGroupView(title: "词条列表", subtitle: "显示当前码表中的词条，可按编码或词条搜索")
        searchField.placeholderString = "搜索编码或词条"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchChanged)

        countBadge.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        countBadge.textColor = .secondaryLabelColor
        countBadge.alignment = .right

        let listToolbar = NSStackView(views: [searchField, countBadge])
        listToolbar.orientation = .horizontal
        listToolbar.spacing = 10
        listToolbar.alignment = .centerY
        listGroup.addFullWidthView(listToolbar)

        tableView.addTableColumn(makeColumn(identifier: "code", title: "编码", width: 110))
        tableView.addTableColumn(makeColumn(identifier: "word", title: "词条", width: 300))
        tableView.addTableColumn(makeColumn(identifier: "freq", title: "词频", width: 90))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 28
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.target = self
        tableView.action = #selector(tableRowActivated)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .controlBackgroundColor
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        listGroup.addFullWidthView(scrollView)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)
        listGroup.addFullWidthView(statusLabel)
        root.addArrangedSubview(listGroup)
        listGroup.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.bottomAnchor.constraint(equalTo: bottomAnchor),

            importButton.widthAnchor.constraint(equalToConstant: 92),
            exportButton.widthAnchor.constraint(equalToConstant: 92),
            refreshButton.widthAnchor.constraint(equalToConstant: 82),
            codeField.widthAnchor.constraint(equalToConstant: 90),
            wordField.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            freqField.widthAnchor.constraint(equalToConstant: 84),
            addButton.widthAnchor.constraint(equalToConstant: 82),
            updateButton.widthAnchor.constraint(equalToConstant: 98),
            clearSelectionButton.widthAnchor.constraint(equalToConstant: 98),
            deleteButton.widthAnchor.constraint(equalToConstant: 110),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 260),
            countBadge.widthAnchor.constraint(equalToConstant: 120),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 210),
        ])
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard entries.indices.contains(row), let identifier = tableColumn?.identifier else { return nil }
        let entry = entries[row]
        let value: String
        switch identifier.rawValue {
        case "code": value = entry.code
        case "word": value = entry.word
        case "freq": value = "\(entry.freq)"
        default: value = ""
        }

        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        cell.identifier = identifier
        let textField = cell.textField ?? NSTextField(labelWithString: "")
        textField.stringValue = value
        textField.font = identifier.rawValue == "code"
            ? .monospacedSystemFont(ofSize: 13, weight: .regular)
            : .systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false
        if textField.superview == nil {
            cell.addSubview(textField)
            cell.textField = textField
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        return cell
    }

    @objc private func searchChanged() {
        reloadEntries()
    }

    @objc private func refreshDictionary() {
        reloadEntries()
    }

    @objc private func addEntry() {
        let entry = WubiDictEntry(
            code: codeField.stringValue,
            word: wordField.stringValue,
            freq: Int(freqField.stringValue) ?? 0
        )

        do {
            try WubiDict.addEntry(entry, to: resolver.databasePath)
            tableView.deselectAll(nil)
            resetEditor()
            notifyDictionaryChanged()
            reloadEntries()
            showStatus("已增加词条")
        } catch {
            showError(error)
        }
    }

    @objc private func updateSelectedEntry() {
        guard let selectedEntry = selectedEntry else {
            showStatus("请先选择要修改的词条")
            return
        }

        let updatedEntry = WubiDictEntry(
            id: selectedEntry.id,
            code: codeField.stringValue,
            word: wordField.stringValue,
            freq: Int(freqField.stringValue) ?? 0
        )

        do {
            try WubiDict.updateEntry(updatedEntry, in: resolver.databasePath)
            notifyDictionaryChanged()
            reloadEntries(selectingEntryID: updatedEntry.id)
            showStatus("已保存词条修改")
        } catch {
            showError(error)
        }
    }

    @objc private func deleteSelectedEntry() {
        guard let selectedEntry = selectedEntry else {
            showStatus("请先选择要删除的词条")
            return
        }

        do {
            try WubiDict.deleteEntry(id: selectedEntry.id, from: resolver.databasePath)
            notifyDictionaryChanged()
            tableView.deselectAll(nil)
            resetEditor()
            reloadEntries()
            showStatus("已删除词条")
        } catch {
            showError(error)
        }
    }

    @objc private func importDictionary() {
        let panel = NSOpenPanel()
        panel.title = "导入词库"
        var contentTypes: [UTType] = [.plainText]
        if let tabSeparatedText = UTType(filenameExtension: "tsv") {
            contentTypes.append(tabSeparatedText)
        }
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let alert = NSAlert()
        alert.messageText = "导入方式"
        alert.informativeText = "追加会保留现有词库，替换会先清空现有词库。"
        alert.addButton(withTitle: "追加")
        alert.addButton(withTitle: "替换")
        alert.addButton(withTitle: "取消")
        let response = alert.runModal()
        guard response != .alertThirdButtonReturn else { return }

        do {
            let importedCount = try WubiDict.importEntries(
                from: url,
                to: resolver.databasePath,
                replacingExisting: response == .alertSecondButtonReturn
            )
            notifyDictionaryChanged()
            reloadEntries()
            showStatus("已导入 \(importedCount) 条词条")
        } catch {
            showError(error)
        }
    }

    @objc private func exportDictionary() {
        let panel = NSSavePanel()
        panel.title = "导出词库"
        panel.nameFieldStringValue = "wubi86.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try WubiDict.exportEntries(from: resolver.databasePath, to: url)
            showStatus("已导出到 \(url.path)")
        } catch {
            showError(error)
        }
    }

    @objc private func clearSelection() {
        tableView.deselectAll(nil)
        resetEditor()
        showStatus("已取消选择")
    }

    @objc private func tableRowActivated() {
        syncEditorWithSelection()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        syncEditorWithSelection()
    }

    private func reloadEntries(selectingEntryID: Int64? = nil) {
        do {
            entries = try WubiDict.entries(at: resolver.databasePath, matching: searchField.stringValue)
            tableView.reloadData()
            reselectEntryIfNeeded(selectingEntryID)
            countBadge.stringValue = "\(entries.count) 条"
            showStatus(searchField.stringValue.isEmpty ? "显示当前词库前 \(entries.count) 条词条" : "搜索到 \(entries.count) 条词条")
        } catch {
            entries = []
            tableView.reloadData()
            countBadge.stringValue = "0 条"
            resetEditor()
            showError(error)
        }
    }

    private var selectedEntry: WubiDictEntry? {
        let row = tableView.selectedRow
        guard entries.indices.contains(row) else { return nil }
        return entries[row]
    }

    private func syncEditorWithSelection() {
        guard let entry = selectedEntry else {
            resetEditor()
            return
        }

        codeField.stringValue = entry.code
        wordField.stringValue = entry.word
        freqField.stringValue = "\(entry.freq)"
        updateEditorButtons(hasSelection: true)
    }

    private func resetEditor() {
        codeField.stringValue = ""
        wordField.stringValue = ""
        freqField.stringValue = "0"
        updateEditorButtons(hasSelection: false)
    }

    private func updateEditorButtons(hasSelection: Bool) {
        updateButton.isEnabled = hasSelection
        clearSelectionButton.isEnabled = hasSelection
    }

    private func reselectEntryIfNeeded(_ entryID: Int64?) {
        guard let entryID else {
            syncEditorWithSelection()
            return
        }

        guard let row = entries.firstIndex(where: { $0.id == entryID }) else {
            tableView.deselectAll(nil)
            syncEditorWithSelection()
            return
        }

        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
        syncEditorWithSelection()
    }

    private func notifyDictionaryChanged() {
        NotificationCenter.default.post(name: .wubiDictionaryDidChange, object: nil)
    }

    private func makeButton(title: String, action: Selector, symbolName: String) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        return button
    }

    private func makeColumn(identifier: String, title: String, width: CGFloat) -> NSTableColumn {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        return column
    }

    private func showStatus(_ text: String) {
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = text
    }

    private func showError(_ error: Error) {
        statusLabel.textColor = .systemRed
        statusLabel.stringValue = error.localizedDescription
    }
}

private final class ShortcutSettingsView: NSView {
    private let settings = SettingsManager.shared
    private let shiftToggle = NSSwitch()
    private let capsLockToggle = NSSwitch()
    private let pageKeyPopup = NSPopUpButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)

        let inputGroup = SettingsGroupView(title: "中英文切换", subtitle: "选择更顺手的模式切换按键")
        inputGroup.addRow(title: "Shift", detail: "单击 Shift 在中文和英文模式之间切换", control: shiftToggle)
        inputGroup.addRow(title: "Caps Lock", detail: "用 Caps Lock 作为额外的中英文切换键", control: capsLockToggle)
        root.addArrangedSubview(inputGroup)
        inputGroup.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        CandidatePageKeySet.allCases.forEach { item in
            pageKeyPopup.addItem(withTitle: item.displayName)
            pageKeyPopup.lastItem?.representedObject = item.rawValue
        }
        pageKeyPopup.target = self
        pageKeyPopup.action = #selector(saveSettings)
        pageKeyPopup.widthAnchor.constraint(equalToConstant: 160).isActive = true

        let candidateGroup = SettingsGroupView(title: "候选翻页", subtitle: "配置候选窗口上一页和下一页按键")
        candidateGroup.addRow(title: "翻页键组", detail: "在候选窗口打开时生效", control: pageKeyPopup)
        root.addArrangedSubview(candidateGroup)
        candidateGroup.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        [shiftToggle, capsLockToggle].forEach {
            $0.target = self
            $0.action = #selector(saveSettings)
        }

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private func loadSettings() {
        shiftToggle.state = settings.shiftTogglesEnglish ? .on : .off
        capsLockToggle.state = settings.capsLockTogglesEnglish ? .on : .off
        pageKeyPopup.selectItem(withTitle: settings.candidatePageKeySet.displayName)
    }

    @objc private func saveSettings() {
        settings.shiftTogglesEnglish = shiftToggle.state == .on
        settings.capsLockTogglesEnglish = capsLockToggle.state == .on
        if let rawValue = pageKeyPopup.selectedItem?.representedObject as? String,
           let keySet = CandidatePageKeySet(rawValue: rawValue) {
            settings.candidatePageKeySet = keySet
        }
    }
}

private final class HabitSettingsView: NSView {
    private let settings = SettingsManager.shared
    private let clearOnEmptyToggle = NSSwitch()
    private let smartPunctuationToggle = NSSwitch()
    private let halfWidthPunctuationToggle = NSSwitch()
    private let candidatePageSizeStepper = NSStepper()
    private let candidatePageSizeLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)

        [clearOnEmptyToggle, smartPunctuationToggle, halfWidthPunctuationToggle].forEach {
            $0.target = self
            $0.action = #selector(saveSettings)
        }

        let inputGroup = SettingsGroupView(title: "输入行为", subtitle: "控制编码没有候选时的处理方式")
        inputGroup.addRow(title: "四码无字时清空编码", detail: "继续输入下一个字时自动清空无效编码", control: clearOnEmptyToggle)
        root.addArrangedSubview(inputGroup)
        inputGroup.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let punctuationGroup = SettingsGroupView(title: "标点", subtitle: "控制中文输入时的标点宽度")
        punctuationGroup.addRow(title: "智能标点", detail: "英文和数字后自动使用半角标点", control: smartPunctuationToggle)
        punctuationGroup.addRow(title: "全局半角标点", detail: "始终输出半角标点", control: halfWidthPunctuationToggle)
        root.addArrangedSubview(punctuationGroup)
        punctuationGroup.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        candidatePageSizeStepper.minValue = 3
        candidatePageSizeStepper.maxValue = 9
        candidatePageSizeStepper.increment = 1
        candidatePageSizeStepper.target = self
        candidatePageSizeStepper.action = #selector(pageSizeChanged)

        candidatePageSizeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        candidatePageSizeLabel.alignment = .right
        candidatePageSizeLabel.widthAnchor.constraint(equalToConstant: 26).isActive = true

        let pageSizeControl = NSStackView(views: [candidatePageSizeStepper, candidatePageSizeLabel])
        pageSizeControl.orientation = .horizontal
        pageSizeControl.spacing = 8
        pageSizeControl.alignment = .centerY

        let candidateGroup = SettingsGroupView(title: "候选窗口", subtitle: "调整候选显示密度")
        candidateGroup.addRow(title: "每页候选数", detail: "可设置为 3 到 9 个", control: pageSizeControl)
        root.addArrangedSubview(candidateGroup)
        candidateGroup.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private func loadSettings() {
        clearOnEmptyToggle.state = settings.clearOnEmpty4thCode ? .on : .off
        smartPunctuationToggle.state = settings.smartPunctuation ? .on : .off
        halfWidthPunctuationToggle.state = settings.halfWidthPunctuation ? .on : .off
        candidatePageSizeStepper.integerValue = settings.candidatePageSize
        candidatePageSizeLabel.stringValue = "\(settings.candidatePageSize)"
    }

    @objc private func pageSizeChanged() {
        settings.candidatePageSize = candidatePageSizeStepper.integerValue
        candidatePageSizeLabel.stringValue = "\(settings.candidatePageSize)"
    }

    @objc private func saveSettings() {
        settings.clearOnEmpty4thCode = clearOnEmptyToggle.state == .on
        settings.smartPunctuation = smartPunctuationToggle.state == .on
        settings.halfWidthPunctuation = halfWidthPunctuationToggle.state == .on
    }
}

private final class SettingsGroupView: NSView {
    private let contentStack = NSStackView()

    init(title: String, subtitle: String) {
        super.init(frame: .zero)
        buildUI(title: title, subtitle: subtitle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addRow(title: String, detail: String, control: NSView) {
        let row = SettingsRowView(title: title, detail: detail, control: control)
        contentStack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    func addFullWidthView(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    private func buildUI(title: String, subtitle: String) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.82).cgColor
        layer?.cornerRadius = 10
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        contentStack.orientation = .vertical
        contentStack.spacing = 10
        contentStack.alignment = .leading
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }
}

private final class SettingsRowView: NSView {
    init(title: String, detail: String, control: NSView) {
        super.init(frame: .zero)
        buildUI(title: title, detail: detail, control: control)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI(title: String, detail: String, control: NSView) {
        translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(detailLabel)

        control.translatesAutoresizingMaskIntoConstraints = false
        addSubview(control)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -16),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -16),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4),

            control.trailingAnchor.constraint(equalTo: trailingAnchor),
            control.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
