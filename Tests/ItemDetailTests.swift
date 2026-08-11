import Testing
import SwiftData
import Foundation
@testable import WhereAreYou

/// 物件詳細頁：三個欄位、進盤點頁那一列、以及移動歷史時間軸。
/// 語意定義在 `docs/SPEC.md` §4.4–§4.4e。
@MainActor
struct ItemDetailTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Node.self, MoveEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// 2026-08-09 20:20 之類的固定時刻，避免測試跟著今天跑。
    private func at(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    // MARK: - 上行的四種寫法（§4.4e）

    @Test("一般移動寫成「目的地 ← 來源」")
    func ordinaryMove() throws {
        let context = try makeContext()
        let passport = Node(name: "護照")
        let bag = Node(name: "登山包")
        let drawer = Node(name: "書房抽屜")
        [passport, bag, drawer].forEach(context.insert)
        context.insert(MoveEvent(node: passport, from: bag, to: drawer, at: at(8, 9, 20, 20)))

        #expect(passport.timeline.map(\.title) == ["書房抽屜 ← 登山包"])
    }

    @Test("建檔寫成「建檔於 X」—— fromName 是空字串")
    func creation() throws {
        let context = try makeContext()
        let passport = Node(name: "護照")
        let safe = Node(name: "保險箱")
        [passport, safe].forEach(context.insert)
        context.insert(MoveEvent(node: passport, from: nil, to: safe, at: at(6, 1, 11, 3)))

        #expect(passport.timeline.map(\.title) == ["建檔於保險箱"])
    }

    @Test("移到頂層仍然用箭頭，左邊是「不在任何容器裡」")
    func movedToTopLevel() throws {
        let context = try makeContext()
        let raincoat = Node(name: "雨衣")
        let bag = Node(name: "登山包")
        [raincoat, bag].forEach(context.insert)
        context.insert(MoveEvent(node: raincoat, from: bag, to: nil, at: at(8, 9, 20, 20)))

        #expect(raincoat.timeline.map(\.title) == ["不在任何容器裡 ← 登山包"])
    }

    @Test("建檔在頂層時兩邊都是空字串")
    func createdAtTopLevel() throws {
        let context = try makeContext()
        let home = Node(name: "家")
        context.insert(home)
        context.insert(MoveEvent(node: home, from: nil, to: nil, at: at(5, 3, 21, 7)))

        #expect(home.timeline.map(\.title) == ["建檔，不在任何容器裡"])
    }

    // MARK: - 下行

    @Test("下行是「M 月 d 日 HH:mm」，有地名才接「 · 地名」")
    func metaLine() throws {
        let context = try makeContext()
        let passport = Node(name: "護照")
        let safe = Node(name: "保險箱")
        let drawer = Node(name: "書房抽屜")
        [passport, safe, drawer].forEach(context.insert)
        context.insert(MoveEvent(node: passport, from: safe, to: drawer,
                                 at: at(8, 9, 20, 20), placemark: "信義區"))
        context.insert(MoveEvent(node: passport, from: nil, to: safe, at: at(6, 1, 11, 3)))

        #expect(passport.timeline.map(\.meta) == ["8 月 9 日 20:20 · 信義區", "6 月 1 日 11:03"])
    }

    @Test("個位數的分鐘要補零，不能寫成 20:2")
    func metaPadsMinutes() throws {
        let context = try makeContext()
        let passport = Node(name: "護照")
        context.insert(passport)
        context.insert(MoveEvent(node: passport, from: nil, to: nil, at: at(8, 9, 9, 5)))

        #expect(passport.timeline.map(\.meta) == ["8 月 9 日 09:05"])
    }

    // MARK: - 排序與強調色

    @Test("依 at 由新到舊")
    func newestFirst() throws {
        let context = try makeContext()
        let passport = Node(name: "護照")
        let a = Node(name: "甲"), b = Node(name: "乙"), c = Node(name: "丙")
        [passport, a, b, c].forEach(context.insert)
        context.insert(MoveEvent(node: passport, from: nil, to: a, at: at(6, 1, 11, 3)))
        context.insert(MoveEvent(node: passport, from: a, to: b, at: at(7, 22, 9, 14)))
        context.insert(MoveEvent(node: passport, from: b, to: c, at: at(8, 9, 20, 20)))

        #expect(passport.timeline.map(\.title) == ["丙 ← 乙", "乙 ← 甲", "建檔於甲"])
    }

    @Test("只有最新的那一筆是 current")
    func onlyNewestIsCurrent() throws {
        let context = try makeContext()
        let passport = Node(name: "護照")
        let a = Node(name: "甲"), b = Node(name: "乙")
        [passport, a, b].forEach(context.insert)
        context.insert(MoveEvent(node: passport, from: nil, to: a, at: at(6, 1, 11, 3)))
        context.insert(MoveEvent(node: passport, from: a, to: b, at: at(8, 9, 20, 20)))

        #expect(passport.timeline.map(\.isCurrent) == [true, false])
    }

    /// `at` 相同時若沒有第二鍵，順序就是 `moveEvents` 關聯陣列碰巧給的順序 ——
    /// 同一頁兩次開啟可能列出不同結果，那看起來就像資料自己在變。
    ///
    /// 這裡**不能**用「連續呼叫兩次結果相同」來驗：同一個陣列排兩次本來就會一樣，
    /// 那種測試在拿掉第二鍵之後照樣是綠的（實際驗證過）。要驗的是排序真的由 `id` 決定，
    /// 所以直接斷言結果的 `id` 遞增。
    ///
    /// 用 8 筆是為了讓「碰巧就是遞增」的機率降到 1/8!（約四萬分之一）——
    /// `id` 是隨機 UUID，筆數太少的話這個測試會變成偶爾漏抓的擲骰子。
    @Test("at 相同時改用 id 當第二鍵，順序才是決定性的")
    func stableOrderOnEqualTimestamps() throws {
        let context = try makeContext()
        let passport = Node(name: "護照")
        context.insert(passport)
        let same = at(8, 9, 20, 20)
        for i in 0..<8 {
            let box = Node(name: "容器\(i)")
            context.insert(box)
            context.insert(MoveEvent(node: passport, from: nil, to: box, at: same))
        }

        let ids = passport.timeline.map(\.id.uuidString)
        #expect(ids.count == 8)
        #expect(ids == ids.sorted())
    }

    @Test("歷史是空的時候回傳空陣列，不是崩潰")
    func emptyTimeline() throws {
        let context = try makeContext()
        let orphan = Node(name: "沒有歷史的東西")
        context.insert(orphan)

        #expect(orphan.timeline.isEmpty)
    }

    // MARK: - 快照，不是關聯（§2.2）

    @Test("容器改名之後，舊的歷史條目繼續顯示舊名稱")
    func snapshotsDoNotFollowRenames() throws {
        let context = try makeContext()
        let passport = Node(name: "護照")
        let bag = Node(name: "登山包")
        [passport, bag].forEach(context.insert)
        context.insert(MoveEvent(node: passport, from: nil, to: bag, at: at(6, 1, 11, 3)))

        bag.name = "登山背包"

        #expect(passport.timeline.map(\.title) == ["建檔於登山包"])
    }

    // MARK: - 三個欄位（§4.4d）

    @Test("目前位置取 parent 的名稱，頂層寫「不在任何容器裡」")
    func currentLocationText() throws {
        let context = try makeContext()
        let drawer = Node(name: "書房抽屜")
        let passport = Node(name: "護照", parent: drawer)
        let loose = Node(name: "雨衣")
        [drawer, passport, loose].forEach(context.insert)

        #expect(passport.currentLocationText == "書房抽屜")
        #expect(loose.currentLocationText == "不在任何容器裡")
    }

    @Test("歸屬地沒設定時寫「未設定」，那一列仍然要在")
    func homeText() throws {
        let context = try makeContext()
        let drawer = Node(name: "書房抽屜")
        let passport = Node(name: "護照", home: drawer)
        let bottle = Node(name: "水壺")
        [drawer, passport, bottle].forEach(context.insert)

        #expect(passport.homeText == "書房抽屜")
        #expect(bottle.homeText == "未設定")
    }

    @Test("備註是空的或只有空白時整列不出現")
    func noteText() throws {
        let context = try makeContext()
        let a = Node(name: "護照", note: "效期 2031 / 04")
        let b = Node(name: "水壺")
        let c = Node(name: "雨衣", note: "   ")
        [a, b, c].forEach(context.insert)

        #expect(a.noteText == "效期 2031 / 04")
        #expect(b.noteText == nil)
        #expect(c.noteText == nil)
    }

    // MARK: - 進盤點頁那一列（§4.4c）

    @Test("「裡面有 N 件」的 N 是遞迴件數，孫節點也要算")
    func inventoryLink() throws {
        let context = try makeContext()
        let bag = Node(name: "登山包")
        let pouch = Node(name: "筆袋", parent: bag)
        let pen = Node(name: "鉛筆", parent: pouch)
        let passport = Node(name: "護照")
        [bag, pouch, pen, passport].forEach(context.insert)

        // 筆袋 + 鉛筆 = 2，孫節點也要算進去（§3.1）
        #expect(bag.inventoryLinkText == "裡面有 2 件")
        #expect(pouch.inventoryLinkText == "裡面有 1 件")
        #expect(passport.inventoryLinkText == "裡面有 0 件")
    }

    /// 出現的條件是「盤點頁列得出東西」，不是「有子節點」。用後者當條件的話，
    /// 一個被搬空的包就再也進不去自己的盤點頁 —— 而那正是使用者要把東西一件件
    /// 標回來的地方。見 §4.4c。
    @Test("被搬空但還有缺件的容器，仍然進得去自己的盤點頁")
    func inventoryLinkForEmptiedContainerWithMissingItems() throws {
        let context = try makeContext()
        let study = Node(name: "書房")
        let cameraBag = Node(name: "相機包", parent: study)
        // 兩件東西歸屬在相機包，但人都在書房 —— 相機包自己是空的
        let camera = Node(name: "相機", parent: study, home: cameraBag)
        let lens = Node(name: "鏡頭", parent: study, home: cameraBag)
        [study, cameraBag, camera, lens].forEach(context.insert)

        #expect(cameraBag.childNodes.isEmpty)
        #expect(cameraBag.subtreeCount == 0)
        // 盤點頁列得出兩列缺件，所以那一列要在；件數是真的 0
        #expect(cameraBag.inventoryRows.count == 2)
        #expect(cameraBag.inventoryLinkText == "裡面有 0 件")
    }

    /// 剛建好的空容器兩邊都是空的。**那一列仍然要在** —— 它的盤點頁正是把第一件東西
    /// 放進去的入口（§4.2d 的「加入第一件」），設任何條件都會讓那一頁到不了。
    @Test("剛建好、什麼都沒有的容器也有那一列")
    func inventoryLinkForBrandNewEmptyContainer() throws {
        let context = try makeContext()
        let pouch = Node(name: "筆袋")
        context.insert(pouch)

        #expect(pouch.inventoryRows.isEmpty)
        #expect(pouch.inventoryLinkText == "裡面有 0 件")
    }
}

/// 跨持久化邊界的詳細頁測試 —— `save()` 之後重新 fetch 再斷言。
/// 只在記憶體裡操作 `ModelContext` 而不存檔，等於沒有測到 SwiftData（`CLAUDE.md` §3）。
@MainActor
struct ItemDetailPersistenceTests {

    @Test("容器被刪除並存檔後，時間軸仍讀得出當時的名稱")
    func timelineSurvivesContainerDeletion() throws {
        let container = try ModelContainer(
            for: Node.self, MoveEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let bag = Node(name: "登山包")
        let drawer = Node(name: "書房抽屜")
        let passport = Node(name: "護照", parent: drawer)
        [bag, drawer, passport].forEach(context.insert)
        context.insert(MoveEvent(node: passport, from: bag, to: drawer, at: Date()))
        try context.save()

        try bag.delete(in: context)
        try context.save()

        // 重新 fetch，確保讀的是磁碟上的狀態而不是記憶體裡的殘影
        // （`first {}` 直接寫進 `#expect` 會弄丟 rethrows 推導，所以先算成區域變數）
        let all = try context.fetch(FetchDescriptor<Node>())
        let reloaded = all.first { $0.name == "護照" }
        let titles = try #require(reloaded).timeline.map(\.title)

        // 關聯已經被 nullify，但快照撐住了整行
        #expect(titles == ["書房抽屜 ← 登山包"])
    }
}
