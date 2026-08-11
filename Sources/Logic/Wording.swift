import Foundation

/// 散在多個畫面、但必須一字不差的用語與格式。
///
/// 這裡放的都是「同一件事在不同畫面上要講同一句話」的東西。散成好幾份就會有一天
/// 只改到其中一份，而使用者看到的是兩種說法在講同一個狀態。
enum Wording {

    /// 東西的 `parent` 是 `nil` 時的說法 —— 這是一個**狀態的描述**。
    ///
    /// 與 `MoveDestinations.topLevelName`（「不放在任何容器裡」）**刻意不同**：
    /// 那一句是選單上的**動作**（把它放到頂層去），這一句是位置的**現況**（它現在不在任何容器裡）。
    /// 見 `docs/SPEC.md` §4.2b 與 §4.3a —— 兩節各自用各自的說法，不要統一。
    static let noContainer = "不在任何容器裡"

    /// `M 月 d 日`。盤點頁標頭（§4.2d）與詳細頁時間軸（§4.4e）共用。
    ///
    /// 同一支 app 裡的日期只該有一種長相，所以格式只寫在這裡一次。
    static func monthDay(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0) 月 \(c.day ?? 0) 日"
    }

    /// `M 月 d 日 HH:mm`。時間軸用，分鐘要補零 —— `20:2` 不是時間。
    static func monthDayTime(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return monthDay(date) + String(format: " %02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
