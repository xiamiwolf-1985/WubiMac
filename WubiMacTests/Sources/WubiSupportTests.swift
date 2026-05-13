import Foundation
import XCTest
@testable import WubiSupport
@testable import WubiEngine

final class WubiSupportTests: XCTestCase {
    func testDatabasePathResolverBuildsExpectedPath() {
        let root = URL(fileURLWithPath: "/tmp/wubimac-tests", isDirectory: true)
        let resolver = DatabasePathResolver(applicationSupportURL: root, containerName: "CustomApp", databaseName: "dict.db")

        XCTAssertEqual(resolver.databaseDirectoryURL.path, "/tmp/wubimac-tests/CustomApp")
        XCTAssertEqual(resolver.databaseURL.path, "/tmp/wubimac-tests/CustomApp/dict.db")
        XCTAssertEqual(resolver.databasePath, "/tmp/wubimac-tests/CustomApp/dict.db")
    }

    func testPunctuationTransformerUsesSmartHalfWidthAfterASCII() {
        let transformer = PunctuationTransformer()

        XCTAssertTrue(transformer.shouldUseHalfWidth(for: ",", globalHalfWidth: false, smartPunctuation: true, precedingCharacter: "a"))
        XCTAssertTrue(transformer.shouldUseHalfWidth(for: ".", globalHalfWidth: false, smartPunctuation: true, precedingCharacter: "8"))
        XCTAssertTrue(transformer.shouldUseHalfWidth(for: ",", globalHalfWidth: false, smartPunctuation: true, precedingCharacter: "."))
        XCTAssertFalse(transformer.shouldUseHalfWidth(for: ",", globalHalfWidth: false, smartPunctuation: true, precedingCharacter: "中"))
        XCTAssertFalse(transformer.shouldUseHalfWidth(for: ",", globalHalfWidth: false, smartPunctuation: false, precedingCharacter: "a"))
        XCTAssertFalse(transformer.shouldUseHalfWidth(for: ",", globalHalfWidth: false, smartPunctuation: true, precedingCharacter: nil))
    }

    func testPunctuationTransformerReturnsMappedFullWidthText() {
        let transformer = PunctuationTransformer()

        XCTAssertEqual(transformer.transformed(","), "，")
        XCTAssertEqual(transformer.transformed("/"), "、")
        XCTAssertNil(transformer.transformed("a"))
    }

    func testCandidatePaginatorClampsPages() {
        let paginator = CandidatePaginator(pageSize: 3)
        let page = paginator.page(for: [1, 2, 3, 4, 5], currentPage: 9)

        XCTAssertEqual(page.currentPage, 1)
        XCTAssertEqual(page.startIndex, 3)
        XCTAssertEqual(page.items, [4, 5])
        XCTAssertEqual(page.totalPages, 2)
    }

    func testCandidatePanelPositionerKeepsFrameInsideScreen() {
        let positioner = CandidatePanelPositioner()
        let frame = positioner.frame(
            anchor: CGPoint(x: 480, y: 10),
            panelSize: CGSize(width: 120, height: 40),
            screenFrame: CGRect(x: 0, y: 0, width: 500, height: 300)
        )

        XCTAssertGreaterThanOrEqual(frame.minX, 0)
        XCTAssertLessThanOrEqual(frame.maxX, 500)
        XCTAssertGreaterThanOrEqual(frame.minY, 0)
        XCTAssertLessThanOrEqual(frame.maxY, 300)
    }

    func testCompositionResolverPrefersCandidateThenClearOrCommitBuffer() {
        let resolver = CompositionResolver()
        let candidates = [Candidate(text: "一", code: "g", freq: 1)]

        XCTAssertEqual(resolver.resolve(buffer: "g", candidates: candidates, clearOnEmpty4thCode: true), .commitCandidate(index: 0))
        XCTAssertEqual(resolver.resolve(buffer: "gggg", candidates: [], clearOnEmpty4thCode: true), .clear)
        XCTAssertEqual(resolver.resolve(buffer: "gggg", candidates: [], clearOnEmpty4thCode: false), .commitBuffer)
        XCTAssertEqual(resolver.resolve(buffer: "", candidates: [], clearOnEmpty4thCode: false), .none)
    }

    func testPunctuationShouldDefaultToFullWidthAfterCompositionCommits() {
        let resolver = CompositionResolver()
        let transformer = PunctuationTransformer()
        let candidates = [Candidate(text: "一", code: "g", freq: 1)]
        let hadPendingComposition = true

        XCTAssertEqual(resolver.resolve(buffer: "g", candidates: candidates, clearOnEmpty4thCode: true), .commitCandidate(index: 0))
        let useHalfWidth = !hadPendingComposition && transformer.shouldUseHalfWidth(for: ",", globalHalfWidth: false, smartPunctuation: true, precedingCharacter: "a")
        XCTAssertFalse(useHalfWidth)
        XCTAssertEqual(transformer.transformed(","), "，")
        XCTAssertEqual(transformer.transformed("."), "。")
    }

    func testShiftToggleTrackerOnlyTogglesForCleanShiftTap() {
        var tracker = ShiftToggleTracker()

        XCTAssertEqual(tracker.handleModifierChange(hasShift: true, hasOtherModifiers: false), .passthrough)
        XCTAssertEqual(tracker.handleModifierChange(hasShift: false, hasOtherModifiers: false), .toggleEnglish)

        tracker.recordKeyPress()
        XCTAssertEqual(tracker.handleModifierChange(hasShift: false, hasOtherModifiers: false), .passthrough)

        XCTAssertEqual(tracker.handleModifierChange(hasShift: true, hasOtherModifiers: true), .passthrough)
        XCTAssertEqual(tracker.handleModifierChange(hasShift: false, hasOtherModifiers: true), .passthrough)
    }

    func testUserDefaultsSettingsStoreHonorsDefaults() {
        let defaults = UserDefaults(suiteName: "WubiSupportTests")!
        defaults.removePersistentDomain(forName: "WubiSupportTests")
        let store = UserDefaultsSettingsStore(defaults: defaults)

        XCTAssertTrue(store.clearOnEmpty4thCode)
        XCTAssertTrue(store.smartPunctuation)
        XCTAssertFalse(store.halfWidthPunctuation)
        XCTAssertTrue(store.shiftTogglesEnglish)
        XCTAssertTrue(store.capsLockTogglesEnglish)
        XCTAssertEqual(store.candidatePageKeySet, .brackets)
        XCTAssertEqual(store.candidatePageSize, 9)

        store.clearOnEmpty4thCode = false
        store.smartPunctuation = false
        store.halfWidthPunctuation = true
        store.shiftTogglesEnglish = false
        store.capsLockTogglesEnglish = false
        store.candidatePageKeySet = .minusEqual
        store.candidatePageSize = 4

        XCTAssertFalse(store.clearOnEmpty4thCode)
        XCTAssertFalse(store.smartPunctuation)
        XCTAssertTrue(store.halfWidthPunctuation)
        XCTAssertFalse(store.shiftTogglesEnglish)
        XCTAssertFalse(store.capsLockTogglesEnglish)
        XCTAssertEqual(store.candidatePageKeySet, .minusEqual)
        XCTAssertEqual(store.candidatePageSize, 4)

        store.candidatePageSize = 1
        XCTAssertEqual(store.candidatePageSize, 3)

        store.candidatePageSize = 20
        XCTAssertEqual(store.candidatePageSize, 9)
    }
}
