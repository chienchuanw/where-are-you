import SwiftUI
import SwiftData

/// 首頁。對照 Figma `Screens — Light / Home`、`Home — Empty`、`Search — No Results`，
/// 行為見 `docs/SPEC.md` §4.1 與 §4.4b。
struct HomeView: View {
    /// 分組與搜尋的語意只有一份，在 `Library` 裡。這裡拿到整包節點就轉手交給它，
    /// 畫面不重新解讀「哪些算地點」這種問題。
    @Query private var nodes: [Node]

    @State private var query = ""

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
                    message: "先建一個你最常翻的地方 —— 通常是每天出門會帶的那個包。",
                    actionLabel: "建立第一個空間",
                    action: addFirstPlace
                )
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
            NavigationLink(value: node) { ContainerRow(node: node) }
                .buttonStyle(.plain)
        }
    }

    // MARK: - 搜尋

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var searchResults: some View {
        let results = Library.search(query, among: nodes)
        if results.isEmpty {
            OpticallyCentred {
                EmptyStateView(
                    glyph: SearchGlyph(side: Size.iconLg),
                    title: "找不到「\(query)」",
                    message: "這個東西可能還沒建檔。要現在建一筆嗎？",
                    actionLabel: "建立「\(query)」",
                    action: addSearchedItem
                )
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

    // MARK: -

    // TODO: 新增流程（Figma `Item — Add`）不在這一支分支的範圍內，按鈕還沒有去處。
    private func addFirstPlace() {}
    private func addSearchedItem() {}
}
