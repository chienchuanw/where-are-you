#if DEBUG
import Foundation

/// DEBUG 專用的啟動參數。
///
/// 畫面不寫 XCUITest（`CLAUDE.md` §3），驗收方式是「跑起來截圖，與 Figma frame 逐項對照」。
/// 少了這些參數，空狀態與搜尋無結果就得靠人手點到那個狀態，截圖步驟也就不可重現。
/// Release 版整支不編譯。
///
/// ```
/// xcrun simctl launch booted com.chienchuanw.whereareyou -open-container 登山包
/// xcrun simctl launch booted com.chienchuanw.whereareyou -search 腳架
/// xcrun simctl launch booted com.chienchuanw.whereareyou -empty-store
/// ```
enum DebugLaunch {
    /// 不寫入種子資料，用來看 `Home — Empty`。
    static var wantsEmptyStore: Bool { flag("-empty-store") }

    /// 啟動就推進某個容器的盤點頁。
    static var containerToOpen: String? { value(for: "-open-container") }

    /// 啟動就把搜尋列填好。
    static var initialSearch: String? { value(for: "-search") }

    private static func flag(_ name: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(name)
    }

    private static func value(for name: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: name) else { return nil }
        let next = arguments.index(after: flag)
        guard next < arguments.endIndex else { return nil }
        return arguments[next]
    }
}
#endif
