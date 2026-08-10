import Testing
import SwiftData
import Foundation
@testable import WhereAreYou

/// 「它在哪？」sheet 的選項組成。語意定義在 `docs/SPEC.md` §4.3a–§4.3c。
///
/// 斷言一律先算成區域變數再進 `#expect`：`contains {}` / `allSatisfy {}` 這類 rethrows
/// 函式被 macro 展開之後會失去 rethrows 推導，直接寫在 `#expect` 裡編不過。
@MainActor
struct MoveDestinationsTests {

    struct World {
        let context: ModelContext
        let home: Node
        let balcony: Node
        let study: Node
        let drawer: Node
        let hikingBag: Node
        let firstAid: Node
        let bandage: Node
        let headlamp: Node
    }

    /// ```
    /// 家（根）
    ///  └ 陽台
    /// 書房（根）
    ///  └ 書房抽屜
    /// 登山包（根）
    ///  ├ 頭燈
    ///  └ 急救包
    ///     └ 繃帶
    /// ```
    private func makeWorld() throws -> World {
        let container = try ModelContainer(
            for: Node.self, MoveEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let home = Node(name: "家")
        let balcony = Node(name: "陽台", parent: home)
        let study = Node(name: "書房")
        let drawer = Node(name: "書房抽屜", parent: study)
        let hikingBag = Node(name: "登山包")
        let headlamp = Node(name: "頭燈", parent: hikingBag)
        let firstAid = Node(name: "急救包", parent: hikingBag)
        let bandage = Node(name: "繃帶", parent: firstAid)

        for node in [home, balcony, study, drawer, hikingBag, headlamp, firstAid, bandage] {
            context.insert(node)
        }
        return World(context: context, home: home, balcony: balcony, study: study,
                     drawer: drawer, hikingBag: hikingBag, firstAid: firstAid,
                     bandage: bandage, headlamp: headlamp)
    }

    private func allNodes(_ context: ModelContext) throws -> [Node] {
        try context.fetch(FetchDescriptor<Node>())
    }

    // MARK: - 組成與排序（§4.3a）

    @Test("最近用過的排在最前面，其餘依名稱排序")
    func recentComeFirstThenTheRestByName() throws {
        let w = try makeWorld()
        let options = MoveDestinations.options(
            for: w.headlamp,
            among: try allNodes(w.context),
            recent: [w.balcony, w.drawer]
        )

        let recent = Array(options.prefix(2))
        #expect(recent.map(\.name) == ["陽台", "書房抽屜"])
        #expect(recent.map(\.isRecent) == [true, true])

        // 其餘四個（登山包是目前的 parent，被排除）。
        // 順序是 localizedStandardCompare 對中文的實際結果，不是筆畫也不是注音。
        let rest = Array(options.dropFirst(2).dropLast())
        #expect(rest.map(\.name) == ["家", "急救包", "書房", "繃帶"])
        #expect(!rest.map(\.isRecent).contains(true))
    }

    @Test("最後一列固定是「不放在任何容器裡」")
    func theTopLevelOptionIsAlwaysLast() throws {
        let w = try makeWorld()
        let options = MoveDestinations.options(
            for: w.headlamp, among: try allNodes(w.context), recent: []
        )
        #expect(options.last?.node == nil)
        #expect(options.last?.name == "不放在任何容器裡")
    }

    @Test("最近用過的容器不會在下面再出現一次")
    func aRecentContainerIsNotRepeatedInTheRest() throws {
        let w = try makeWorld()
        let options = MoveDestinations.options(
            for: w.headlamp, among: try allNodes(w.context), recent: [w.drawer]
        )
        let occurrences = options.map(\.name).filter { $0 == "書房抽屜" }.count
        #expect(occurrences == 1)
    }

    @Test("沒有子節點的東西也是合法的目的地")
    func aLeafNodeIsStillAValidDestination() throws {
        let w = try makeWorld()
        let options = MoveDestinations.options(
            for: w.headlamp, among: try allNodes(w.context), recent: []
        )
        // 繃帶還沒裝過任何東西，但「筆袋裝第一支筆」的那一次必須選得到它。
        #expect(options.map(\.name).contains("繃帶"))
    }

    // MARK: - 排除規則（§4.3b）

    @Test("自己不會出現在自己的選項裡")
    func theNodeItselfIsExcluded() throws {
        let w = try makeWorld()
        let options = MoveDestinations.options(
            for: w.firstAid, among: try allNodes(w.context), recent: []
        )
        #expect(!options.map(\.name).contains("急救包"))
    }

    @Test("自己的子孫不會出現 —— 循環防呆防在選單這一層")
    func descendantsAreExcluded() throws {
        let w = try makeWorld()
        let options = MoveDestinations.options(
            for: w.hikingBag, among: try allNodes(w.context), recent: []
        )
        let names = options.map(\.name)
        for name in ["登山包", "頭燈", "急救包", "繃帶"] {
            #expect(!names.contains(name))
        }

        // 選單上剩下的每一個都真的移得過去，不會選了才報錯。
        let movable = options.map { w.hikingBag.canMove(to: $0.node) }
        #expect(!movable.contains(false))
    }

    @Test("目前的 parent 不會出現")
    func theCurrentParentIsExcluded() throws {
        let w = try makeWorld()
        let options = MoveDestinations.options(
            for: w.headlamp, among: try allNodes(w.context), recent: []
        )
        #expect(!options.map(\.name).contains("登山包"))
    }

    @Test("目前的 parent 就算最近用過也不會出現")
    func theCurrentParentIsExcludedEvenWhenRecent() throws {
        let w = try makeWorld()
        let options = MoveDestinations.options(
            for: w.headlamp, among: try allNodes(w.context), recent: [w.hikingBag, w.drawer]
        )
        let names = options.map(\.name)
        #expect(names.first == "書房抽屜")
        #expect(!names.contains("登山包"))
    }

    @Test("子孫就算最近用過也不會出現")
    func descendantsAreExcludedEvenWhenRecent() throws {
        let w = try makeWorld()
        let options = MoveDestinations.options(
            for: w.hikingBag, among: try allNodes(w.context), recent: [w.firstAid, w.balcony]
        )
        let names = options.map(\.name)
        #expect(names.first == "陽台")
        #expect(!names.contains("急救包"))
    }

    @Test("本來就在頂層的東西，沒有「不放在任何容器裡」這一列")
    func aTopLevelNodeHasNoTopLevelOption() throws {
        let w = try makeWorld()
        let options = MoveDestinations.options(
            for: w.study, among: try allNodes(w.context), recent: []
        )
        let topLevelRows = options.filter { $0.node == nil }.count
        #expect(topLevelRows == 0)
        #expect(options.last?.node != nil)
    }

    // MARK: - 搜尋（§4.3c）

    @Test("搜尋只列符合的候選，沒有最近用過的標記")
    func searchingListsOnlyMatchesWithoutRecentMarks() throws {
        let w = try makeWorld()
        let options = MoveDestinations.search(
            "書房", for: w.headlamp, among: try allNodes(w.context)
        )
        // 順序由 updatedAt 決定，另有一個測試守著；這裡只看內容。
        #expect(Set(options.map(\.name)) == ["書房", "書房抽屜"])
        #expect(!options.map(\.isRecent).contains(true))
    }

    @Test("搜尋結果一樣套用排除規則")
    func searchingStillAppliesTheExclusions() throws {
        let w = try makeWorld()
        let options = MoveDestinations.search(
            "包", for: w.headlamp, among: try allNodes(w.context)
        )
        // 登山包是目前的 parent，搜尋不該把它變回可選；急救包同樣叫「包」，但它是合法目的地。
        #expect(options.map(\.name) == ["急救包"])
    }

    @Test("搜尋時不出現「不放在任何容器裡」")
    func searchingHasNoTopLevelOption() throws {
        let w = try makeWorld()
        let options = MoveDestinations.search(
            "書房", for: w.headlamp, among: try allNodes(w.context)
        )
        let topLevelRows = options.filter { $0.node == nil }.count
        #expect(topLevelRows == 0)
    }

    @Test("空字串的搜尋不回傳任何東西")
    func blankSearchReturnsNothing() throws {
        let w = try makeWorld()
        let all = try allNodes(w.context)
        #expect(MoveDestinations.search("", for: w.headlamp, among: all).isEmpty)
        #expect(MoveDestinations.search("  ", for: w.headlamp, among: all).isEmpty)
    }

    @Test("搜尋結果依最近更新排序，與首頁的搜尋一致")
    func searchResultsAreSortedByMostRecentlyUpdated() throws {
        let w = try makeWorld()
        w.study.updatedAt = Date(timeIntervalSince1970: 100)
        w.drawer.updatedAt = Date(timeIntervalSince1970: 200)

        let options = MoveDestinations.search(
            "書房", for: w.headlamp, among: try allNodes(w.context)
        )
        #expect(options.map(\.name) == ["書房抽屜", "書房"])
    }
}
