import Foundation
import SwiftData

/// 一次位置變更。存完整歷史而不是只覆寫「最後位置」——
/// 「回想最後一次在哪」常常需要往回看不只一步，而且誤操作可還原。
/// 見 `docs/SPEC.md` §2.2。
@Model
final class MoveEvent {
    var id: UUID = UUID()

    var node: Node?

    /// nil 代表建檔。
    var from: Node?
    var to: Node?

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
        self.at = at
        self.latitude = latitude
        self.longitude = longitude
        self.placemark = placemark
        self.photoFilename = photoFilename
    }
}
