import Foundation

// 状态数据模型
struct CrackProgressState {
    var currentPassword: String
    var processedCount: Int
    var totalCount: Int
    var speedPerSecond: Int
    var percentage: Double {
        totalCount > 0 ? Double(processedCount) / Double(totalCount) : 0
    }
    var remainingSeconds: Int {
        guard speedPerSecond > 0 else { return 0 }
        let remainingItems = totalCount - processedCount
        return max(0, remainingItems / speedPerSecond)
    }
}

enum CrackOutcome {
    case none
    case success(password: String)
    case exhausted
}

/// 核心跑字典调度引擎：逐行读取字典并驱动握手验证钩子。
/// 手握手验证(verify:)需要外部密码学库(如基于 PBKDF2 的 PMK 推导)实现,
/// 本文件保留接口,具体 KCK/PMK 校验由接入方按实际需求补齐。
final class CrackEngine {
    private(set) var state = CrackProgressState(
        currentPassword: "等待加载字典...",
        processedCount: 0,
        totalCount: 0,
        speedPerSecond: 0
    )

    private var dictionaryLines: [String] = []
    private var index = 0
    private var lastTick = Date()

    var isLoaded: Bool { !dictionaryLines.isEmpty }
    var isExhausted: Bool { index >= dictionaryLines.count }

    func loadDictionary(from url: URL) -> Bool {
        // 兼容多种常见编码: UTF-8 / UTF-16 / GB18030(GBK 超集), 逐种尝试
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.gb_18030_2000.rawValue)
            ))
        ]
        var raw: String?
        for enc in encodings {
            if let text = try? String(contentsOf: url, encoding: enc) {
                raw = text
                break
            }
        }
        guard let text = raw else { return false }

        let rawLines = text
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        // 去重并保持顺序
        var seen = Set<String>()
        let lines = rawLines.filter { seen.insert($0).inserted }
        dictionaryLines = lines

        index = 0
        lastTick = Date()
        state.totalCount = dictionaryLines.count
        state.processedCount = 0
        state.speedPerSecond = 0
        state.currentPassword = dictionaryLines.first ?? "等待加载字典..."
        return !dictionaryLines.isEmpty
    }

    /// 推进一步：返回是否命中
    func progressOneStep(verify: (String) -> Bool) -> CrackOutcome {
        guard index < dictionaryLines.count else { return .exhausted }

        let candidate = dictionaryLines[index]
        index += 1
        state.processedCount = index
        state.currentPassword = candidate
        updateSpeed()

        return verify(candidate) ? .success(password: candidate) : .none
    }

    private func updateSpeed() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTick)
        if elapsed > 0.5 {
            let count = state.processedCount
            state.speedPerSecond = count > 0 && elapsed > 0 ? Int(Double(count) / elapsed) : 0
            lastTick = now
        }
    }
}