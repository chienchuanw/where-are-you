import SwiftUI
import SwiftData
import OSLog

/// 容器盤點頁。對照 Figma `Screens — Light / Container — Inventory` 與 `Container — Empty`，
/// 行為見 `docs/SPEC.md` §4.2。
///
/// 這是這個 app 的主要更新入口 —— 使用者不會在搬動物品的當下開 app，他是在出門前核包時
/// 才發現資料要修，所以寫入做在他自然會來的這一頁。
struct ContainerInventoryView: View {
    let container: Node

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// 正在問「移到哪」的那個節點。收掉 sheet 而沒有選就什麼都不發生。
    @State private var nodeBeingMoved: Node?

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
                                let action = row.toggleAction(in: container)
                                ItemRow(
                                    row: row,
                                    action: action,
                                    onToggle: { perform(action, on: row.node) }
                                )
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
        .sheet(item: $nodeBeingMoved) { node in
            WhereIsItSheet(title: "\(node.name)移到哪？", node: node) { destination in
                move(node, to: destination)
                nodeBeingMoved = nil
            }
        }
        #if DEBUG
        // 見 `DebugLaunch`：sheet 只有點記號才會開，simctl 送不出點擊。
        .task {
            guard let name = DebugLaunch.itemToMove else { return }
            nodeBeingMoved = rows.first { $0.node.name == name }?.node
        }
        #endif
    }

    // MARK: - 狀態切換（見 `docs/SPEC.md` §4.2e）

    /// 決定「按下去該做什麼」的是 `InventoryRow.toggleAction`，在邏輯層、有測試守著。
    /// 這裡只負責把那個決定執行出來。
    private func perform(_ action: ToggleAction, on node: Node) {
        switch action {
        case .askWhereItIs:
            nodeBeingMoved = node
        case .moveIntoThisContainer:
            // 目的地已經確定了 —— 使用者正站在這個容器的盤點頁上按「它在這」。
            move(node, to: container)
        case .unavailable:
            // 記號在這個狀態下沒有觸控目標，走不到這裡。
            break
        }
    }

    private func move(_ node: Node, to destination: Node?) {
        do {
            try node.move(to: destination, in: context)
        } catch {
            // 兩條路徑都已經先擋掉會成環的移動 —— sheet 靠 §4.3b 濾選項，
            // 「它在這」靠 §4.2e 讓記號不可點。走到這裡代表那兩層之一漏了，
            // 不是使用者做錯什麼。
            Self.log.error("""
                「\(node.name, privacy: .public)」移不過去，資料沒有被改動：\
                \(error.localizedDescription, privacy: .public)
                """)
            return
        }

        do {
            try context.save()
        } catch {
            // 與上面那個是不同的故障：移動已經套用在記憶體裡，畫面也已經更新，
            // 只是沒有落到磁碟。合成同一句話會讓下次除錯分不出資料到底改了沒有。
            Self.log.error("""
                「\(node.name, privacy: .public)」已經移動，但存不進資料庫，重開 app 後會回到舊位置：\
                \(error.localizedDescription, privacy: .public)
                """)
        }
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
                message: "加入你出門一定要帶的東西，之後就能一眼確認有沒有漏。"
            ) {
                EmptyStateAction(label: "加入第一件", route: .addItem(.into(container)))
            }
        }
    }

    private static let log = Logger(subsystem: "com.chienchuanw.whereareyou", category: "inventory")
}
