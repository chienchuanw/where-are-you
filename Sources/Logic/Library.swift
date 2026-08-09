import Foundation
import SwiftData

/// 首頁分組、搜尋、最近使用的容器。語意定義在 `docs/SPEC.md` §4.4b，
/// 集中在這裡是為了讓各畫面不要各自解讀。
enum Library {

    // MARK: - 首頁分組

    /// 「地點」= 所有根節點，依名稱排序。
    static func places(in context: ModelContext) throws -> [Node] {
        try context.fetch(FetchDescriptor<Node>())
            .filter { $0.parent == nil }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 「釘選」= 所有被釘的節點，不管它在樹的哪一層。
    ///
    /// 既是根節點又被釘選的容器會同時出現在兩組 —— 釘選是使用者主動的置頂，
    /// 不該因為它剛好是根節點就消失。
    static func pinned(in context: ModelContext) throws -> [Node] {
        try context.fetch(FetchDescriptor<Node>())
            .filter(\.isPinned)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - 搜尋

    /// 比對名稱與備註，不分大小寫，依最近更新排序。
    ///
    /// 備註要納入，是因為使用者常把型號、顏色寫在那裡（「充電線」三個字底下可能有五條）。
    static func search(_ query: String, in context: ModelContext) throws -> [Node] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        return try context.fetch(FetchDescriptor<Node>())
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
