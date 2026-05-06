import Foundation

// MARK: - 静音/停顿配置

enum PauseConfig {
    // MARK: - 自动停顿基准值（毫秒）
    enum AutoPause {
        static let sameRole = 250
        static let differentRole = 600
        static let narratorToRole = 650
        static let roleToNarrator = 750
    }

    // MARK: - 标点额外停顿
    enum Punctuation {
        static let questionMark = 150
        static let exclamationMark = 150
        static let ellipsis = 250
    }

    // MARK: - 上限
    enum Max {
        static let autoPause = 1200
        static let manualPause = 3000
    }

    // MARK: - 手动标签停顿
    enum Manual {
        static let shortPause = 300
        static let mediumPause = 600
        static let longPause = 1000
    }

    // MARK: - 淡入淡出
    enum Fade {
        static let segmentFadeMs = 20
        static let fullStartFadeMs = 60
        static let fullEndFadeMs = 80
    }
}

// MARK: - 停顿标签处理器

enum PauseTagProcessor {
    /// 支持的停顿标签及其对应毫秒数
    private static let tagPatterns: [(pattern: String, value: Int)] = [
        ("[停顿短]", PauseConfig.Manual.shortPause),
        ("[停顿中]", PauseConfig.Manual.mediumPause),
        ("[停顿长]", PauseConfig.Manual.longPause),
    ]

    /// 从文本中提取停顿标签，返回清理后的文本和停顿毫秒数
    /// - Parameter text: 原始文本
    /// - Returns: (cleanText: 清理后的文本, pauseMs: 停顿毫秒数，如果无标签则为 nil)
    static func extractPauseTag(from text: String) -> (cleanText: String, pauseMs: Int?) {
        var cleanText = text
        var pauseMs: Int? = nil

        // 1. 先匹配精确标签 [停顿XXXms] 或 [停顿 XXXms]
        // 使用更稳定的正则提取数字
        let msPattern = #"\[停顿\s*(\d+)ms\]"#
        if let regex = try? NSRegularExpression(pattern: msPattern, options: []),
           let match = regex.firstMatch(in: cleanText, options: [], range: NSRange(cleanText.startIndex..., in: cleanText)) {
            // 提取数字组
            if let numberRange = Range(match.range(at: 1), in: cleanText),
               let msValue = Int(cleanText[numberRange]) {
                // 限制范围：0-3000ms
                pauseMs = max(0, min(msValue, PauseConfig.Max.manualPause))
            }
            // 删除整个匹配的标签
            if let fullRange = Range(match.range(at: 0), in: cleanText) {
                cleanText = cleanText.replacingCharacters(in: fullRange, with: "")
            }
        } else {
            // 2. 再匹配预设标签
            for (pattern, value) in tagPatterns {
                if let range = cleanText.range(of: pattern) {
                    pauseMs = value
                    cleanText = cleanText.replacingCharacters(in: range, with: "")
                    break
                }
            }
        }

        return (cleanText.trimmingCharacters(in: .whitespaces), pauseMs)
    }

    /// 清理文本中所有停顿标签，返回干净文本
    /// - Parameter text: 原始文本
    /// - Returns: 清理后的文本
    static func cleanAllPauseTags(from text: String) -> String {
        var cleanText = text

        // 清理精确标签 [停顿XXXms] 或 [停顿 XXXms]
        cleanText = cleanText.replacingOccurrences(
            of: #"\[停顿\s*\d+ms\]"#,
            with: "",
            options: .regularExpression
        )

        // 清理预设标签
        for (pattern, _) in tagPatterns {
            cleanText = cleanText.replacingOccurrences(of: pattern, with: "")
        }

        return cleanText.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - 停顿计算器

enum PauseCalculator {
    /// 计算段落之间的停顿时间
    /// - Parameters:
    ///   - prevSegment: 前一段（可选）
    ///   - currentSegment: 当前段
    /// - Returns: 停顿毫秒数，如果第一段则返回 nil
    static func calculatePause(prevSegment: ScriptSegment?, currentSegment: ScriptSegment) -> Int? {
        // 第一段返回 nil
        guard let prev = prevSegment else {
            return nil
        }

        // 1. 优先使用前一段末尾的手动停顿标签
        let (cleanText, manualPauseMs) = PauseTagProcessor.extractPauseTag(from: prev.text)
        if let manualMs = manualPauseMs {
            return min(manualMs, PauseConfig.Max.manualPause)
        }

        // 2. 计算自动停顿：根据角色关系
        let prevRoleId = prev.roleName
        let currRoleId = currentSegment.roleName

        // 辅助函数：判断是否为旁白角色
        func isNarrator(_ roleName: String) -> Bool {
            let lower = roleName.lowercased()
            return lower == "旁白" || lower == "narrator" || roleName.isEmpty
        }

        var basePauseMs: Int
        if prevRoleId == currRoleId {
            // 同一角色
            basePauseMs = PauseConfig.AutoPause.sameRole
        } else if isNarrator(prevRoleId) {
            // 旁白 -> 角色
            basePauseMs = PauseConfig.AutoPause.narratorToRole
        } else if isNarrator(currRoleId) {
            // 角色 -> 旁白
            basePauseMs = PauseConfig.AutoPause.roleToNarrator
        } else {
            // 不同角色切换
            basePauseMs = PauseConfig.AutoPause.differentRole
        }

        // 3. 结尾标点微调（支持中英文标点）
        let trimmedText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let lastChar = trimmedText.last {
            switch lastChar {
            case "?", "？":
                basePauseMs += PauseConfig.Punctuation.questionMark
            case "!", "！":
                basePauseMs += PauseConfig.Punctuation.exclamationMark
            default:
                // 检查省略号：…、……、...
                if trimmedText.hasSuffix("…") || trimmedText.hasSuffix("……") || trimmedText.hasSuffix("...") {
                    basePauseMs += PauseConfig.Punctuation.ellipsis
                }
            }
        }

        // 4. 应用上限
        return min(basePauseMs, PauseConfig.Max.autoPause)
    }
}