import SwiftUI
import SwiftData

/// 導覽的根。首頁是根，其他畫面都是從它推進去的 —— 見 `docs/SPEC.md` §4.0。
///
/// 系統導覽列整支隱藏：v2 的大標題是自繪的，留著系統導覽列會多一條它自己的底線與高度，
/// 那正好是 v2 要拿掉的東西。返回鍵改由 `LargeTitleBar` 提供。
struct RootView: View {
    @State private var path: [Node] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Node.self) { node in
                    ContainerInventoryView(container: node)
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
    @Binding var path: [Node]
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content.task {
            guard let name = DebugLaunch.containerToOpen else { return }
            let match = try? context.fetch(FetchDescriptor<Node>()).first { $0.name == name }
            if let match { path = [match] }
        }
    }
}
#endif
