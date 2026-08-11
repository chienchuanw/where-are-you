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
///
/// **已知落差：這裡的節點是直接建出來的，沒有走 §4.5c 的建檔流程，所以絕大多數沒有
/// `MoveEvent`。** 真正的 app 裡每個節點都會有一筆建檔紀錄，這裡只有五個有 ——
/// 於是詳細頁在大部分節點上會顯示「還沒有任何紀錄」，而 §4.4e 把那句話定義成
/// 「寫入路徑漏了」的異常訊號。在種子資料上它不是異常，是這份資料的捷徑。
///
/// 補法不是在這裡補一筆建檔事件了事：那會讓「最近用過的容器」（§4.3a 只取最新三個）
/// 被幾十筆同一時刻的建檔事件灌爆，而那一組有自己的 frame 要對照。要做就得讓每一筆
/// 建檔事件有各自的時間、並重新驗收「它在哪？」那支畫面 —— 那是它自己的一件事。
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
        for name in ["印章", "保單", "相簿"] { _ = node(name, in: shelf) }

        // 護照是 Figma `Item — Detail` 的那一支：有備註、有一段走過三個地方的歷史。
        // 少了它，詳細頁沒有任何一筆資料可以拿來與 frame 對照。
        let safe = node("保險箱", in: study)
        let passport = node("護照", in: drawer)
        passport.note = "效期 2031 / 04"
        let deskBox = node("桌上收納", in: study)
        for name in ["隨身碟", "讀卡機", "轉接頭"] { _ = node(name, in: deskBox) }
        let cameraBag = node("相機包", in: study)
        for name in ["相機", "鏡頭", "電池充電器"] { _ = node(name, in: cameraBag) }

        for name in ["螢幕", "鍵盤", "外接硬碟", "傘", "室內鞋"] { _ = node(name, in: office) }
        for name in ["行照", "雨傘", "面紙", "手機架", "充電座"] { _ = node(name, in: car) }

        seedHistory(context, raincoat: balcony, drawer: drawer, hikingBag: hikingBag)
        seedDetailHistory(context, passport: passport, safe: safe,
                          hikingBag: hikingBag, drawer: drawer)
    }

    /// 詳細頁（SPEC §4.4）要對照的兩支 frame 各需要一段歷史。
    ///
    /// **這一段有三個限制，少守一個就會弄壞別支畫面的驗收：**
    ///
    /// 1. **月日要與 SPEC §4.4 的範例一字不差**，否則詳細頁的截圖對不上它自己的 frame
    /// 2. **年份用去年**，讓這幾筆比 `seedHistory` 那三筆舊。「最近用過」只取最新三個（§4.3a）
    /// 3. **舊還不夠，`to` 不能是新的容器。** 上限是在排除之後才套用的（§4.3a 講得很明白），
    ///    所以舊事件不會被擠掉，而是往後遞補。這裡三筆的目的地分別是保險箱（寫完就刪掉）、
    ///    登山包與書房抽屜（本來就已經在那一組裡，去重之後名次不動），所以那一組不會多一列
    private static func seedDetailHistory(
        _ context: ModelContext, passport: Node, safe: Node, hikingBag: Node, drawer: Node
    ) {
        func at(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
            var c = DateComponents()
            c.year = Calendar.current.component(.year, from: Date()) - 1
            c.month = month; c.day = day; c.hour = hour; c.minute = minute
            return Calendar.current.date(from: c) ?? Date()
        }

        // 護照走過的路：建檔在保險箱 → 帶去登山包 → 收進書房抽屜（它現在的位置）
        context.insert(MoveEvent(node: passport, from: nil, to: safe,
                                 at: at(6, 1, 11, 3)))
        context.insert(MoveEvent(node: passport, from: safe, to: hikingBag,
                                 at: at(7, 22, 9, 14), placemark: "大安區"))
        context.insert(MoveEvent(node: passport, from: hikingBag, to: drawer,
                                 at: at(8, 9, 20, 20), placemark: "信義區"))

        // 登山包自己也有檔案 —— 這是 `Item — Detail — Container` 那一支。
        // 它是頂層節點，所以 `to` 是 nil：時間軸讀作「建檔，不在任何容器裡」，
        // 而 `to` 為 nil 的事件不會進「最近用過」那一組（那一組取的就是 `to`）。
        context.insert(MoveEvent(node: hikingBag, from: nil, to: nil, at: at(4, 18, 8, 5)))

        // **保險箱寫完歷史就刪掉。** 兩個理由，都是為了不弄壞別的畫面：
        // 多一個節點會把書房從 18 件推成 19 件（§4.1 與 Home frame 都釘死 18）；
        // 而它留著就會遞補進「最近用過」的第三格。
        //
        // 刪掉之後歷史照樣讀得出「保險箱」—— 那正是 §2.2 存名稱快照的理由，
        // 這幾筆順便把那個行為在實機上演一次。
        context.delete(safe)
    }

    /// 「它在哪？」sheet 的第一組選項讀的是 `MoveEvent`（見 SPEC §4.4b）。上面那棵樹是
    /// 直接建出來的、沒有經過任何一次移動，所以那一組會是空的，跟 Figma frame 對不起來。
    ///
    /// 補的這幾筆不是憑空捏的，而是把樹上已經存在的異常講完整：雨衣的歸屬地是登山包
    /// 卻人在陽台（所以它是缺件），充電線的歸屬地是書房抽屜卻人在登山包（所以它是外來件）。
    /// 沒有這兩筆歷史，那兩個狀態等於憑空發生。
    private static func seedHistory(
        _ context: ModelContext, raincoat balcony: Node, drawer: Node, hikingBag: Node
    ) {
        func find(_ name: String, in parent: Node) -> Node? {
            parent.childNodes.first { $0.name == name }
        }

        let day: TimeInterval = 86_400
        let now = Date()

        if let cable = find("充電線", in: hikingBag) {
            context.insert(MoveEvent(node: cable, from: drawer, to: hikingBag, at: now - 5 * day))
        }
        if let battery = find("電池", in: drawer) {
            context.insert(MoveEvent(node: battery, from: nil, to: drawer, at: now - 3 * day))
        }
        if let raincoat = find("雨衣", in: balcony) {
            context.insert(MoveEvent(node: raincoat, from: hikingBag, to: balcony, at: now - day))
        }
    }
}
#endif
