import SwiftUI
import SwiftData

/// 物件詳細頁。對照 Figma `Screens — Light / Item — Detail` 與 `Item — Detail — Container`，
/// 行為見 `docs/SPEC.md` §4.4–§4.4e。
///
/// **這一版是唯讀的**（§4.4a）。位置、歸屬地、備註都顯示但都還不能改 —— Figma 現行的
/// 三列都是純值列，沒有修改的入口，而視覺要先在 Figma 成立。照片同理，等 `PhotoStore`。
struct ItemDetailView: View {
    let node: Node

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            LargeTitleBar(title: node.name) { dismiss() }

            ScrollView {
                VStack(spacing: 0) {
                    ValueFieldRow(label: "目前位置", value: node.currentLocationText)
                    ValueFieldRow(label: "歸屬地", value: node.homeText)

                    // 備註空的時候整列不出現：一列空著只是在說「這裡可以填東西」，
                    // 而這一版還不能填（§4.4d）。
                    if let note = node.noteText {
                        ValueFieldRow(label: "備註", value: note)
                    }

                    if let link = node.inventoryLinkText {
                        InventoryLinkRow(text: link, route: .container(node))
                    }

                    SectionHeader(label: "移動歷史")
                    timeline
                }
                .padding(.horizontal, Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bgGrouped)
        .toolbar(.hidden, for: .navigationBar)
    }

    /// 左側那條縱線是這個容器的邊框，不是每一列自己的 —— 它要跨越所有列。
    ///
    /// 線寬 1 與 `FieldSeparator` 同一個處理：線寬屬於美術資產，不是設計 token。
    @ViewBuilder
    private var timeline: some View {
        let entries = node.timeline

        if entries.isEmpty {
            // 建檔一定寫一筆（§4.5c），被上移的子節點也一定寫一筆（§7），所以這裡是異常。
            // 異常要被看見，不是留白。
            Text("還沒有任何紀錄")
                .typography(.body)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, minHeight: Size.row, alignment: .leading)
        } else {
            VStack(spacing: 0) {
                ForEach(entries) { TimelineRow(entry: $0) }
            }
            .padding(.leading, Spacing.lg)
            .padding(.top, Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.borderSeparator)
                    .frame(width: 1)
            }
        }
    }
}
