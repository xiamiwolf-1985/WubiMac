import CoreGraphics

public struct CandidatePage<Item> {
    public let items: [Item]
    public let startIndex: Int
    public let currentPage: Int
    public let totalPages: Int

    public var showsPrevious: Bool { totalPages > 1 }
    public var showsNext: Bool { totalPages > 1 }

    public init(items: [Item], startIndex: Int, currentPage: Int, totalPages: Int) {
        self.items = items
        self.startIndex = startIndex
        self.currentPage = currentPage
        self.totalPages = totalPages
    }
}

public struct CandidatePaginator {
    public let pageSize: Int

    public init(pageSize: Int = 9) {
        self.pageSize = max(1, pageSize)
    }

    public func page<Item>(for items: [Item], currentPage: Int) -> CandidatePage<Item> {
        let totalPages = max(1, (items.count + pageSize - 1) / pageSize)
        let safePage = max(0, min(totalPages - 1, currentPage))
        let startIndex = safePage * pageSize
        let endIndex = min(startIndex + pageSize, items.count)
        let visibleItems = startIndex < endIndex ? Array(items[startIndex..<endIndex]) : []
        return CandidatePage(items: visibleItems, startIndex: startIndex, currentPage: safePage, totalPages: totalPages)
    }

    public func navigate(itemCount: Int, currentPage: Int, delta: Int) -> Int {
        let totalPages = max(1, (itemCount + pageSize - 1) / pageSize)
        return max(0, min(totalPages - 1, currentPage + delta))
    }
}

public struct CandidatePanelPositioner {
    private let verticalSpacing: CGFloat

    public init(verticalSpacing: CGFloat = 4) {
        self.verticalSpacing = verticalSpacing
    }

    public func frame(anchor: CGPoint, panelSize: CGSize, screenFrame: CGRect) -> CGRect {
        var originX = anchor.x
        var originY = anchor.y - panelSize.height - verticalSpacing

        if originX + panelSize.width > screenFrame.maxX {
            originX = screenFrame.maxX - panelSize.width
        }
        if originX < screenFrame.minX {
            originX = screenFrame.minX
        }
        if originY < screenFrame.minY {
            originY = anchor.y + verticalSpacing
        }
        if originY + panelSize.height > screenFrame.maxY {
            originY = screenFrame.maxY - panelSize.height
        }
        if originY < screenFrame.minY {
            originY = screenFrame.minY
        }

        return CGRect(origin: CGPoint(x: originX, y: originY), size: panelSize)
    }
}
