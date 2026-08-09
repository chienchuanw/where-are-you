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
}
