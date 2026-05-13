import XCTest
@testable import WubiEngine

class WubiDictTests: XCTestCase {
    var dict: WubiDict!
    let dbPath = NSTemporaryDirectory() + "test_wubi.db"
    
    override func setUp() async throws {
        try WubiDictBuilder.buildSample(to: dbPath)
        dict = WubiDict(dbPath: dbPath)
        try dict.open()
    }
    
    override func tearDown() {
        dict.close()
        try? FileManager.default.removeItem(atPath: dbPath)
    }
    
    func testInput() {
        XCTAssertTrue(dict.append("g"))
        XCTAssertEqual(dict.buffer, "g")
        XCTAssertFalse(dict.candidates.isEmpty)
        XCTAssertEqual(dict.candidates.first?.text, "一")
    }
    
    func testBackspace() {
        dict.append("g")
        dict.append("g")
        XCTAssertTrue(dict.backspace())
        XCTAssertEqual(dict.buffer, "g")
    }
    
    func testPick() {
        dict.append("g")
        let word = dict.pick(at: 0)
        XCTAssertEqual(word, "一")
        XCTAssertTrue(dict.buffer.isEmpty)
    }
}
