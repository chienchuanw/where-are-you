import Foundation
import SwiftData

/// 一次位置變更。存完整歷史而不是只覆寫「最後位置」——
/// 「回想最後一次在哪」常常需要往回看不只一步，而且誤操作可還原。
/// 見 `docs/SPEC.md` §2.2。
@Model
final class MoveEvent {
    var id: UUID = UUID()

    /// 三個關聯都在 `Node` 上有對應的 inverse 並設 `deleteRule: .nullify`。
    /// 少了 inverse，節點被刪除並存檔後再讀這裡會拋
    /// `This model instance was invalidated because its backing data could no longer be
    /// found in the store`。
    ///
    /// 有了 inverse 之後參照會安全地變成 `nil` —— 但那也代表參照本身靠不住，
    /// 所以**顯示一律以名稱快照為準**，關聯只用於「該節點還在時可以點進去」。
    var node: Node?
    var from: Node?
    var to: Node?

    /// 名稱快照。歷史是只增不改的紀錄，不該因為容器被刪就掉資訊 ——
    /// 「書房抽屜 ← 登山包」在登山包被刪之後仍然要讀得出來。
    ///
    /// `fromName` 為空字串代表建檔，`toName` 為空字串代表移到頂層。
    var nodeName: String = ""
    var fromName: String = ""
    var toName: String = ""

    var at: Date = Date()

    /// 當下的座標與地名。GPS 的主要價值是降低輸入摩擦與補上「臨時放在某處」，
    /// 不是取代容器階層。權限只要 When-In-Use。
    var latitude: Double?
    var longitude: Double?
    var placemark: String?

    /// 現場照，與物件的建檔照是兩回事。
    var photoFilename: String?

    init(
        node: Node?,
        from: Node?,
        to: Node?,
        at: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        placemark: String? = nil,
        photoFilename: String? = nil
    ) {
        self.id = UUID()
        self.node = node
        self.from = from
        self.to = to
        self.nodeName = node?.name ?? ""
        self.fromName = from?.name ?? ""
        self.toName = to?.name ?? ""
        self.at = at
        self.latitude = latitude
        self.longitude = longitude
        self.placemark = placemark
        self.photoFilename = photoFilename
    }
}
