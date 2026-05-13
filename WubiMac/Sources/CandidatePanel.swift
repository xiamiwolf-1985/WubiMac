// CandidatePanel.swift
// WubiMac — 候选词浮窗

import Cocoa
import WubiEngine
import WubiSupport

class CandidatePanel: NSPanel {
    static let shared = CandidatePanel()
    
    private let stackView = NSStackView()
    private let containerView = NSView()
    
    private let candidateFont = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .regular)
    private let numberFont  = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
    
    private let arrowUp   = NSImage(systemSymbolName: "chevron.up",   accessibilityDescription: nil)!
    private let arrowDown = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)!
    
    /// 每页最多显示几个候选词
    private var pageSize: Int {
        SettingsManager.shared.candidatePageSize
    }
    
    /// 当前页（多页时滚动）
    private var currentPage = 0
    
    /// 当前所有候选（分页前的完整列表）
    private var allCandidates: [Candidate] = []
    
    /// 记录上次展示的坐标，用于判断是否需要重新定位
    private var lastAnchorPoint: NSPoint = .zero
    
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        
        setupUI()
    }
    
    private func setupUI() {
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        containerView.layer?.cornerRadius = 8
        containerView.layer?.borderWidth = 0.5
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        self.contentView = containerView
        
        stackView.orientation = .horizontal
        stackView.spacing = 6
        stackView.edgeInsets = NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
    }
    
    func show(candidates: [Candidate], at point: NSPoint) {
        guard !candidates.isEmpty else {
            hide()
            return
        }
        
        allCandidates = candidates
        currentPage = 0
        lastAnchorPoint = point
        
        renderPage()
        positionAndDisplay(at: point)
    }
    
    private func renderPage() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let totalPages = max(1, (allCandidates.count + pageSize - 1) / pageSize)
        let start = currentPage * pageSize
        let end   = min(start + pageSize, allCandidates.count)
        let page  = Array(allCandidates[start..<end])
        
        // 左翻页箭头（仅非首页显示）
        if totalPages > 1 {
            let arrowBtn = makeArrowBtn(image: arrowUp, tooltip: "上一页") { [weak self] in
                self?.navigatePage(-1)
            }
            stackView.addArrangedSubview(arrowBtn)
        }
        
        // 候选词标签
        for (i, cand) in page.enumerated() {
            let idx = start + i
            let item = makeCandidateLabel(number: idx + 1, text: cand.text, index: idx)
            stackView.addArrangedSubview(item)
        }
        
        // 右翻页箭头（仅非末页显示）
        if totalPages > 1 {
            let arrowBtn = makeArrowBtn(image: arrowDown, tooltip: "下一页") { [weak self] in
                self?.navigatePage(1)
            }
            stackView.addArrangedSubview(arrowBtn)
        }
    }
    
    private func makeCandidateLabel(number: Int, text: String, index: Int) -> NSView {
        let container = NSView()
        
        // 序号
        let numLabel = NSTextField(labelWithString: "\(number)")
        numLabel.font = numberFont
        numLabel.textColor = .secondaryLabelColor
        numLabel.alignment = .right
        numLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(numLabel)
        
        // 分隔符 "."
        let dot = NSTextField(labelWithString: ".")
        dot.font = candidateFont
        dot.textColor = .tertiaryLabelColor
        dot.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dot)
        
        // 候选文字
        let textLabel = NSTextField(labelWithString: text)
        textLabel.font = candidateFont
        textLabel.textColor = .labelColor
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textLabel)
        
        // 点击热区
        let hitView = CandidateHitView(index: index)
        hitView.translatesAutoresizingMaskIntoConstraints = false
        hitView.wantsLayer = true
        hitView.layer?.cornerRadius = 3
        hitView.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.0).cgColor
        container.addSubview(hitView)
        
        let click = NSClickGestureRecognizer(target: self, action: #selector(candidateClicked(_:)))
        hitView.addGestureRecognizer(click)
        
        NSLayoutConstraint.activate([
            numLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            numLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            numLabel.widthAnchor.constraint(equalToConstant: 14),
            
            dot.leadingAnchor.constraint(equalTo: numLabel.trailingAnchor),
            dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            textLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 2),
            textLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            textLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            hitView.topAnchor.constraint(equalTo: container.topAnchor),
            hitView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hitView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: -4),
            hitView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: 4),
            
            container.heightAnchor.constraint(equalToConstant: 26),
        ])
        
        return container
    }
    
    private func makeArrowBtn(image: NSImage, tooltip: String, action: @escaping () -> Void) -> NSView {
        let btn = NSButton()
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.image = image
        btn.imageScaling = .scaleProportionallyDown
        btn.contentTintColor = .secondaryLabelColor
        btn.toolTip = tooltip
        btn.target = self
        btn.tag = image === arrowUp ? -1 : 1
        btn.action = #selector(arrowClicked(_:))
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 20),
            btn.heightAnchor.constraint(equalToConstant: 26),
        ])
        return btn
    }
    
    @objc private func arrowClicked(_ sender: NSButton) {
        navigatePage(sender.tag)
    }
    
    func navigatePage(_ delta: Int) {
        let totalPages = max(1, (allCandidates.count + pageSize - 1) / pageSize)
        currentPage = max(0, min(totalPages - 1, currentPage + delta))
        renderPage()
        // 保持当前位置不变重新布局
        positionAndDisplay(at: lastAnchorPoint)
    }
    
    @objc private func candidateClicked(_ gesture: NSClickGestureRecognizer) {
        // 从 CandidateHitView 获取候选词索引
        guard let hitView = gesture.view as? CandidateHitView else { return }
        let index = hitView.candidateIndex
        guard index >= 0 && index < allCandidates.count else { return }
        let text = allCandidates[index].text
        NotificationCenter.default.post(name: .commitCandidate, object: text)
        hide()
    }
    
    /// 将面板定位到屏幕内（不超过左/右/下边缘）
    private func positionAndDisplay(at point: NSPoint) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        
        // screen.visibleFrame 使用的是 flip 坐标系（origin 在左上角）
        let screenFrame = screen.visibleFrame
        
        // 面板尺寸
        let panelSize = stackView.fittingSize
        let panelWidth  = panelSize.width  + 8   // 8 = containerView 的 padding
        let panelHeight = panelHeight(for: panelSize.height) + 8
        
        // 默认放在光标下方（Y = 光标Y，macOS 坐标系 Y 向上增长）
        var originX = point.x
        var originY = point.y - panelHeight - 4  // 面板在光标上方留 4pt 间隙
        
        // 右边界检测：如果面板右侧超出屏幕右缘，左移
        if originX + panelWidth > screenFrame.maxX {
            originX = screenFrame.maxX - panelWidth
        }
        // 左边界检测：如果左侧超出，左移到至少 x = 0
        if originX < screenFrame.minX {
            originX = screenFrame.minX
        }
        // 下边界检测：如果面板跑到屏幕外（originY < 0），改放光标上方（point.y）
        if originY < screenFrame.minY {
            originY = point.y + 4
        }
        // 再检查上方是否也超出
        if originY + panelHeight > screenFrame.maxY {
            originY = screenFrame.maxY - panelHeight
        }
        if originY < screenFrame.minY {
            originY = screenFrame.minY
        }
        
        self.setFrame(NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight), display: true)
        self.orderFrontRegardless()
    }
    
    private func panelHeight(for contentHeight: CGFloat) -> CGFloat {
        return contentHeight
    }
    
    func hide() {
        allCandidates = []
        self.orderOut(nil)
    }
}

extension Notification.Name {
    static let commitCandidate = Notification.Name("WubiCommitCandidate")
}

/// 候选词点击热区视图，用于存储候选词索引
class CandidateHitView: NSView {
    let candidateIndex: Int
    
    init(index: Int) {
        self.candidateIndex = index
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        self.candidateIndex = -1
        super.init(coder: coder)
    }
}
