import Foundation

public struct PunctuationTransformer {
    private let mappings: [Character: String] = [
        ",": "，", ".": "。", "?": "？", "!": "！", ":": "：", ";": "；",
        "(": "（", ")": "）", "[": "【", "]": "】", "{": "｛", "}": "｝",
        "<": "《", ">": "》", "\\": "、", "^": "……", "_": "——",
        "~": "～", "$": "￥", "\"": "”", "'": "’", "/": "、"
    ]

    public init() {}

    public func supports(_ character: Character) -> Bool {
        mappings[character] != nil
    }

    public func transformed(_ character: Character) -> String? {
        mappings[character]
    }

    public func shouldUseHalfWidth(
        for character: Character,
        globalHalfWidth: Bool,
        smartPunctuation: Bool,
        precedingCharacter: Character?
    ) -> Bool {
        guard supports(character) else { return false }
        if globalHalfWidth {
            return true
        }
        guard smartPunctuation,
              let precedingCharacter,
              precedingCharacter.isASCII else {
            return false
        }
        return true
    }
}
