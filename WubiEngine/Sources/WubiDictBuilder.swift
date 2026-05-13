// WubiDictBuilder.swift
// WubiEngine — 码表数据库构建工具

import Foundation
import SQLite3

private let SQLITE_TRANSIENT_PTR = unsafeBitCast(-1 as Int, to: sqlite3_destructor_type.self)

public final class WubiDictBuilder {
    
    /// 从文本码表构建 SQLite 数据库
    /// - Parameters:
    ///   - inputPath: 文本文件路径 (格式: 编码\t文字\t词频)
    ///   - outputPath: 输出数据库路径
    public static func build(from inputPath: String, to outputPath: String) throws {
        // 删除旧数据库
        try? FileManager.default.removeItem(atPath: outputPath)
        
        var db: OpaquePointer?
        guard sqlite3_open(outputPath, &db) == SQLITE_OK else {
            throw WubiDictError.cannotOpen(path: outputPath)
        }
        defer { sqlite3_close(db) }
        
        // 创建表
        let createTable = """
        CREATE TABLE dict (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            word TEXT NOT NULL,
            freq INTEGER DEFAULT 0
        );
        """
        sqlite3_exec(db, createTable, nil, nil, nil)
        
        // 创建索引
        sqlite3_exec(db, "CREATE INDEX idx_code ON dict(code);", nil, nil, nil)
        
        // 开始事务
        sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
        
        let insertSQL = "INSERT INTO dict (code, word, freq) VALUES (?, ?, ?);"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        
        let content = try String(contentsOfFile: inputPath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2 else { continue }
            
            let code = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let word = parts[1].trimmingCharacters(in: .whitespaces)
            let freq = parts.count > 2 ? (Int(parts[2]) ?? 0) : 0
            
            // 过滤包含过僻字（Ext-B 及以上，超出 BMP 平面，产生方框字）的条目
            if word.unicodeScalars.contains(where: { $0.value > 0xFFFF }) { continue }
            
            sqlite3_bind_text(stmt, 1, code, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_text(stmt, 2, word, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_int(stmt, 3, Int32(freq))
            
            sqlite3_step(stmt)
            sqlite3_reset(stmt)
        }
        
        sqlite3_exec(db, "COMMIT;", nil, nil, nil)
    }
    
    /// 构建包含内置基础数据的示例数据库
    public static func buildSample(to outputPath: String) throws {
        let tempTxt = NSTemporaryDirectory() + "wubi_sample.txt"
        let sampleData = """
        a	工	1000
        b	了	999
        c	以	998
        d	在	997
        e	有	996
        f	地	995
        g	一	994
        h	上	993
        i	不	992
        j	是	991
        k	中	990
        l	国	989
        m	同	988
        n	民	987
        o	为	986
        p	这	985
        q	我	984
        r	的	983
        s	要	982
        t	和	981
        u	产	980
        v	发	979
        w	人	978
        x	经	977
        y	主	976
        aaaa	工	100
        bbbb	子	100
        cccc	又	100
        dddd	大	100
        eeee	月	100
        ffff	土	100
        gggg	王	100
        hhhh	目	100
        iiii	水	100
        jjjj	日	100
        kkkk	口	100
        llll	田	100
        mmmm	山	100
        nnnn	已	100
        oooo	火	100
        pppp	之	100
        qqqq	金	100
        rrrr	白	100
        ssss	木	100
        tttt	禾	100
        uuuu	立	100
        vvvv	女	100
        wwww	人	100
        xxxx	幺	100
        yyyy	言	100
        """
        try sampleData.write(toFile: tempTxt, atomically: true, encoding: .utf8)
        try build(from: tempTxt, to: outputPath)
        try? FileManager.default.removeItem(atPath: tempTxt)
    }
}
