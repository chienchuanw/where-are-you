import Foundation
import SwiftData

enum TreeError: Error, Equatable {
    /// 把節點移進自己或自己的子孫會讓這棵樹不再是樹。
    case wouldCreateCycle
}

extension Node {

    // MARK: - 走訪

    var childNodes: [Node] { children ?? [] }

    /// 這個節點底下的所有子孫，不含自己。
    var descendants: [Node] {
        childNodes.flatMap { [$0] + $0.descendants }
    }

    /// 自己加上所有子孫。缺件與外來件的判斷都以「這棵子樹」為界。
    var subtree: [Node] { [self] + descendants }

    /// 遞迴件數，不含自己。
    var subtreeCount: Int { descendants.count }

    /// `node` 是否落在這棵子樹裡（含自己）。
    func containsInSubtree(_ node: Node) -> Bool {
        let ids = Set(subtree.map(ObjectIdentifier.init))
        return ids.contains(ObjectIdentifier(node))
    }

    // MARK: - 缺件與外來件

    /// 歸屬在這棵子樹裡、但人已經離開這棵子樹的東西。
    ///
    /// 定義刻意是「離開整個包」而不是「不在正確的格子裡」：東西從筆袋滑到包底時仍然
    /// 被帶出門了，報成缺件只會製造假警報，讓徽章很快被忽略。見 `docs/SPEC.md` §3.2。
    var missingItems: [Node] {
        let inSubtree = Set(subtree.map(ObjectIdentifier.init))
        return subtree
            .flatMap { $0.homedItems ?? [] }
            .filter { !inSubtree.contains(ObjectIdentifier($0)) }
    }

    var missingCount: Int { missingItems.count }

    /// 人在這棵子樹裡、但歸屬地在別處的東西。沒有歸屬地的不算。
    var foreignItems: [Node] {
        let inSubtree = Set(subtree.map(ObjectIdentifier.init))
        return descendants.filter { node in
            guard let home = node.home else { return false }
            return !inSubtree.contains(ObjectIdentifier(home))
        }
    }

    // MARK: - 移動

    /// 移動到 `newParent` 是否合法。`nil` 代表移到頂層。
    func canMove(to newParent: Node?) -> Bool {
        guard let newParent else { return true }
        return !containsInSubtree(newParent)
    }

    /// 移動並寫一筆歷史。被拒絕的移動不會留下任何痕跡。
    func move(to newParent: Node?, in context: ModelContext) throws {
        guard canMove(to: newParent) else { throw TreeError.wouldCreateCycle }

        let previousParent = parent
        parent = newParent
        updatedAt = Date()

        context.insert(MoveEvent(node: self, from: previousParent, to: newParent))
    }

    // MARK: - 刪除

    /// 刪除這個節點，子節點上移到祖父層。
    ///
    /// 絕不連帶刪除：沒有雲端備份的情況下，一次誤觸不該蒸發幾十筆資料。
    func delete(in context: ModelContext) throws {
        let grandparent = parent

        for child in childNodes {
            child.parent = grandparent
            child.updatedAt = Date()

            // 這是系統造成的位置變更，但歷史記的是「東西在哪」而不是「誰移動的」。
            // 少了這筆，物件的歷史會斷在一個已經不存在的容器上。
            context.insert(MoveEvent(node: child, from: self, to: grandparent))
        }

        // 別留下指向已刪節點的懸空歸屬地。這是「應該在哪」的變更，不是位置變更，
        // 所以不寫 MoveEvent。
        for item in homedItems ?? [] {
            item.home = nil
            item.updatedAt = Date()
        }

        // 先把自己從父節點卸下再刪。SwiftData 要等到存檔才把已刪物件移出關聯陣列，
        // 少了這一步，父節點的遞迴計數會把已經刪掉的節點算進去。
        parent = nil

        context.delete(self)
    }
}
