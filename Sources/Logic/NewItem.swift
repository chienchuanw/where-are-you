import Foundation
import SwiftData

/// 新增物件的三個入口。見 `docs/SPEC.md` §4.5b。
///
/// 做成型別而不是三個布林／可選參數，是因為它同時是導覽的目的地：
/// 「從哪裡來」決定了預填什麼，兩件事本來就是同一個決定。
enum AddItemEntry: Hashable {
    /// 盤點頁的「加入第一件」。使用者剛剛才在那個容器的頁面上。
    case into(Node)

    /// 首頁空狀態的「建立第一個空間」。空間就是根節點（§4.4b 的「地點」），
    /// 而且一個庫還空著的時候也沒有別的容器可以放。
    case firstPlace

    /// 搜尋無結果的「建立「X」」。沒有 GPS 時，「你剛剛才放東西進去的那個容器」
    /// 是手上最好的猜測；猜錯的代價只是一次「更改」。
    case named(String, suggested: Node?)
}

/// 新增物件表單的狀態。語意在 `docs/SPEC.md` §4.5。
///
/// 表單只有三個值，但它們之間有一條不明顯的規則（歸屬地跟著位置走，直到使用者自己選過），
/// 而那條規則錯了會靜默建出與使用者所想相反的資料。所以放在邏輯層，不放在畫面裡。
struct NewItemDraft {
    var name: String = ""

    private(set) var location: Node?
    private(set) var home: Node?

    /// 歸屬地是否已經被使用者自己選過。沒有的話它跟著位置走。
    private(set) var homeIsExplicit = false

    // MARK: - 入口（§4.5b）

    /// 一般情況：位置給定，歸屬地跟著它。
    init(location: Node?) {
        self.location = location
        self.home = location
    }

    /// 由入口決定預填。沒有 GPS 的這一版，依據是「使用者從哪裡來」——
    /// 那比 GPS 更確定，因為他剛剛才在那個頁面上。
    init(_ entry: AddItemEntry) {
        switch entry {
        case .into(let container):
            self.init(location: container)
        case .firstPlace:
            self.init(location: nil)
        case .named(let name, let suggested):
            self.init(location: suggested)
            self.name = name
        }
    }

    // MARK: - 欄位

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 名稱是這個 app 的識別主鍵（§2.1）。沒填就不能送出 ——
    /// 一筆沒有名稱的資料在任何畫面上都認不出來。
    var canSubmit: Bool { !trimmedName.isEmpty }

    /// 歸屬地那一列上顯示的值。
    var homeLabel: String {
        guard homeIsExplicit else { return "同位置" }
        return home?.name ?? MoveDestination.topLevelName
    }

    /// 位置那一列上顯示的值。
    var locationLabel: String { location?.name ?? MoveDestination.topLevelName }

    mutating func setLocation(_ node: Node?) {
        location = node
        // 使用者自己選過歸屬地之後就脫鉤 —— 「先設好歸屬地、再改位置」正是
        // 「這件東西現在暫時放在別的地方」的建檔情境，這時覆蓋掉他的選擇是錯的。
        if !homeIsExplicit { home = node }
    }

    mutating func setHome(_ node: Node?) {
        // 挑了畫面上已經生效的那一個，不算選過。那一下什麼都沒改變，脫鉤卻已經發生 ——
        // 接著改位置就會建出一筆立刻被算成缺件的資料。脫鉤是看不見的狀態，
        // 只有真的改變了值才值得付出這個代價。見 `docs/SPEC.md` §4.5a。
        guard node !== home else { return }

        home = node
        // 選「不放在任何容器裡」也是一次選擇，不是「還沒選」。
        homeIsExplicit = true
    }

    // MARK: - 寫入（§4.5c）

    /// 建立節點並寫一筆建檔歷史。名稱沒填時什麼都不做並回傳 `nil`。
    @discardableResult
    func create(in context: ModelContext) -> Node? {
        guard canSubmit else { return nil }

        let node = Node(name: trimmedName, parent: location, home: home)
        context.insert(node)

        // 容器的內容變了，跟著標記成剛動過。與 §4.2d 的移動同一條理由：
        // 盤點頁的標頭不能在剛被寫入之後還顯示舊日期。
        location?.updatedAt = node.createdAt

        // from 為 nil 代表建檔，見 `docs/SPEC.md` §2.2。
        context.insert(MoveEvent(node: node, from: nil, to: location, at: node.createdAt))
        return node
    }

    /// 把一次剛建好、但存不進資料庫的建檔收回來。
    ///
    /// 存檔失敗時**當作沒建過**：建檔是憑空多一筆，收回之後記憶體與磁碟又完全一致，
    /// 等於那個動作沒發生過。移動不能這樣處理（改的是既有節點，改回去會變成第三種說法），
    /// 但這裡可以。不收回的話，這一頁會表演出一次成功 —— 畫面退回去、或名稱欄清空讓你
    /// 接著建下一件 —— 使用者於是連續建了八件，八件全部沒有落地。見 `docs/SPEC.md` §4.5c。
    static func rollBack(_ node: Node, in context: ModelContext) {
        for event in node.moveEvents ?? [] { context.delete(event) }

        // 先從父節點卸下再刪。SwiftData 要等到存檔才把已刪物件移出關聯陣列，
        // 少了這一步，容器的遞迴計數會把已經收回的節點算進去。
        node.parent = nil
        node.home = nil
        context.delete(node)
    }

    /// 「再新增一件」：只清掉名稱。
    ///
    /// 位置與歸屬地留著，因為這顆按鈕服務的是「把登山包裡八件裝備一次建完」——
    /// 那個情境裡它們從頭到尾是同一個答案。
    mutating func startAnother() {
        name = ""
    }
}
