import SwiftUI
import SwiftData
import OSLog

/// 「它在哪？」sheet。對照 Figma `Screens — Light / Container — Where is it?`，
/// 行為見 `docs/SPEC.md` §4.3。
///
/// 這支只負責選，不負責移動 —— 選完把目的地交回呼叫端，由它寫入並收掉 sheet。
/// 收掉而沒有選則什麼都不發生：「我想改但還沒決定改成什麼」不是一次移動。
struct WhereIsItSheet: View {
    /// 要被移動的那個節點。標題與所有排除規則都是相對它算的。
    let node: Node
    /// `nil` 代表「不放在任何容器裡」。
    let onPick: (Node?) -> Void

    @Query private var nodes: [Node]
    @Environment(\.modelContext) private var context

    @State private var query = ""

    /// 最近被移入過的容器。算一次就好 —— 它讀的是整份移動歷史，那份只增不減，
    /// 掛在計算屬性上會變成每次重繪都重掃一遍。上限由 `MoveDestinations` 在排除之後才套。
    @State private var recent: [Node] = []

    var body: some View {
        VStack(spacing: 0) {
            Text("\(node.name)移到哪？")
                .typography(.title3)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Figma 是 header 自己的下內距 4 加上 sheet 的 gap 12。這裡兩段合成一個
                // token，因為程式碼沒有 header 那一層可以掛那個 4。
                .padding(.bottom, Spacing.lg)

            SearchField(text: $query, placeholder: "搜尋位置")
                .padding(.bottom, Spacing.md)

            options
        }
        // Figma 的 sheet 在標題上方留了 grabber 與一段間距。grabber 是 iOS 自己畫的，
        // 它的確切高度各版本不同，所以這裡不複製 Figma 那個數字（與 `LargeTitleBar`
        // 不複製狀態列的 52pt 同一條理由），只用一個夠讓標題閃開它的 token。
        .padding(.top, Spacing.xxxl)
        .padding(.horizontal, Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bgElevated)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.xl)
        .task { recent = loadRecentContainers() }
        #if DEBUG
        // 見 `DebugLaunch`：讓「找不到」那個狀態的截圖步驟可重現。
        .task { if let seeded = DebugLaunch.initialSheetSearch { query = seeded } }
        #endif
    }

    @ViewBuilder
    private var options: some View {
        let destinations = isSearching
            ? MoveDestinations.search(query, for: node, among: nodes)
            : MoveDestinations.options(for: node, among: nodes, recent: recent)

        if destinations.isEmpty {
            // 搜不到不給「建立「X」」—— 使用者正在回答「這東西移到哪」，
            // 順手長出一個空容器只會多一個沒人維護的節點。見 `docs/SPEC.md` §4.3c。
            Text("找不到「\(query)」")
                .typography(.subhead)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.lg)
            Spacer(minLength: 0)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(destinations) { destination in
                        Button { onPick(destination.node) } label: {
                            DestinationRow(destination: destination)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 排除的是**節點目前所在的容器**，不是正在檢視的畫面。從盤點頁開 sheet 時兩者
    /// 剛好相同（§4.2e），但依據是 `parent`。見 `docs/SPEC.md` §4.4b。
    private func loadRecentContainers() -> [Node] {
        do {
            return try Library.recentContainers(excluding: node.parent, in: context)
        } catch {
            // 讀不到歷史不該讓整支 sheet 開不起來 —— 少掉的只是捷徑那一組，
            // 下面的完整清單仍然選得到每一個容器。但一定要講出來：「還沒有任何移動歷史」
            // 與「歷史讀壞了」在畫面上長得一模一樣，吞掉就再也分不出來。
            Self.log.error("讀不到移動歷史，「最近用過」那一組會是空的：\(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static let log = Logger(subsystem: "com.chienchuanw.whereareyou", category: "where-is-it")
}
