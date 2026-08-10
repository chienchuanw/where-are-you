import SwiftUI

/// 容器盤點頁。對照 Figma `Screens — Light / Container — Inventory` 與 `Container — Empty`，
/// 行為見 `docs/SPEC.md` §4.2。
///
/// 這一版只做顯示與導覽 —— 點記號切換「在／不在」需要「它在哪？」sheet 才有去處，
/// 那支畫面不在這一支分支的範圍內。
struct ContainerInventoryView: View {
    let container: Node

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let rows = container.inventoryRows

        VStack(spacing: 0) {
            LargeTitleBar(title: container.name) { dismiss() }

            VStack(spacing: 0) {
                summary(isEmpty: rows.isEmpty)

                if rows.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(rows) { row in
                                if row.node.childNodes.isEmpty && row.status != .missing {
                                    ItemRow(row: row)
                                } else {
                                    // 有子節點的東西在 UI 上就是容器，點得進去自己的盤點頁。
                                    // 缺件也要點得進去 —— 那正是你要去確認它跑到哪的時候。
                                    NavigationLink(value: row.node) { ItemRow(row: row) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .padding(.horizontal, Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bgGrouped)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: -

    @ViewBuilder
    private func summary(isEmpty: Bool) -> some View {
        Text(isEmpty ? "還沒有東西" : container.inventorySummary.text)
            .typography(.subhead)
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Spacing.md)
    }

    private var emptyState: some View {
        OpticallyCentred {
            EmptyStateView(
                glyph: PlusGlyph(side: Size.iconLg),
                title: "這個包還是空的",
                message: "加入你出門一定要帶的東西，之後就能一眼確認有沒有漏。",
                actionLabel: "加入第一件",
                action: addFirstItem
            )
        }
    }

    // TODO: 新增流程（Figma `Item — Add`）不在這一支分支的範圍內，按鈕還沒有去處。
    private func addFirstItem() {}
}
