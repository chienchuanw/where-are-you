#if DEBUG
import Foundation

/// DEBUG 專用的啟動參數。
///
/// 畫面不寫 XCUITest（`CLAUDE.md` §3），驗收方式是「跑起來截圖，與 Figma frame 逐項對照」。
/// 少了這些參數，空狀態與搜尋無結果就得靠人手點到那個狀態，截圖步驟也就不可重現。
/// Release 版整支不編譯。
///
/// 裝置**指名，不要用 `booted`** —— 兩台基準機（`CLAUDE.md` 的「完成的定義」）同時開著時，
/// `booted` 會自己挑一台，挑到 SE 就是拿 375×667 的截圖去對 393×852 的 frame。
/// 代價是指名不像 `booted` 保證那台在跑，所以先確認它開著。
///
/// `--terminate-running-process` 不可省：app 已經在跑的話，`launch` 只會把它叫到前景，
/// 下面這些參數整組被忽略，截到的是上一次留下的畫面。
///
/// `D` 換成 `"iPhone SE (3rd generation)"` 就是 `CLAUDE.md` 那道矮機身關卡要用的。
/// 名稱在這裡與 `CLAUDE.md` 各寫一份，換基準機時兩邊要一起改。
///
/// ```
/// D="iPhone 16"; L=(xcrun simctl launch --terminate-running-process "$D" com.chienchuanw.whereareyou)
///
/// "${L[@]}" -empty-store
/// "${L[@]}" -search 腳架
/// "${L[@]}" -open-container 登山包
/// "${L[@]}" -open-container 登山包 -move 頭燈
/// "${L[@]}" -open-container 登山包 -move 頭燈 -sheet-search 腳架
/// "${L[@]}" -open-container 登山包 -add-item
/// ```
enum DebugLaunch {
    /// 不寫入種子資料，用來看 `Home — Empty`。
    static var wantsEmptyStore: Bool { flag("-empty-store") }

    /// 啟動就推進某個容器的盤點頁。
    static var containerToOpen: String? { value(for: "-open-container") }

    /// 啟動就把搜尋列填好。
    static var initialSearch: String? { value(for: "-search") }

    /// 啟動就在盤點頁上彈出某一件東西的「它在哪？」sheet。
    ///
    /// sheet 只有點狀態記號才會開，而 `simctl` 沒有辦法送出點擊 —— 少了這個參數，
    /// 這一支畫面的截圖就是不可重現的。要與 `-open-container` 一起用。
    static var itemToMove: String? { value(for: "-move") }

    /// 啟動就把 sheet 的搜尋列填好，用來看 `Container — Where is it? — No Results`。
    /// 要與 `-move` 一起用。
    static var initialSheetSearch: String? { value(for: "-sheet-search") }

    /// 啟動就從某個容器推進新增物件那一頁。要與 `-open-container` 一起用。
    static var wantsAddItem: Bool { flag("-add-item") }

    /// 啟動就推進某個東西的詳細頁。要與 `-open-container` 一起用 ——
    /// 詳細頁是從盤點頁的列推進去的（`docs/SPEC.md` §4.4c）。
    static var itemToOpen: String? { value(for: "-open-item") }

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
