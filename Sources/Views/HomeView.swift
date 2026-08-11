import SwiftUI
import SwiftData
import OSLog

/// 首頁。對照 Figma `Screens — Light / Home`、`Home — Empty`、`Search — No Results`，
/// 行為見 `docs/SPEC.md` §4.1 與 §4.4b。
struct HomeView: View {
    /// 分組與搜尋的語意只有一份，在 `Library` 裡。這裡拿到整包節點就轉手交給它，
    /// 畫面不重新解讀「哪些算地點」這種問題。
    @Query private var nodes: [Node]

    @Environment(\.modelContext) private var context

    @State private var query = ""

    /// 見 `loadMostRecentContainer()`：每敲一個字重掃一次移動歷史太貴。
    @State private var mostRecentContainer: Node?

    var body: some View {
        VStack(spacing: 0) {
            LargeTitleBar(title: "我的東西")

            VStack(spacing: 0) {
                // 一件東西都沒有時不放搜尋列 —— 沒有東西可搜，擺著只是噪音。
                // 對照 Figma `Home — Empty`。
                if !nodes.isEmpty {
                    SearchField(text: $query, placeholder: "搜尋物件")
                }
                content
            }
            .padding(.horizontal, Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bgGrouped)
        .toolbar(.hidden, for: .navigationBar)
        .task { mostRecentContainer = loadMostRecentContainer() }
        #if DEBUG
        // 見 `DebugLaunch`：讓「搜尋無結果」這個狀態的截圖步驟可重現。
        .task { if let seeded = DebugLaunch.initialSearch { query = seeded } }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if nodes.isEmpty {
            OpticallyCentred {
                EmptyStateView(
                    glyph: PlusGlyph(side: Size.iconLg),
                    title: "還沒有任何收納空間",
                    message: "先建一個你最常翻的地方 —— 通常是每天出門會帶的那個包。"
                ) {
                    EmptyStateAction(label: "建立第一個空間", route: .addItem(.firstPlace))
                }
            }
        } else if isSearching {
            searchResults
        } else {
            ScrollView {
                groups
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - 分組

    private var groups: some View {
        VStack(spacing: 0) {
            let pinned = Library.pinned(among: nodes)
            if !pinned.isEmpty {
                SectionHeader(label: "釘選")
                rows(pinned)
            }

            let places = Library.places(among: nodes)
            if !places.isEmpty {
                SectionHeader(label: "地點")
                rows(places)
            }
        }
    }

    private func rows(_ group: [Node]) -> some View {
        ForEach(group) { node in
            NavigationLink(value: Route.container(node)) { ContainerRow(node: node) }
                .buttonStyle(.plain)
        }
    }

    // MARK: - 搜尋

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !trimmedQuery.isEmpty }

    /// 搜尋落空時要猜的位置。
    ///
    /// 算一次就好 —— 它讀的是整份移動歷史，掛在計算屬性上會變成每敲一個字就重掃一遍
    /// （`WhereIsItSheet` 那邊已經踩過同一個坑）。
    ///
    /// 讀不到歷史就不猜：位置留空使用者自己選得到，但把「讀壞了」偽裝成「沒有歷史」
    /// 會讓之後看不出差別。
    private func loadMostRecentContainer() -> Node? {
        do {
            return try Library.recentContainers(excluding: nil, limit: 1, in: context).first
        } catch {
            Self.log.error("讀不到移動歷史，新增物件的位置不預填：\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        let results = Library.search(query, among: nodes)
        if results.isEmpty {
            OpticallyCentred {
                // 顯示與實際建出來的名稱都用修掉空白之後的那一個，
                // 否則按鈕上寫著「建立「腳架 」」而建出來的是「腳架」。
                EmptyStateView(
                    glyph: SearchGlyph(side: Size.iconLg),
                    title: "找不到「\(trimmedQuery)」",
                    message: "這個東西可能還沒建檔。要現在建一筆嗎？"
                ) {
                    // 沒有 GPS 時，「你剛剛才放東西進去的那個容器」是手上最好的猜測。
                    // 見 `docs/SPEC.md` §4.5b。
                    EmptyStateAction(
                        label: "建立「\(trimmedQuery)」",
                        route: .addItem(.named(trimmedQuery, suggested: mostRecentContainer))
                    )
                }
            }
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    SectionHeader(label: "搜尋結果")
                    rows(results)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private static let log = Logger(subsystem: "com.chienchuanw.whereareyou", category: "home")
}
