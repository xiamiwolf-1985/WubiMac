import XCTest
@testable import WubiEngine

final class WubiDictBehaviorTests: XCTestCase {
    private var dict: WubiDict!
    private let dbPath = NSTemporaryDirectory() + "test_wubi_behavior.db"

    override func setUp() async throws {
        try WubiDictBuilder.buildSample(to: dbPath)
        dict = WubiDict(dbPath: dbPath)
        try dict.open()
    }

    override func tearDown() {
        dict.close()
        try? FileManager.default.removeItem(atPath: dbPath)
    }

    func testExactResultsAppearBeforePrefixResults() {
        XCTAssertTrue(dict.append("g"))

        XCTAssertEqual(dict.candidates.first?.text, "一")
        XCTAssertEqual(dict.candidates.first?.isPrefix, false)
        XCTAssertTrue(dict.candidates.contains(where: \ .isPrefix))
    }

    func testEnglishModePreventsInputAndClearsBuffer() {
        XCTAssertTrue(dict.append("g"))
        dict.toggleEnglish()

        XCTAssertTrue(dict.buffer.isEmpty)
        XCTAssertTrue(dict.candidates.isEmpty)
        XCTAssertTrue(dict.englishMode)
        XCTAssertFalse(dict.append("g"))
    }

    func testAppendRejectsZAndFifthCode() {
        XCTAssertFalse(dict.append("z"))
        XCTAssertTrue(dict.append("g"))
        XCTAssertTrue(dict.append("g"))
        XCTAssertTrue(dict.append("g"))
        XCTAssertTrue(dict.append("g"))
        XCTAssertFalse(dict.append("g"))
        XCTAssertEqual(dict.buffer, "gggg")
    }

    func testBackspaceClearsCandidatesWhenBufferBecomesEmpty() {
        XCTAssertTrue(dict.append("g"))
        XCTAssertFalse(dict.candidates.isEmpty)

        XCTAssertFalse(dict.backspace())
        XCTAssertTrue(dict.buffer.isEmpty)
        XCTAssertTrue(dict.candidates.isEmpty)
    }

    func testDictionaryEntryManagementAddsAndDeletesEntries() throws {
        let id = try WubiDict.addEntry(WubiDictEntry(code: "xy", word: "测试", freq: 42), to: dbPath)
        var entries = try WubiDict.entries(at: dbPath, matching: "测试")

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, id)
        XCTAssertEqual(entries.first?.code, "xy")

        try WubiDict.deleteEntry(id: id, from: dbPath)
        entries = try WubiDict.entries(at: dbPath, matching: "测试")
        XCTAssertTrue(entries.isEmpty)
    }

    func testDictionaryEntryManagementUpdatesExistingEntry() throws {
        let id = try WubiDict.addEntry(WubiDictEntry(code: "xy", word: "测试", freq: 42), to: dbPath)

        try WubiDict.updateEntry(WubiDictEntry(id: id, code: "xh", word: "测试词", freq: 99), in: dbPath)

        let entries = try WubiDict.entries(at: dbPath, matching: "测试词")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, id)
        XCTAssertEqual(entries.first?.code, "xh")
        XCTAssertEqual(entries.first?.freq, 99)
    }

    func testDictionaryImportAndExportEntries() throws {
        let importURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wubi-import.txt")
        let exportURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wubi-export.txt")
        try "xy\t测试\t42\nzz\t跳过\t10\ngg\t一一\t5".write(to: importURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: importURL)
            try? FileManager.default.removeItem(at: exportURL)
        }

        let count = try WubiDict.importEntries(from: importURL, to: dbPath, replacingExisting: true)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(try WubiDict.entries(at: dbPath, matching: "").count, 2)

        try WubiDict.exportEntries(from: dbPath, to: exportURL)
        let exported = try String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertTrue(exported.contains("xy\t测试\t42"))
        XCTAssertTrue(exported.contains("gg\t一一\t5"))
    }
}
