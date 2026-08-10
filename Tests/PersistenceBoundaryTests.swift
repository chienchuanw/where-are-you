import Testing
import SwiftData
import Foundation
@testable import WhereAreYou

/// 跨持久化邊界的回歸測試。見 `CLAUDE.md`「跨持久化邊界必須測」。
///
/// 這一組的每個測試都會 `save()` 之後重新 fetch 再斷言。只在記憶體裡操作 `ModelContext`
/// 不會觸發 delete rule 傳播、關聯 faulting 與預設值套用 —— 那些只在邊界的另一側才會出錯。
///
/// 這些情境曾經在 code review 時被實際跑出來過，但當時寫在臨時 worktree 裡，隨 worktree
/// 一起消失。補回 repo，否則 `Node` 上那三個 inverse 被拿掉時沒有東西會擋。
@MainActor
struct PersistenceBoundaryTests {

    private func freshContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Node.self, MoveEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - 刪除後歷史仍可讀

    @Test("刪掉事件的來源容器並存檔後，歷史讀得出來")
    func deletingTheSourceContainerLeavesHistoryReadable() throws {
        let context = try freshContext()
        let desk = Node(name: "書桌")
        let bag = Node(name: "登山包")
        let torch = Node(name: "頭燈", parent: desk)
        for node in [desk, bag, torch] { context.insert(node) }
        try context.save()

        try torch.move(to: bag, in: context)
        try context.save()

        try desk.delete(in: context)
        try context.save()

        let events = try context.fetch(FetchDescriptor<MoveEvent>())
        let move = try #require(events.first { $0.nodeName == "頭燈" && $0.toName == "登山包" })
        #expect(move.fromName == "書桌")     // 快照留著
        #expect(move.from == nil)            // 參照安全斷開，不是失效 fault
        #expect(move.to?.name == "登山包")   // 還在的節點仍然指得到
    }

    @Test("刪掉事件主體本身並存檔後，歷史讀得出來")
    func deletingTheSubjectOfAnEventLeavesHistoryReadable() throws {
        let context = try freshContext()
        let shelf = Node(name: "層架")
        let box = Node(name: "收納箱", parent: shelf)
        context.insert(shelf); context.insert(box)
        try context.save()

        try box.move(to: nil, in: context)
        try context.save()

        try box.delete(in: context)
        try context.save()

        let events = try context.fetch(FetchDescriptor<MoveEvent>())
        let move = try #require(events.first { $0.nodeName == "收納箱" })
        #expect(move.node == nil)
        #expect(move.nodeName == "收納箱")
        #expect(move.fromName == "層架")
    }

    @Test("同一個容器同時是某事件的來源與另一事件的目的地，刪掉後兩邊都安全")
    func aContainerUsedAsBothSourceAndDestinationDetachesCleanly() throws {
        let context = try freshContext()
        let hallway = Node(name: "玄關")
        let drawer = Node(name: "抽屜")
        let keys = Node(name: "鑰匙", parent: hallway)
        let card = Node(name: "門禁卡", parent: drawer)
        for node in [hallway, drawer, keys, card] { context.insert(node) }
        try context.save()

        try keys.move(to: drawer, in: context)    // drawer 當目的地
        try card.move(to: hallway, in: context)   // drawer 當來源
        try context.save()

        try drawer.delete(in: context)
        try context.save()

        let events = try context.fetch(FetchDescriptor<MoveEvent>())
        #expect(events.allSatisfy { $0.to == nil || $0.to?.name != "抽屜" })
        #expect(events.allSatisfy { $0.from == nil || $0.from?.name != "抽屜" })
        #expect(events.contains { $0.nodeName == "鑰匙" && $0.toName == "抽屜" })
        #expect(events.contains { $0.nodeName == "門禁卡" && $0.fromName == "抽屜" })
    }

    @Test("連續刪掉多個被歷史引用的容器都不會炸")
    func deletingSeveralReferencedContainersInSequenceIsSafe() throws {
        let context = try freshContext()
        let a = Node(name: "甲")
        let b = Node(name: "乙")
        let c = Node(name: "丙")
        let item = Node(name: "物件", parent: a)
        for node in [a, b, c, item] { context.insert(node) }
        try context.save()

        try item.move(to: b, in: context)
        try context.save()
        try item.move(to: c, in: context)
        try context.save()

        for container in [a, b, c] {
            try container.delete(in: context)
            try context.save()
        }

        let events = try context.fetch(FetchDescriptor<MoveEvent>())

        // 三筆：兩次主動移動，加上刪掉丙時把物件上移到頂層所寫的那筆（SPEC §7）
        #expect(events.count == 3)
        #expect(Set(events.map(\.toName)) == ["乙", "丙", ""])
        #expect(events.allSatisfy { $0.from == nil && $0.to == nil })   // 參照全數安全斷開

        let promotion = try #require(events.first { $0.toName == "" })
        #expect(promotion.fromName == "丙")
        #expect(item.parent == nil)   // 最後一個容器被刪，物件升到頂層
    }

    // MARK: - 查詢層在邊界另一側

    @Test("最近使用的容器在來源被刪除並存檔後，不會炸也不會列出已刪的容器")
    func recentContainersSurvivesADeletedDestination() throws {
        let context = try freshContext()
        let study = Node(name: "書房")
        let bag = Node(name: "上班包")
        let pen = Node(name: "筆", parent: study)
        for node in [study, bag, pen] { context.insert(node) }
        try context.save()

        try pen.move(to: bag, in: context)
        try context.save()

        try bag.delete(in: context)
        try context.save()

        let recent = try Library.recentContainers(excluding: nil, limit: 5, in: context)
        #expect(recent.contains { $0.name == "上班包" } == false)
    }

    // MARK: - 模型屬性在邊界另一側

    @Test("重新 fetch 之後，屬性預設值與 optional 性都還原得回來")
    func modelDefaultsRoundTripThroughTheStore() throws {
        let context = try freshContext()
        let bare = Node(name: "只有名字")
        context.insert(bare)
        try context.save()

        let refetched = try #require(
            try context.fetch(FetchDescriptor<Node>()).first { $0.name == "只有名字" }
        )
        #expect(refetched.note == "")
        #expect(refetched.isPinned == false)
        #expect(refetched.photoFilename == nil)
        #expect(refetched.parent == nil)
        #expect(refetched.home == nil)
        #expect(refetched.childNodes.isEmpty)
    }

    @Test("歸屬地被清掉之後存檔，重新讀回來仍然是空的")
    func clearedHomeStaysClearedAcrossASave() throws {
        let context = try freshContext()
        let case1 = Node(name: "筆袋")
        let pen = Node(name: "筆", parent: case1, home: case1)
        context.insert(case1); context.insert(pen)
        try context.save()

        try case1.delete(in: context)
        try context.save()

        let refetched = try #require(
            try context.fetch(FetchDescriptor<Node>()).first { $0.name == "筆" }
        )
        #expect(refetched.home == nil)
        #expect(refetched.parent == nil)
    }
}
