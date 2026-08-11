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
            guard let name = DebugLaunch.containerToOpen else { return }
            let match = try? context.fetch(FetchDescriptor<Node>()).first { $0.name == name }
            guard let match else { return }

            path = [.container(match)]
            if DebugLaunch.wantsAddItem { path.append(.addItem(.into(match))) }

            // 名稱刻意不唯一（CloudKit 相容規則不用 `@Attribute(.unique)`），所以要在
            // 剛推進的那個容器的列裡面找，不能全庫撈第一個 —— 否則截圖步驟會安靜地
            // 拍到另一個同名節點的歷史。與 `-move` 的作法一致。
            if let itemName = DebugLaunch.itemToOpen,
               let item = match.inventoryRows.first(where: { $0.node.name == itemName })?.node {
                path.append(.item(item))
            }
        }
    }
}
#endif
