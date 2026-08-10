import Foundation
import SwiftData

/// 首頁分組、搜尋、最近使用的容器。語意定義在 `docs/SPEC.md` §4.4b，
/// 集中在這裡是為了讓各畫面不要各自解讀。
enum Library {

    // MARK: - 首頁分組

    /// 「地點」= 所有根節點，依名稱排序。
    static func places(in context: ModelContext) throws -> [Node] {
        places(among: try context.fetch(FetchDescriptor<Node>()))
    }

    /// 「釘選」= 所有被釘的節點，不管它在樹的哪一層。
    ///
    /// 既是根節點又被釘選的容器會同時出現在兩組 —— 釘選是使用者主動的置頂，
    /// 不該因為它剛好是根節點就消失。
    static func pinned(in context: ModelContext) throws -> [Node] {
        pinned(among: try context.fetch(FetchDescriptor<Node>()))
    }

    // 畫面用 `@Query` 拿到的是陣列，不是 ModelContext。分組語意只有一份，
    // 上面兩個取完資料就轉呼叫這裡，免得畫面自己重新解讀一次。
    static func places(among nodes: [Node]) -> [Node] {
        nodes.filter { $0.parent == nil }.sortedByName()
    }

    static func pinned(among nodes: [Node]) -> [Node] {
        nodes.filter(\.isPinned).sortedByName()
    }

    // MARK: - 搜尋

    /// 比對名稱與備註，不分大小寫，依最近更新排序。
    ///
    /// 備註要納入，是因為使用者常把型號、顏色寫在那裡（「充電線」三個字底下可能有五條）。
    static func search(_ query: String, in context: ModelContext) throws -> [Node] {
        search(query, among: try context.fetch(FetchDescriptor<Node>()))
    }

    static func search(_ query: String, among nodes: [Node]) -> [Node] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        return nodes
            .filter { node in
                node.name.localizedCaseInsensitiveContains(needle)
                    || node.note.localizedCaseInsensitiveContains(needle)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - 最近使用的容器

    /// 「它在哪？」sheet 的第一組選項：最近被移入過的容器，新的在前、去除重複。
    ///
    /// 排除正在檢視的容器 —— 把東西移到它已經在的地方沒有意義。
    static func recentContainers(
        excluding current: Node?,
        limit: Int,
        in context: ModelContext
    ) throws -> [Node] {
        let events = try context.fetch(
            FetchDescriptor<MoveEvent>(sortBy: [SortDescriptor(\.at, order: .reverse)])
        )

        var seen = Set<ObjectIdentifier>()
        var result: [Node] = []
        if let current { seen.insert(ObjectIdentifier(current)) }

        for event in events {
            // to 為 nil 有兩種原因：當初就是移到頂層，或是那個容器後來被刪了。
            // 兩種都該排除 —— 前者沒有容器可記，後者容器已經不存在。
            guard let destination = event.to else { continue }
            let key = ObjectIdentifier(destination)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(destination)
            if result.count == limit { break }
        }
        return result
    }
}

/// 首頁兩組與盤點頁共用的名稱排序 —— 數字照人類的直覺排（`充電線 2` 在 `充電線 10` 前面）。
///
/// 共用的是這個比較式本身，不是某個 `sorted` 呼叫：首頁排的是 `Node`，盤點頁排的是
/// `InventoryRow`，型別對不起來。各自再寫一次的話，之後改了校對規則只會有一邊跟著動，
/// 而兩邊的排序看起來又一直是對的，這種漂移要很久才會被發現。
enum NameOrder {
    static func isAscending(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }
}

extension Array where Element == Node {
    func sortedByName() -> [Node] {
        sorted { NameOrder.isAscending($0.name, $1.name) }
    }
}
