import Foundation

/// 「它在哪？」sheet 上的一個位置選項。
struct MoveDestination: Identifiable {
    /// `nil` 代表「不放在任何容器裡」，也就是移到頂層。
    let node: Node?

    /// 右側是否標「最近用過」。搜尋狀態下一律是 `false`。
    let isRecent: Bool

    // 頂層那一列沒有節點可以借 id。整個 app 只會有一列是它，所以一個固定值就夠。
    private static let topLevelID = UUID()

    var id: UUID { node?.id ?? Self.topLevelID }
    var name: String { node?.name ?? "不放在任何容器裡" }
}

/// sheet 的選項組成。語意在 `docs/SPEC.md` §4.3a–§4.3c。
///
/// 「最近用過」那一組由呼叫端傳進來（`Library.recentContainers`），因為它要讀移動歷史；
/// 這裡只負責把三段接起來並套用排除規則。
enum MoveDestinations {

    /// 「最近用過」那一組最多幾個。見 `docs/SPEC.md` §4.3a。
    ///
    /// 上限由這裡套用而不是交給 `Library.recentContainers` 的 `limit`，因為它必須落在
    /// 排除規則**之後**。先砍到三個再排除，名額會被不能選的容器佔掉，合格的後補不會遞補。
    static let recentLimit = 3

    /// 沒有在搜尋時的完整清單：最近用過 → 其餘依名稱 → 不放在任何容器裡。
    ///
    /// `node` 傳 `nil` 代表那個東西還不存在（新增流程的位置與歸屬地選擇器，§4.5d）——
    /// 沒有自己與子孫要排除，也沒有目前的 parent，所以一條都不排除。
    static func options(for node: Node?, among all: [Node], recent: [Node]) -> [MoveDestination] {
        let blocked = blockedIDs(for: node)
        func isAllowed(_ candidate: Node) -> Bool {
            !blocked.contains(ObjectIdentifier(candidate))
        }

        // 最近用過的那一組也要過濾。`Library.recentContainers` 只排除一個容器，
        // 循環防呆不在它的職責範圍內。
        let recents = Array(recent.filter(isAllowed).prefix(recentLimit))
        let promoted = Set(recents.map(ObjectIdentifier.init))

        let rest = all
            .filter { isAllowed($0) && !promoted.contains(ObjectIdentifier($0)) }
            .sortedByName()

        var options = recents.map { MoveDestination(node: $0, isRecent: true) }
        options += rest.map { MoveDestination(node: $0, isRecent: false) }

        // 本來就在頂層的東西不需要這一列 —— 與排除目前 parent 同一條理由。
        // 還不存在的東西則一定要有：首頁那個入口的預設值就是頂層。
        let allowsTopLevel = node.map { $0.parent != nil } ?? true
        if allowsTopLevel {
            options.append(MoveDestination(node: nil, isRecent: false))
        }
        return options
    }

    /// 搜尋狀態下的清單：三段全部收起來，只留符合的候選。
    ///
    /// 比對規則沿用首頁的搜尋（`Library.search`），這樣兩個地方只需要學一次。
    static func search(_ query: String, for node: Node?, among all: [Node]) -> [MoveDestination] {
        let blocked = blockedIDs(for: node)
        return Library.search(query, among: all)
            .filter { !blocked.contains(ObjectIdentifier($0)) }
            .map { MoveDestination(node: $0, isRecent: false) }
    }

    /// 自己、自己的所有子孫、以及目前的 parent。見 `docs/SPEC.md` §4.3b。
    ///
    /// 防在選單這一層而不是等 `move(to:)` 拋錯：一個選了一定會失敗的選項不該出現在選單上。
    private static func blockedIDs(for node: Node?) -> Set<ObjectIdentifier> {
        guard let node else { return [] }
        var ids = Set(node.subtree.map(ObjectIdentifier.init))
        if let parent = node.parent { ids.insert(ObjectIdentifier(parent)) }
        return ids
    }
}
