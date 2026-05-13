import Cocoa
import WubiEngine
import WubiSupport

final class CandidatePanel: NSPanel, CandidatePresenting {
    static let shared = CandidatePanel()

    private let stackView = NSStackView()
    private let containerView = NSView()
    private let candidateFont = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .regular)
    private let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
    private let arrowUp = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: nil)!
    private let arrowDown = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)!
    private let paginator = CandidatePaginator(pageSize: 9)
    private let positioner = CandidatePanelPositioner()

    private var currentPage = 0
    private var allCandidates: [Candidate] = []
    private var lastAnchorPoint: CGPoint = .zero

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        setupUI()
    }

    private func setupUI() {
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        containerView.layer?.cornerRadius = 8
        containerView.layer?.borderWidth = 0.5
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
        contentView = containerView

        stackView.orientation = .horizontal
        stackView.spacing = 6
        stackView.edgeInsets = NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
    }

    func show(candidates: [Candidate], at point: CGPoint) {
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

    func navigatePage(_ delta: Int) {
        currentPage = paginator.navigate(itemCount: allCandidates.count, currentPage: currentPage, delta: delta)
        renderPage()
        positionAndDisplay(at: lastAnchorPoint)
    }

    func hide() {
        allCandidates = []
        currentPage = 0
        orderOut(nil)
    }

    private func renderPage() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let page = paginator.page(for: allCandidates, currentPage: currentPage)

        if page.showsPrevious {
            stackView.addArrangedSubview(makeArrowButton(image: arrowUp, tooltip: "上一页", delta: -1))
        }

        for (offset, candidate) in page.items.enumerated() {
            let index = page.startIndex + offset
            stackView.addArrangedSubview(makeCandidateLabel(number: index + 1, text: candidate.text, index: index))
        }

        if page.showsNext {
            stackView.addArrangedSubview(makeArrowButton(image: arrowDown, tooltip: "下一页", delta: 1))
        }
    }

    private func makeCandidateLabel(number: Int, text: String, index: Int) -> NSView {
        let container = NSView()

        let numberLabel = NSTextField(labelWithString: "\(number)")
        numberLabel.font = numberFont
        numberLabel.textColor = .secondaryLabelColor
        numberLabel.alignment = .right
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(numberLabel)

        let dotLabel = NSTextField(labelWithString: ".")
        dotLabel.font = candidateFont
        dotLabel.textColor = .tertiaryLabelColor
        dotLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dotLabel)

        let textLabel = NSTextField(labelWithString: text)
        textLabel.font = candidateFont
        textLabel.textColor = .labelColor
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textLabel)

        let hitView = CandidateHitView(index: index)
        hitView.translatesAutoresizingMaskIntoConstraints = false
        hitView.wantsLayer = true
        hitView.layer?.cornerRadius = 3
        hitView.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0).cgColor
        container.addSubview(hitView)

        let click = NSClickGestureRecognizer(target: self, action: #selector(candidateClicked(_:)))
        hitView.addGestureRecognizer(click)

        NSLayoutConstraint.activate([
            numberLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            numberLabel.widthAnchor.constraint(equalToConstant: 14),
            dotLabel.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor),
            dotLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            textLabel.leadingAnchor.constraint(equalTo: dotLabel.trailingAnchor, constant: 2),
            textLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            textLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hitView.topAnchor.constraint(equalTo: container.topAnchor),
            hitView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hitView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: -4),
            hitView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: 4),
            container.heightAnchor.constraint(equalToConstant: 26)
        ])

        return container
    }

    private func makeArrowButton(image: NSImage, tooltip: String, delta: Int) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .inline
        button.isBordered = false
        button.image = image
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = tooltip
        button.target = self
        button.tag = delta
        button.action = #selector(arrowClicked(_:))
        button.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 20),
            button.heightAnchor.constraint(equalToConstant: 26)
        ])

        return button
    }

    @objc private func arrowClicked(_ sender: NSButton) {
        navigatePage(sender.tag)
    }

    @objc private func candidateClicked(_ gesture: NSClickGestureRecognizer) {
        guard let hitView = gesture.view as? CandidateHitView,
              allCandidates.indices.contains(hitView.candidateIndex) else {
            return
        }

        NotificationCenter.default.post(name: .commitCandidate, object: allCandidates[hitView.candidateIndex].text)
        hide()
    }

    private func positionAndDisplay(at point: CGPoint) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let contentSize = stackView.fittingSize
        let panelSize = CGSize(width: contentSize.width + 8, height: contentSize.height + 8)
        let frame = positioner.frame(anchor: point, panelSize: panelSize, screenFrame: screen.visibleFrame)
        setFrame(frame, display: true)
        orderFrontRegardless()
    }
}

extension Notification.Name {
    static let commitCandidate = Notification.Name("WubiCommitCandidate")
}

final class CandidateHitView: NSView {
    let candidateIndex: Int

    init(index: Int) {
        candidateIndex = index
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        candidateIndex = -1
        super.init(coder: coder)
    }
}
