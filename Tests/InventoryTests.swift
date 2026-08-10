import Testing
import SwiftData
import Foundation
@testable import WhereAreYou

/// 容器盤點頁的列表組成、每一列的狀態與副標、標頭行。語意定義在 `docs/SPEC.md` §4.2a–§4.2d。
@MainActor
struct InventoryTests {

    struct World {
        let context: ModelContext
        let hikingBag: Node
        let headlamp: Node
        let bottle: Node
        let raincoat: Node
        let cable: Node
        let pouch: Node
        let pen: Node
        let balcony: Node
        let drawer: Node
        let safe: Node

        /// 這一頁會顯示到的所有節點 —— 子樹加上缺件。標頭行的日期取的就是這一組的最新值。
        var displayedInHikingBag: [Node] { hikingBag.subtree + [raincoat] }
    }

    /// ```
    /// 登山包
    ///  ├ 頭燈        home = 登山包      → 在
    ///  ├ 水壺        home = nil        → 在
    ///  ├ 充電線      home = 書房抽屜    → 外來
    ///  └ 筆袋        home = 登山包      → 在
    ///     └ 鉛筆     home = 筆袋        → 在（但不列在登山包這一層）
    /// 陽台
    ///  └ 雨衣        home = 登山包      → 登山包的缺件
    /// 書房抽屜       充電線歸屬在這，所以它不是空的 —— 充電線是它的缺件
    /// 保險箱         真正空的：沒有子節點，也沒有東西歸屬在它底下
    /// ```
    private func makeWorld() throws -> World {
        let container = try ModelContainer(
            for: Node.self, MoveEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let hikingBag = Node(name: "登山包")
        let balcony = Node(name: "陽台")
        let drawer = Node(name: "書房抽屜")
        let safe = Node(name: "保險箱")

        let headlamp = Node(name: "頭燈", parent: hikingBag, home: hikingBag)
        let bottle = Node(name: "水壺", parent: hikingBag)
        let cable = Node(name: "充電線", parent: hikingBag, home: drawer)
        let pouch = Node(name: "筆袋", parent: hikingBag, home: hikingBag)
        let pen = Node(name: "鉛筆", parent: pouch, home: pouch)
        let raincoat = Node(name: "雨衣", parent: balcony, home: hikingBag)

        for node in [hikingBag, balcony, drawer, safe, headlamp, bottle, cable, pouch, pen, raincoat] {
            context.insert(node)
        }
        return World(context: context, hikingBag: hikingBag, headlamp: headlamp, bottle: bottle,
                     raincoat: raincoat, cable: cable, pouch: pouch, pen: pen,
                     balcony: balcony, drawer: drawer, safe: safe)
    }

    // MARK: - 列表組成（§4.2a）

    @Test("列表包含所有直接子節點")
    func rowsIncludeEveryDirectChild() throws {
        let world = try makeWorld()
        let names = world.hikingBag.inventoryRows.map(\.node.name)
        for expected in ["頭燈", "水壺", "充電線", "筆袋"] {
            #expect(names.contains(expected))
        }
    }

    @Test("列表包含缺件，即使它已經不在這個容器裡")
    func rowsIncludeMissingItemsThatHaveLeft() throws {
        let world = try makeWorld()
        let names = world.hikingBag.inventoryRows.map(\.node.name)
        #expect(names.contains("雨衣"))
    }

    @Test("列表不遞迴展開孫節點")
    func rowsDoNotFlattenGrandchildren() throws {
        let world = try makeWorld()
        let names = world.hikingBag.inventoryRows.map(\.node.name)
        #expect(!names.contains("鉛筆"), "鉛筆要在筆袋自己的盤點頁上出現，不是攤平到登山包這一層")
    }

    @Test("列表依名稱排序，不依狀態分組")
    func rowsAreSortedByName() throws {
        let world = try makeWorld()
        let names = world.hikingBag.inventoryRows.map(\.node.name)
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    @Test("空容器沒有任何列")
    func emptyContainerHasNoRows() throws {
        let world = try makeWorld()
        #expect(world.safe.inventoryRows.isEmpty)
    }

    @Test("沒有子節點但有缺件的容器不算空")
    func containerWithOnlyMissingItemsIsNotEmpty() throws {
        let world = try makeWorld()
        #expect(world.drawer.childNodes.isEmpty)
        let rows = world.drawer.inventoryRows
        #expect(rows.map(\.node.name) == ["充電線"], "充電線歸屬在書房抽屜卻在登山包裡，正是抽屜缺的那件")
        #expect(rows.first?.status == .missing)
    }

    // MARK: - 狀態與副標（§4.2b）

    @Test("歸屬正確的子節點是「在」，而且沒有副標")
    func childHomedHereIsPresentWithoutSubtitle() throws {
        let world = try makeWorld()
        let row = try #require(world.hikingBag.inventoryRows.first { $0.node === world.headlamp })
        #expect(row.status == .present)
        #expect(row.subtitle == nil)
    }

    @Test("沒有歸屬地的子節點是「在」，不是另外一種狀態")
    func childWithoutHomeIsPresent() throws {
        let world = try makeWorld()
        let row = try #require(world.hikingBag.inventoryRows.first { $0.node === world.bottle })
        #expect(row.status == .present)
        #expect(row.subtitle == nil)
    }

    @Test("歸屬在子樹裡更深一層也算「在」")
    func childHomedDeeperInTheSubtreeIsPresent() throws {
        let world = try makeWorld()
        world.headlamp.home = world.pouch
        let row = try #require(world.hikingBag.inventoryRows.first { $0.node === world.headlamp })
        #expect(row.status == .present, "東西從筆袋滑到包底仍然被帶出門了，不該報警")
    }

    @Test("歸屬在別處的子節點是「外來」，副標寫它該回哪")
    func childHomedElsewhereIsForeign() throws {
        let world = try makeWorld()
        let row = try #require(world.hikingBag.inventoryRows.first { $0.node === world.cable })
        #expect(row.status == .foreign)
        #expect(row.subtitle == "歸屬在書房抽屜")
    }

    @Test("缺件的副標寫它目前跑去哪了")
    func missingRowSubtitleSaysWhereItActuallyIs() throws {
        let world = try makeWorld()
        let row = try #require(world.hikingBag.inventoryRows.first { $0.node === world.raincoat })
        #expect(row.status == .missing)
        #expect(row.subtitle == "在陽台")
    }

    @Test("缺件在頂層時，副標寫「不在任何容器裡」")
    func missingRowAtTopLevelSaysSo() throws {
        let world = try makeWorld()
        world.raincoat.parent = nil
        let row = try #require(world.hikingBag.inventoryRows.first { $0.node === world.raincoat })
        #expect(row.status == .missing)
        #expect(row.subtitle == "不在任何容器裡")
    }

    // MARK: - 標頭行（§4.2d）

    @Test("件數是遞迴的，缺件數另外算")
    func summaryCountsAreRecursive() throws {
        let world = try makeWorld()
        let summary = world.hikingBag.inventorySummary
        #expect(summary.count == 5, "頭燈、水壺、充電線、筆袋、鉛筆")
        #expect(summary.missingCount == 1, "雨衣")
    }

    @Test("標頭行寫出件數、缺件數與最後更新日期")
    func summaryTextSpellsOutEverything() throws {
        let world = try makeWorld()
        world.displayedInHikingBag.forEach { $0.updatedAt = Self.date(2026, 8, 9) }
        #expect(world.hikingBag.inventorySummary.text == "5 件 · 缺 1 · 8 月 9 日更新")
    }

    @Test("沒有缺件時，「缺 0」整段不出現")
    func summaryOmitsTheMissingSegmentWhenThereIsNone() throws {
        let world = try makeWorld()
        world.raincoat.home = nil
        world.displayedInHikingBag.forEach { $0.updatedAt = Self.date(2026, 8, 9) }
        #expect(world.hikingBag.inventorySummary.text == "5 件 · 8 月 9 日更新")
    }

    @Test("日期取整棵子樹裡最新的那一筆")
    func summaryDateIsTheNewestInTheSubtree() throws {
        let world = try makeWorld()
        world.displayedInHikingBag.forEach { $0.updatedAt = Self.date(2026, 3, 1) }
        world.pen.updatedAt = Self.date(2026, 8, 9)
        #expect(world.hikingBag.inventorySummary.lastUpdated == Self.date(2026, 8, 9))
        #expect(world.hikingBag.inventorySummary.text == "5 件 · 缺 1 · 8 月 9 日更新")
    }

    @Test("缺件動過也算子樹動過 —— 它是這一頁的一部分")
    func summaryDateIncludesMissingItems() throws {
        let world = try makeWorld()
        world.displayedInHikingBag.forEach { $0.updatedAt = Self.date(2026, 3, 1) }
        world.raincoat.updatedAt = Self.date(2026, 8, 9)
        #expect(world.hikingBag.inventorySummary.lastUpdated == Self.date(2026, 8, 9))
    }

    // MARK: - 跨持久化邊界（CLAUDE.md 的硬規則）

    @Test("刪掉一個列出的節點並存檔後，盤點頁不會再列出它，也不會炸")
    func rowsSurviveDeletingOneOfTheirNodes() throws {
        let world = try makeWorld()
        try world.context.save()

        try world.cable.delete(in: world.context)
        try world.context.save()

        let bag = try #require(
            try world.context.fetch(FetchDescriptor<Node>()).first { $0.name == "登山包" }
        )
        let names = bag.inventoryRows.map(\.node.name)
        #expect(!names.contains("充電線"))
        #expect(names.contains("頭燈"))
    }

    @Test("缺件的所在容器被刪掉並存檔後，副標改口說它不在任何容器裡")
    func missingSubtitleFallsBackWhenItsContainerIsDeleted() throws {
        let world = try makeWorld()
        try world.context.save()

        try world.balcony.delete(in: world.context)
        try world.context.save()

        let bag = try #require(
            try world.context.fetch(FetchDescriptor<Node>()).first { $0.name == "登山包" }
        )
        let row = try #require(bag.inventoryRows.first { $0.node.name == "雨衣" })
        #expect(row.status == .missing)
        #expect(row.subtitle == "不在任何容器裡")
    }

    // MARK: -

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
