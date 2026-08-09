import Foundation
import SwiftData

/// 一切都是 Node —— 空間、容器、物件沒有型別上的分別，任何 Node 都能裝下另一個 Node。
///
/// 這樣「登山包被帶去公司」時，包裡的東西位置會自動跟著走；三層固定模型做不到這件事。
/// 見 `docs/SPEC.md` §2.1。
///
/// 屬性刻意全部給預設值、關聯全部 optional、不使用 `@Attribute(.unique)`，
/// 這是 CloudKit 的相容條件。MVP 不開同步，但先守著就不必痛苦遷移。
@Model
final class Node {
    var id: UUID = UUID()
    var name: String = ""
    var note: String = ""

    /// 是否釘在首頁。登山包的 parent 通常是「家」，若首頁只列根節點，
    /// 最高頻的動作（出門前核包）反而藏得最深。
    var isPinned: Bool = false

    /// 照片存檔案系統，資料庫只存檔名。
    var photoFilename: String?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// 目前實際在哪。
    var parent: Node?

    @Relationship(deleteRule: .nullify, inverse: \Node.parent)
    var children: [Node]?

    /// 本來應該在哪。缺件與外來件都是拿它跟 `parent` 比出來的。
    var home: Node?

    @Relationship(deleteRule: .nullify, inverse: \Node.home)
    var homedItems: [Node]?

    // 這三個 inverse 存在的唯一目的是讓刪除安全。少了它們，`MoveEvent` 的參照在
    // 節點被刪除並存檔後會變成失效的 fault，再讀就整個當掉。有了它們，參照會被
    // 乾淨地清成 nil，歷史則靠 MoveEvent 自己的名稱快照繼續讀得出來。
    @Relationship(deleteRule: .nullify, inverse: \MoveEvent.node)
    var moveEvents: [MoveEvent]?

    @Relationship(deleteRule: .nullify, inverse: \MoveEvent.from)
    var movedOutEvents: [MoveEvent]?

    @Relationship(deleteRule: .nullify, inverse: \MoveEvent.to)
    var movedInEvents: [MoveEvent]?

    init(name: String, parent: Node? = nil, home: Node? = nil, note: String = "", isPinned: Bool = false) {
        self.id = UUID()
        self.name = name
        self.note = note
        self.isPinned = isPinned
        self.parent = parent
        self.home = home
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
