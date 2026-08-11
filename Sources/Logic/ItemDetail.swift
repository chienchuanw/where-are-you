import Foundation

/// 詳細頁時間軸的一列。
///
/// 兩個字串都是**算好的成品**，畫面不再做判斷 —— 上行是發生了什麼，下行是時間與地點。
/// 見 `docs/SPEC.md` §4.4e。
struct TimelineEntry: Identifiable, Equatable {
    let id: UUID
    let title: String
    let meta: String

    /// 最新的那一筆。它的目的地就是這個東西現在在的地方，所以下行走強調色（SPEC §9）。
    let isCurrent: Bool
}

extension MoveEvent {

    /// 上行。**只讀名稱快照，不讀關聯** —— 關聯在節點被刪除後會被清成 `nil`，
    /// 只有快照撐得住（`docs/SPEC.md` §2.2）。
    ///
    /// 空字串有語意：`fromName` 空代表建檔，`toName` 空代表移到頂層。
    var timelineTitle: String {
        switch (fromName.isEmpty, toName.isEmpty) {
        case (true, true):   "建檔，\(Wording.noContainer)"
        case (true, false):  "建檔於\(toName)"
        // 移到頂層仍然用箭頭：每一列同一個形狀，眼睛只要學一次，
        // 而箭頭左邊永遠是「這次移動之後在哪」。
        case (false, true):  "\(Wording.noContainer) ← \(fromName)"
        case (false, false): "\(toName) ← \(fromName)"
        }
    }

    /// 下行：`M 月 d 日 HH:mm`，有地名才接 ` · 地名`。
    ///
    /// 日期格式與 §4.2d 的標頭同一個 —— 同一支 app 裡的日期只該有一種長相。
    var timelineMeta: String {
        var text = Wording.monthDayTime(at)
        if let placemark, !placemark.isEmpty { text += " · \(placemark)" }
        return text
    }
}

extension Node {

    /// 完整的移動歷史，新到舊。
    ///
    /// `at` 相同時用 `id` 當第二鍵：沒有第二鍵的話，同一頁兩次開啟可能列出不同順序，
    /// 那看起來就像資料自己在變。
    var timeline: [TimelineEntry] {
        let sorted = (moveEvents ?? []).sorted { lhs, rhs in
            lhs.at == rhs.at ? lhs.id.uuidString < rhs.id.uuidString : lhs.at > rhs.at
        }

        return sorted.enumerated().map { index, event in
            TimelineEntry(
                id: event.id,
                title: event.timelineTitle,
                meta: event.timelineMeta,
                isCurrent: index == 0
            )
        }
    }

    /// 目前位置。頂層不是「沒有值」，而是一個講得出來的狀態（§4.2b 也是這個說法）。
    var currentLocationText: String {
        parent?.name ?? Wording.noContainer
    }

    /// 歸屬地。沒設定時那一列**仍然要在** —— 「沒有歸屬地」是關於這件東西的事實
    /// （它永遠不算缺、也不算外來，§3.3），不是一個缺漏。
    var homeText: String {
        home?.name ?? "未設定"
    }

    /// 備註。空的時候整列不出現：備註沒有語意，一列空著只是在說「這裡可以填東西」，
    /// 而這一版還不能填。
    var noteText: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 進這個容器盤點頁的那一列。
    ///
    /// 出現的條件是**它的盤點頁列得出東西**，不是「它有子節點」—— 盤點頁列的是
    /// 直接子節點 ∪ 缺件（§4.2a）。一個包被帶出去、裡面的東西又各自被拿走時，
    /// 它的子節點是空的，但歸屬在它底下的東西仍然會以 `✗` 列在它的盤點頁上，
    /// 而那正是使用者要去把它們標回來的地方。用子節點當條件會讓那一頁到不了。
    ///
    /// N 用遞迴件數（§3.1），與首頁、盤點頁標頭同一個數字，所以上述情況會是「裡面有 0 件」。
    /// 那是真的：東西確實都不在裡面，點進去正好看到它們跑到哪了。
    var inventoryLinkText: String? {
        guard !inventoryRows.isEmpty else { return nil }
        return "裡面有 \(subtreeCount) 件"
    }
}
