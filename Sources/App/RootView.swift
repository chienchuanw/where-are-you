import SwiftUI
import SwiftData

/// 可以被推進去的畫面。
///
/// 首頁是根，其他畫面都是從它推進去的 —— 見 `docs/SPEC.md` §4.0。
enum Route: Hashable {
    case container(Node)
    /// 物件詳細頁。盤點頁的每一列都通往這裡，不分它有沒有子節點 —— 否則容器永遠
    /// 到不了自己的詳細頁，而那正是唯一能改歸屬地的地方（§4.4c）。
    case item(Node)
    /// 新增物件。帶著入口，因為「從哪裡來」就決定了預填什麼（§4.5b）。
    case addItem(AddItemEntry)
}

/// 導覽的根。
///
/// 系統導覽列整支隱藏：v2 的大標題是自繪的，留著系統導覽列會多一條它自己的底線與高度，
/// 那正好是 v2 要拿掉的東西。返回鍵改由 `LargeTitleBar` 與 `InlineTitleBar` 提供。
struct RootView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .container(let node):
                        ContainerInventoryView(container: node)
                    case .item(let node):
                        ItemDetailView(node: node)
                    case .addItem(let entry):
                        AddItemView(draft: NewItemDraft(entry))
                    }
                }
        }
        .tint(Color.accent)
        #if DEBUG
        .modifier(OpenContainerOnLaunch(path: $path))
        #endif
    }
}

#if DEBUG
/// 見 `DebugLaunch`：讓截圖步驟可重現。
private struct OpenContainerOnLaunch: ViewModifier {
    @Binding var path: [Route]
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content.task {
            let all = (try? context.fetch(FetchDescriptor<Node>())) ?? []

            guard let name = DebugLaunch.containerToOpen else {
                // 單獨用 `-open-item`：頂層節點不在任何容器的列裡（`inventoryRows` 是
                // 直接子節點 ∪ 缺件），沒有這條路的話，登山包這種根節點的詳細頁就到不了 ——
                // 而 `Item — Detail — Container` 那支 frame 用的正是它。
                if let itemName = DebugLaunch.itemToOpen,
                   let item = all.first(where: { $0.name == itemName }) {
                    path = [.item(item)]
                }
                return
            }
            guard let match = all.first(where: { $0.name == name }) else { return }

            path = [.container(match)]
            if DebugLaunch.wantsAddItem { path.append(.addItem(.into(match))) }

            // 名稱刻意不唯一（CloudKit 相容規則不用 `@Attribute(.unique)`），所以有
            // `-open-container` 時要在那個容器的列裡面找，不能全庫撈第一個 ——
            // 否則截圖步驟會安靜地拍到另一個同名節點的歷史。與 `-move` 的作法一致。
            if let itemName = DebugLaunch.itemToOpen,
               let item = match.inventoryRows.first(where: { $0.node.name == itemName })?.node {
                path.append(.item(item))
            }
        }
    }
}
#endif
