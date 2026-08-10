import Testing
import SwiftData
import Foundation
@testable import WhereAreYou

/// 這四項運算是 `docs/SPEC.md` §3 點名「最容易寫錯、且錯了會靜默壞資料」的地方。
/// 每一項都先有測試才有實作。
@MainActor
struct TreeQueriesTests {

    // MARK: - 測試用的世界

    /// 建出 SPEC §3.2 拿來當反例的那棵樹：
    ///
    /// ```
    /// 上班包
    ///  ├ 筆袋
    ///  │   └ 鑑子筆   home = 筆袋
    ///  └ 橡皮擦       home = 筆袋   ← 掉出筆袋但還在包裡
    /// 玄關
    ///  └ 門禁卡       home = 上班包 ← 真的沒帶
    /// ```
    struct World {
        let context: ModelContext
        let workBag: Node
        let pencilCase: Node
        let pen: Node
        let eraser: Node
        let hallway: Node
        let keycard: Node
    }

    private func makeWorld() throws -> World {
        let container = try ModelContainer(
            for: Node.self, MoveEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let workBag = Node(name: "上班包")
        let pencilCase = Node(name: "筆袋", parent: workBag)
        let pen = Node(name: "鑑子筆", parent: pencilCase, home: pencilCase)
        let eraser = Node(name: "橡皮擦", parent: workBag, home: pencilCase)
        let hallway = Node(name: "玄關")
        let keycard = Node(name: "門禁卡", parent: hallway, home: workBag)

        for node in [workBag, pencilCase, pen, eraser, hallway, keycard] {
            context.insert(node)
        }
        return World(context: context, workBag: workBag, pencilCase: pencilCase,
                     pen: pen, eraser: eraser, hallway: hallway, keycard: keycard)
    }

    // MARK: - 遞迴計數

    @Test("遞迴計數包含孫節點")
    func subtreeCountIncludesGrandchildren() throws {
        let w = try makeWorld()
        // 上班包底下：筆袋、鑑子筆、橡皮擦
        #expect(w.workBag.subtreeCount == 3)
    }

    @Test("遞迴計數不含自己")
    func subtreeCountExcludesSelf() throws {
        let w = try makeWorld()
        #expect(w.pencilCase.subtreeCount == 1)   // 只有鑑子筆
        #expect(w.pen.subtreeCount == 0)
    }

    // MARK: - 缺件

    @Test("歸屬在此但人已離開整棵子樹，算缺件")
    func itemThatLeftTheSubtreeIsMissing() throws {
        let w = try makeWorld()
        let missing = w.workBag.missingItems
        #expect(missing.map(\.name) == ["門禁卡"])
    }

    @Test("東西掉出子容器但還在包裡，不算缺件")
    func itemStillInsideTheBagIsNotMissing() throws {
        let w = try makeWorld()
        // 橡皮擦 home=筆袋、現在直接躺在上班包裡 —— 東西還在包裡，出門情境不該警示
        #expect(w.workBag.missingItems.contains { $0.name == "橡皮擦" } == false)
    }

    @Test("從子容器的角度看，掉出來的東西才算缺件")
    func theSubContainerStillReportsItMissing() throws {
        let w = try makeWorld()
        #expect(w.pencilCase.missingItems.map(\.name) == ["橡皮擦"])
    }

    @Test("沒有歸屬地的物件永遠不算缺件")
    func itemWithoutHomeIsNeverMissing() throws {
        let w = try makeWorld()
        let stray = Node(name: "隨手撿的石頭", parent: w.hallway)
        w.context.insert(stray)
        #expect(w.workBag.missingItems.contains { $0.name == "隨手撿的石頭" } == false)
        #expect(w.hallway.missingItems.contains { $0.name == "隨手撿的石頭" } == false)
    }

    @Test("缺件數就是缺件清單的長度")
    func missingCountMatchesTheList() throws {
        let w = try makeWorld()
        #expect(w.workBag.missingCount == w.workBag.missingItems.count)
        #expect(w.workBag.missingCount == 1)
    }

    // MARK: - 外來件

    @Test("人在此但歸屬在別處，算外來件")
    func itemHomedElsewhereIsForeign() throws {
        let w = try makeWorld()
        #expect(w.hallway.foreignItems.map(\.name) == ["門禁卡"])
    }

    @Test("沒有歸屬地的物件不算外來件")
    func itemWithoutHomeIsNotForeign() throws {
        let w = try makeWorld()
        let stray = Node(name: "隨手撿的石頭", parent: w.hallway)
        w.context.insert(stray)
        #expect(w.hallway.foreignItems.map(\.name) == ["門禁卡"])
    }

    @Test("歸屬在同一棵子樹內就不算外來件")
    func itemHomedWithinTheSubtreeIsNotForeign() throws {
        let w = try makeWorld()
        // 橡皮擦 home=筆袋，筆袋在上班包底下 —— 對上班包來說不是外來的
        #expect(w.workBag.foreignItems.isEmpty)
    }

    // MARK: - 循環防呆

    @Test("不能把節點移進自己")
    func cannotMoveIntoItself() throws {
        let w = try makeWorld()
        #expect(w.workBag.canMove(to: w.workBag) == false)
        #expect(throws: TreeError.wouldCreateCycle) {
            try w.workBag.move(to: w.workBag, in: w.context)
        }
    }

    @Test("不能把節點移進自己的子孫")
    func cannotMoveIntoItsOwnDescendant() throws {
        let w = try makeWorld()
        #expect(w.workBag.canMove(to: w.pen) == false)
        #expect(throws: TreeError.wouldCreateCycle) {
            try w.workBag.move(to: w.pen, in: w.context)
        }
    }

    @Test("合法的移動要能通過")
    func legitimateMoveIsAllowed() throws {
        let w = try makeWorld()
        #expect(w.keycard.canMove(to: w.workBag))
        try w.keycard.move(to: w.workBag, in: w.context)
        #expect(w.keycard.parent === w.workBag)
        #expect(w.workBag.missingItems.isEmpty)
    }

    @Test("移動到頂層是合法的")
    func movingToRootIsAllowed() throws {
        let w = try makeWorld()
        try w.pencilCase.move(to: nil, in: w.context)
        #expect(w.pencilCase.parent == nil)
        #expect(w.workBag.subtreeCount == 1)   // 只剩橡皮擦
    }

    @Test("一次移動要把兩邊的容器都標記成剛動過")
    func movingTouchesBothContainers() throws {
        let w = try makeWorld()
        let stale = Date(timeIntervalSince1970: 0)
        for node in [w.workBag, w.hallway, w.keycard] { node.updatedAt = stale }

        try w.keycard.move(to: w.workBag, in: w.context)

        // 舊的少一件、新的多一件，兩邊的內容都變了。少了任何一邊，盤點頁的標頭
        // 就會在剛被編輯過的當下顯示舊日期。見 `docs/SPEC.md` §4.2d。
        #expect(w.hallway.updatedAt > stale)
        #expect(w.workBag.updatedAt > stale)
        #expect(w.keycard.updatedAt > stale)
    }

    @Test("移到頂層時只有舊容器要被標記，沒有新容器可以標記")
    func movingToRootTouchesOnlyTheOldContainer() throws {
        let w = try makeWorld()
        let stale = Date(timeIntervalSince1970: 0)
        for node in [w.workBag, w.pencilCase] { node.updatedAt = stale }

        try w.pencilCase.move(to: nil, in: w.context)

        #expect(w.workBag.updatedAt > stale)
        #expect(w.pencilCase.updatedAt > stale)
    }

    // MARK: - 移動歷史

    @Test("每次移動寫一筆歷史，記下從哪到哪")
    func movingRecordsAnEvent() throws {
        let w = try makeWorld()
        try w.keycard.move(to: w.workBag, in: w.context)

        let events = try w.context.fetch(FetchDescriptor<MoveEvent>())
        #expect(events.count == 1)
        #expect(events.first?.node?.name == "門禁卡")
        #expect(events.first?.from?.name == "玄關")
        #expect(events.first?.to?.name == "上班包")
    }

    @Test("被拒絕的移動不留下歷史")
    func rejectedMoveLeavesNoTrace() throws {
        let w = try makeWorld()
        #expect(throws: TreeError.wouldCreateCycle) {
            try w.workBag.move(to: w.pen, in: w.context)
        }
        let events = try w.context.fetch(FetchDescriptor<MoveEvent>())
        #expect(events.isEmpty)
        #expect(w.workBag.parent == nil)
    }

    // MARK: - 刪除

    @Test("刪除容器後子節點上移到祖父，不連帶刪除")
    func deletingReparentsChildrenToTheGrandparent() throws {
        let w = try makeWorld()
        try w.pencilCase.delete(in: w.context)

        #expect(w.pen.parent === w.workBag)
        #expect(w.workBag.subtreeCount == 2)   // 鑑子筆、橡皮擦

        let survivors = try w.context.fetch(FetchDescriptor<Node>()).map(\.name)
        #expect(survivors.contains("鑑子筆"))
        #expect(survivors.contains("筆袋") == false)
    }

    @Test("刪除頂層容器後，子節點自己變成頂層")
    func deletingARootPromotesItsChildrenToRoots() throws {
        let w = try makeWorld()
        try w.workBag.delete(in: w.context)
        #expect(w.pencilCase.parent == nil)
        #expect(w.eraser.parent == nil)
    }

    @Test("刪除的節點若是別人的歸屬地，那些歸屬要被清掉而不是留下懸空參照")
    func deletingClearsHomeReferences() throws {
        let w = try makeWorld()
        try w.pencilCase.delete(in: w.context)
        #expect(w.pen.home == nil)
        #expect(w.eraser.home == nil)
    }

    @Test("被上移的子節點各留一筆歷史，位置變更不會斷鏈")
    func deletingRecordsAMoveEventForEachReparentedChild() throws {
        let w = try makeWorld()
        try w.pencilCase.delete(in: w.context)

        let events = try w.context.fetch(FetchDescriptor<MoveEvent>())
        #expect(events.count == 1)                       // 只有鑑子筆在筆袋裡
        #expect(events.first?.node?.name == "鑑子筆")
        #expect(events.first?.from?.name == "筆袋")
        #expect(events.first?.to?.name == "上班包")
    }

    @Test("刪除頂層容器時，子節點的歷史記到頂層")
    func deletingARootRecordsAMoveToNowhere() throws {
        let w = try makeWorld()
        try w.workBag.delete(in: w.context)

        let events = try w.context.fetch(FetchDescriptor<MoveEvent>())
        #expect(events.count == 2)                       // 筆袋、橡皮擦
        #expect(events.allSatisfy { $0.to == nil })
        #expect(Set(events.compactMap(\.node?.name)) == ["筆袋", "橡皮擦"])
    }

    @Test("容器被刪除並存檔後，歷史仍讀得出來且不會當掉")
    func historySurvivesDeletingAReferencedContainer() throws {
        let w = try makeWorld()
        try w.keycard.move(to: w.pencilCase, in: w.context)
        try w.context.save()

        try w.pencilCase.delete(in: w.context)
        try w.context.save()

        // 沒有名稱快照的話，這一行會拋 "This model instance was invalidated"
        let events = try w.context.fetch(FetchDescriptor<MoveEvent>())
        let keycardEvent = try #require(events.first { $0.nodeName == "門禁卡" })
        #expect(keycardEvent.fromName == "玄關")
        #expect(keycardEvent.toName == "筆袋")
        #expect(keycardEvent.to == nil)   // 參照安全地斷開，快照留下來
    }

    @Test("建檔與移到頂層在快照裡分別是空字串")
    func snapshotsUseAnEmptyStringForNowhere() throws {
        let w = try makeWorld()
        try w.pencilCase.move(to: nil, in: w.context)

        let events = try w.context.fetch(FetchDescriptor<MoveEvent>())
        let event = try #require(events.first { $0.nodeName == "筆袋" })
        #expect(event.fromName == "上班包")
        #expect(event.toName == "")
    }

    @Test("清掉歸屬地不算位置變更，不寫歷史")
    func clearingHomeIsNotAMove() throws {
        let w = try makeWorld()
        // 橡皮擦的 home 是筆袋，但人在上班包 —— 刪筆袋只清它的 home，沒有移動它
        try w.pencilCase.delete(in: w.context)

        let events = try w.context.fetch(FetchDescriptor<MoveEvent>())
        #expect(events.contains { $0.node?.name == "橡皮擦" } == false)
        #expect(w.eraser.parent === w.workBag)
    }
}
