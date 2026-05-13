// Candidate.swift
// WubiEngine — 候选词数据模型

import Foundation

/// 五笔候选词条目
public struct Candidate: Sendable, Equatable {
    /// 候选词文字（汉字/词组）
    public let text: String
    /// 五笔编码
    public let code: String
    /// 词频（越高越优先）
    public let freq: Int
    /// 是否为前缀补全候选（输入未满4码时的联想）
    public let isPrefix: Bool

    public init(text: String, code: String, freq: Int = 0, isPrefix: Bool = false) {
        self.text = text
        self.code = code
        self.freq = freq
        self.isPrefix = isPrefix
    }
}
