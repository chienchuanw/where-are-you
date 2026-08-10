#if DEBUG
import Foundation
import SwiftData

/// DEBUG 專用的種子資料。
///
/// 新增流程（Figma `Item — Add`）還沒實作，所以 app 跑起來會是空的，沒有東西可以拿去跟
/// Figma frame 逐項對照。這份資料照 `Screens — Light / Home` 與 `Container — Inventory`
/// 的 mock 內容建，讓截圖對照有意義。
///
/// 只在資料庫是空的時候寫入，所以不會蓋掉手動建的資料。Release 版整支不編譯。
enum SampleData {

    static func seedIfEmpty(_ context: ModelContext) {
        guard !DebugLaunch.wantsEmptyStore else { return }
        guard (try? context.fetchCount(FetchDescriptor<Node>())) == 0 else { return }
        seed(context)
        try? context.save()
    }

    private static func seed(_ context: ModelContext) {
        func node(_ name: String, in parent: Node? = nil, home: Node? = nil, pinned: Bool = false) -> Node {
            let node = Node(name: name, parent: parent, home: home ?? parent, isPinned: pinned)
            context.insert(node)
            return node
        }

        // 地點
        let house = node("家")
        let study = node("書房")
        let office = node("公司")
        let car = node("車")

        // 登山包：Figma `Container — Inventory` 的那一支，5 件 · 缺 1
        let hikingBag = node("登山包", pinned: true)
        _ = node("頭燈", in: hikingBag)
        // 沒有歸屬地的東西永遠不算缺、也不算外來 —— 在 UI 上就是「在」。
        let bottle = node("水壺", in: hikingBag)
        bottle.home = nil
        let firstAid = node("急救包", in: hikingBag)
        _ = node("繃帶", in: firstAid)

        let drawer = node("書房抽屜", in: study)
        // 人在登山包裡、歸屬在書房抽屜 → 登山包的外來件
        _ = node("充電線", in: hikingBag, home: drawer)

        let balcony = node("陽台", in: house)
        // 歸屬在登山包、人在陽台 → 登山包的缺件
        _ = node("雨衣", in: balcony, home: hikingBag)

        // 上班包：Figma 首頁的第二列，6 件 · 缺 1
        let workBag = node("上班包", in: house, pinned: true)
        for name in ["筆電", "滑鼠", "悠遊卡", "耳機"] { _ = node(name, in: workBag) }
        let pouch = node("筆袋", in: workBag)
        _ = node("鉛筆", in: pouch)

        let entrance = node("玄關", in: house)
        _ = node("鑰匙", in: entrance, home: workBag)

        // 家的其餘部分
        let living = node("客廳", in: house)
        for name in ["遙控器", "電視盒", "拖鞋"] { _ = node(name, in: living) }
        let kitchen = node("廚房", in: house)
        for name in ["咖啡機", "電子秤"] { _ = node(name, in: kitchen) }
        let bedroom = node("臥室", in: house)
        for name in ["檯燈", "眼罩", "充電器"] { _ = node(name, in: bedroom) }

        // 書房
        for name in ["電池", "便利貼", "迴紋針", "印泥"] { _ = node(name, in: drawer) }
        let shelf = node("書櫃", in: study)
        for name in ["護照", "印章", "保單", "相簿"] { _ = node(name, in: shelf) }
        let deskBox = node("桌上收納", in: study)
        for name in ["隨身碟", "讀卡機", "轉接頭"] { _ = node(name, in: deskBox) }
        let cameraBag = node("相機包", in: study)
        for name in ["相機", "鏡頭", "電池充電器"] { _ = node(name, in: cameraBag) }

        for name in ["螢幕", "鍵盤", "外接硬碟", "傘", "室內鞋"] { _ = node(name, in: office) }
        for name in ["行照", "雨傘", "面紙", "手機架", "充電座"] { _ = node(name, in: car) }
    }
}
#endif
