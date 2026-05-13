// WubiDict.swift
// WubiEngine — 五笔码表查询引擎
// 通过 SQLite3 查询码表数据库，返回候选词列表

import Foundation
import SQLite3

// Xcode 26 / Swift 6 中 SQLITE_TRANSIENT 宏类型不兼容，需手动适配
private let SQLITE_TRANSIENT_PTR = unsafeBitCast(-1 as Int, to: sqlite3_destructor_type.self)

// MARK: - 错误定义

public enum WubiDictError: Error, LocalizedError {
    case cannotOpen(path: String)
    case corrupted
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .cannotOpen(let p): return "无法打开码表数据库: \(p)"
        case .corrupted:        return "码表数据库损坏"
        case .operationFailed(let message): return message
        }
    }
}

public struct WubiDictEntry: Equatable {
    public let id: Int64
    public let code: String
    public let word: String
    public let freq: Int

    public init(id: Int64 = 0, code: String, word: String, freq: Int) {
        self.id = id
        self.code = code
        self.word = word
        self.freq = freq
    }
}

// MARK: - 码表查询引擎

/// 五笔码表查询引擎
///
/// 职责：管理 SQLite 数据库连接，提供精确/前缀查询，维护输入缓冲区和候选词列表。
/// 所有公共 API 均限制在 MainActor 上执行，保证线程安全。
public final class WubiDict {

    // MARK: - 公共状态

    /// 当前输入缓冲区（最多4位，仅包含 a-y）
    public private(set) var buffer: String = ""

    /// 当前候选词列表（已按词频排序，最多9个）
    public private(set) var candidates: [Candidate] = []

    /// 是否处于英文直通模式
    public private(set) var englishMode: Bool = false

    // MARK: - 私有

    private var db: OpaquePointer?
    private let dbPath: String

    // MARK: - 生命周期

    public init(dbPath: String) {
        self.dbPath = dbPath
    }

    /// 打开码表数据库（只读）
    public func open() throws {
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw WubiDictError.cannotOpen(path: dbPath)
        }
    }

    /// 关闭数据库
    public func close() {
        if let d = db {
            sqlite3_close(d)
            db = nil
        }
    }

    // MARK: - 输入操作

    /// 追加一个按键到缓冲区
    /// - Parameter ch: 按键字符（a-y）
    /// - Returns: `true` 表示成功消费该按键
    @discardableResult
    public func append(_ ch: Character) -> Bool {
        guard !englishMode else { return false }
        guard ch >= "a" && ch <= "y" else { return false }
        guard buffer.count < 4 else { return false }

        buffer.append(ch)
        requery()
        return true
    }

    /// 退格：删除缓冲区末位
    /// - Returns: `true` 表示缓冲区仍有内容
    @discardableResult
    public func backspace() -> Bool {
        guard !buffer.isEmpty else { return false }
        buffer.removeLast()
        requery()
        return !buffer.isEmpty
    }

    /// 清空缓冲区和候选词
    public func clear() {
        buffer = ""
        candidates = []
    }

    /// 选择候选词
    /// - Parameter idx: 候选词索引（0-based）
    /// - Returns: 被选中的候选词文字，索引越界返回 nil
    public func pick(at idx: Int) -> String? {
        guard candidates.indices.contains(idx) else { return nil }
        let text = candidates[idx].text
        clear()
        return text
    }

    /// 切换中/英文模式
    public func toggleEnglish() {
        englishMode.toggle()
        clear()
    }

    // MARK: - 码表维护

    public static func entries(at dbPath: String, matching keyword: String = "", limit: Int = 500) throws -> [WubiDictEntry] {
        let db = try openWritableDatabase(at: dbPath)
        defer { sqlite3_close(db) }

        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let boundedLimit = max(1, min(limit, Int(Int32.max)))
        let sql: String
        if trimmedKeyword.isEmpty {
            sql = "SELECT id, code, word, freq FROM dict ORDER BY code ASC, freq DESC LIMIT ?;"
        } else {
            sql = "SELECT id, code, word, freq FROM dict WHERE code LIKE ? OR word LIKE ? ORDER BY code ASC, freq DESC LIMIT ?;"
        }

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw WubiDictError.operationFailed("无法查询词库")
        }

        if trimmedKeyword.isEmpty {
            sqlite3_bind_int(stmt, 1, Int32(boundedLimit))
        } else {
            let pattern = "%\(trimmedKeyword)%"
            sqlite3_bind_text(stmt, 1, pattern, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_text(stmt, 2, pattern, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_int(stmt, 3, Int32(boundedLimit))
        }

        var entries: [WubiDictEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            entries.append(entry(from: stmt))
        }
        return entries
    }

    @discardableResult
    public static func addEntry(_ entry: WubiDictEntry, to dbPath: String) throws -> Int64 {
        let code = normalizedCode(entry.code)
        let word = entry.word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidCode(code), !word.isEmpty else {
            throw WubiDictError.operationFailed("编码必须为 1-4 位 a-y 字母，词条不能为空")
        }

        let db = try openWritableDatabase(at: dbPath)
        defer { sqlite3_close(db) }

        let sql = "INSERT INTO dict (code, word, freq) VALUES (?, ?, ?);"
        try execute(db: db, sql: sql) { stmt in
            sqlite3_bind_text(stmt, 1, code, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_text(stmt, 2, word, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_int(stmt, 3, Int32(entry.freq))
        }
        return sqlite3_last_insert_rowid(db)
    }

    public static func deleteEntry(id: Int64, from dbPath: String) throws {
        let db = try openWritableDatabase(at: dbPath)
        defer { sqlite3_close(db) }

        try execute(db: db, sql: "DELETE FROM dict WHERE id = ?;") { stmt in
            sqlite3_bind_int64(stmt, 1, id)
        }
    }

    public static func exportEntries(from dbPath: String, to outputURL: URL) throws {
        let entries = try entries(at: dbPath, limit: Int.max)
        let content = entries
            .map { "\($0.code)\t\($0.word)\t\($0.freq)" }
            .joined(separator: "\n")
        try content.write(to: outputURL, atomically: true, encoding: .utf8)
    }

    public static func importEntries(from inputURL: URL, to dbPath: String, replacingExisting: Bool) throws -> Int {
        let content = try String(contentsOf: inputURL, encoding: .utf8)
        let parsedEntries = content
            .components(separatedBy: .newlines)
            .compactMap(parseEntryLine)

        guard !parsedEntries.isEmpty else {
            throw WubiDictError.operationFailed("导入文件中没有有效词条")
        }

        let db = try openWritableDatabase(at: dbPath)
        defer { sqlite3_close(db) }

        try ensureSchema(in: db)
        sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
        do {
            if replacingExisting {
                sqlite3_exec(db, "DELETE FROM dict;", nil, nil, nil)
            }

            let sql = "INSERT INTO dict (code, word, freq) VALUES (?, ?, ?);"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw WubiDictError.operationFailed("无法写入词库")
            }
            defer { sqlite3_finalize(stmt) }

            for entry in parsedEntries {
                sqlite3_bind_text(stmt, 1, entry.code, -1, SQLITE_TRANSIENT_PTR)
                sqlite3_bind_text(stmt, 2, entry.word, -1, SQLITE_TRANSIENT_PTR)
                sqlite3_bind_int(stmt, 3, Int32(entry.freq))
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw WubiDictError.operationFailed("写入词条失败")
                }
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
            }

            sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        } catch {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw error
        }

        return parsedEntries.count
    }

    // MARK: - 查询

    /// 根据当前缓冲区刷新候选词列表
    private func requery() {
        guard !buffer.isEmpty, db != nil else {
            candidates = []
            return
        }

        var result: [Candidate] = []

        // 1) 精确匹配：精确匹配的词永远比由于前缀推导出的词优先级高，并且在内部按词频排序
        let exact = fetchExact(buffer).sorted { $0.freq > $1.freq }
        result += exact

        // 2) 未满4码时追加前缀补全
        if buffer.count < 4 {
            let existingTexts = Set(exact.map(\.text))
            let prefix = fetchPrefix(buffer, excluding: existingTexts).sorted { $0.freq > $1.freq }
            result += prefix
        }

        // 取前9个作为候选词（精确匹配排在最前面）
        candidates = Array(result.prefix(9))
    }

    /// 精确匹配：code 完全等于输入
    private func fetchExact(_ code: String) -> [Candidate] {
        guard let db else { return [] }

        let sql = "SELECT word, code, freq FROM dict WHERE code = ? ORDER BY freq DESC LIMIT 9;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        sqlite3_bind_text(stmt, 1, code, -1, SQLITE_TRANSIENT_PTR)

        var items: [Candidate] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let word = String(cString: sqlite3_column_text(stmt, 0))
            let c    = String(cString: sqlite3_column_text(stmt, 1))
            let f    = Int(sqlite3_column_int64(stmt, 2))
            items.append(Candidate(text: word, code: c, freq: f, isPrefix: false))
        }
        return items
    }

    /// 前缀匹配：code 以输入开头（补全联想）
    private func fetchPrefix(_ code: String, excluding: Set<String>) -> [Candidate] {
        guard let db else { return [] }

        let sql = "SELECT word, code, freq FROM dict WHERE code LIKE ? AND code != ? ORDER BY freq DESC LIMIT 5;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        let pattern = code + "%"
        sqlite3_bind_text(stmt, 1, pattern, -1, SQLITE_TRANSIENT_PTR)
        sqlite3_bind_text(stmt, 2, code, -1, SQLITE_TRANSIENT_PTR)

        var items: [Candidate] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let word = String(cString: sqlite3_column_text(stmt, 0))
            guard !excluding.contains(word) else { continue }
            let c = String(cString: sqlite3_column_text(stmt, 1))
            let f = Int(sqlite3_column_int64(stmt, 2))
            items.append(Candidate(text: word, code: c, freq: f, isPrefix: true))
        }
        return items
    }

    private static func openWritableDatabase(at path: String) throws -> OpaquePointer? {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            throw WubiDictError.cannotOpen(path: path)
        }
        try ensureSchema(in: db)
        return db
    }

    private static func ensureSchema(in db: OpaquePointer?) throws {
        let createTable = """
        CREATE TABLE IF NOT EXISTS dict (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            word TEXT NOT NULL,
            freq INTEGER DEFAULT 0
        );
        """
        guard sqlite3_exec(db, createTable, nil, nil, nil) == SQLITE_OK,
              sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS idx_code ON dict(code);", nil, nil, nil) == SQLITE_OK else {
            throw WubiDictError.operationFailed("无法初始化词库结构")
        }
    }

    private static func execute(db: OpaquePointer?, sql: String, bind: (OpaquePointer?) -> Void) throws {
        try ensureSchema(in: db)
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw WubiDictError.operationFailed("无法准备词库写入")
        }
        bind(stmt)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw WubiDictError.operationFailed("词库写入失败")
        }
    }

    private static func entry(from stmt: OpaquePointer?) -> WubiDictEntry {
        let id = sqlite3_column_int64(stmt, 0)
        let code = String(cString: sqlite3_column_text(stmt, 1))
        let word = String(cString: sqlite3_column_text(stmt, 2))
        let freq = Int(sqlite3_column_int64(stmt, 3))
        return WubiDictEntry(id: id, code: code, word: word, freq: freq)
    }

    private static func parseEntryLine(_ line: String) -> WubiDictEntry? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#") else { return nil }

        let parts = trimmedLine
            .components(separatedBy: CharacterSet(charactersIn: "\t "))
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return nil }

        let code = normalizedCode(parts[0])
        let word = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidCode(code), !word.isEmpty else { return nil }
        let freq = parts.count > 2 ? (Int(parts[2]) ?? 0) : 0
        return WubiDictEntry(code: code, word: word, freq: freq)
    }

    private static func normalizedCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isValidCode(_ code: String) -> Bool {
        (1...4).contains(code.count) && code.allSatisfy { $0 >= "a" && $0 <= "y" }
    }
}
