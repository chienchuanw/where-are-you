import Foundation

/// 一件東西相對於某個容器的狀態。定義在 `docs/SPEC.md` §4.2b。
enum ItemStatus {
    /// 人在這裡，而且歸屬地是 `nil` 或落在這棵子樹裡。
    case present
    /// 歸屬在這裡但人已經離開整棵子樹。
    case missing
    /// 人在這裡但歸屬在別處。
    case foreign
}

/// 盤點頁的一列。
struct InventoryRow: Identifiable {
    let node: Node
    let status: ItemStatus

    /// `✓` 沒有副標 —— 記號已經說完「該在這、也在這」，再補一句是純冗餘。
    /// `✗` 與 `○` 各自缺的資訊不同，所以各補各的那一句。見 `docs/SPEC.md` §4.2b。
    let subtitle: String?

    var id: UUID { node.id }
}

/// 盤點頁的標頭行。
struct InventorySummary {
    /// 遞迴件數，與容器列上顯示的是同一個數字。
    let count: Int
    let missingCount: Int
    let lastUpdated: Date

    /// `5 件 · 缺 1 · 8 月 9 日更新`
    ///
    /// 日期一定要寫出來：`✓` 在一份三個月沒動過的清單上代表的是「三個月前在」，
    /// 不講出來會被讀成「現在在」，那比沒有資料更危險。
    var text: String {
        var parts = ["\(count) 件"]
        // 缺件數為 0 時整段不出現，不寫「缺 0」。
        if missingCount > 0 { parts.append("缺 \(missingCount)") }

        let components = Calendar.current.dateComponents([.month, .day], from: lastUpdated)
        parts.append("\(components.month ?? 0) 月 \(components.day ?? 0) 日更新")
        return parts.joined(separator: " · ")
    }
}

extension Node {

    /// 這一頁列出的東西：直接子節點 ∪ 缺件，依名稱排序。
    ///
    /// 缺件必須列出來，即使它已經不在這個容器裡 —— 否則 `✗` 這個狀態沒有列可以掛，
    /// 而「雨衣的歸屬地是登山包但人在陽台」正是出門前最需要看到的那一行。
    ///
    /// 只列直接子節點，不遞迴展開：包中包要能被點進去自己的盤點頁。
    /// 見 `docs/SPEC.md` §4.2a。
    var inventoryRows: [InventoryRow] {
        let inSubtree = Set(subtree.map(ObjectIdentifier.init))

        let present = childNodes.map { child -> InventoryRow in
            guard let home = child.home, !inSubtree.contains(ObjectIdentifier(home)) else {
                return InventoryRow(node: child, status: .present, subtitle: nil)
            }
            return InventoryRow(node: child, status: .foreign, subtitle: "歸屬在\(home.name)")
        }

        let absent = missingItems.map { item in
            InventoryRow(
                node: item,
                status: .missing,
                // parent 為 nil 有兩種原因：本來就在頂層，或它的容器被刪掉了。
                // 兩種對使用者是同一句話 —— 它不在任何容器裡。
                subtitle: item.parent.map { "在\($0.name)" } ?? "不在任何容器裡"
            )
        }

        // 依名稱排序，不依狀態分組：盤點是邊核對邊切換的過程，依狀態排會讓剛按過的
        // 那一列跳走，核到一半找不到看到哪裡。見 `docs/SPEC.md` §4.2c。
        return (present + absent)
            .sorted { $0.node.name.localizedStandardCompare($1.node.name) == .orderedAscending }
    }

    /// 標頭行的資料。見 `docs/SPEC.md` §4.2d。
    var inventorySummary: InventorySummary {
        let missing = missingItems
        // 缺件也算這一頁的一部分，所以它動過也要反映在日期上。
        let touched = subtree + missing
        return InventorySummary(
            count: subtreeCount,
            missingCount: missing.count,
            lastUpdated: touched.map(\.updatedAt).max() ?? updatedAt
        )
    }
}
