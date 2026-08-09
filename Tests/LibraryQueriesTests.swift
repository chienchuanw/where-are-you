import Testing
import SwiftData
import Foundation
@testable import WhereAreYou

/// 首頁分組、搜尋、最近使用的容器。語意定義在 `docs/SPEC.md` §4.4b。
@MainActor
struct LibraryQueriesTests {

    struct World {
        let context: ModelContext
        let home: Node
        let study: Node
        let hikingBag: Node
        let workBag: Node
        let cable: Node
        let charger: Node
    }

    /// ```
    /// 家（根）
    ///  └ 書房
    ///     └ 充電線(USB-C 短)
    /// 登山包（根，且釘選）
    /// 上班包（在家底下，釘選）
    ///  └ 充電器 65W
    /// ```
    private func makeWorld() throws -> World {
        let container = try ModelContainer(
            for: Node.self, MoveEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let home = Node(name: "家")
        let study = Node(name: "書房", parent: home)
        let hikingBag = Node(name: "登山包", isPinned: true)
        let workBag = Node(name: "上班包", parent: home, isPinned: true)
        let cable = Node(name: "充電線", parent: study, note: "USB-C 短")
        let charger = Node(name: "充電器", parent: workBag, note: "65W")

        for node in [home, study, hikingBag, workBag, cable, charger] { context.insert(node) }
        return World(context: context, home: home, study: study,
                     hikingBag: hikingBag, workBag: workBag, cable: cable, charger: charger)
    }

    // MARK: - 首頁分組

    @Test("地點只列根節點，依名稱排序")
    func placesAreRootsSortedByName() throws {
        let w = try makeWorld()
        let places = try Library.places(in: w.context)
        #expect(places.map(\.name) == ["家", "登山包"])
    }

    @Test("釘選列出所有被釘的節點，不管在樹的哪一層")
    func pinnedIncludesNonRootNodes() throws {
        let w = try makeWorld()
        let pinned = try Library.pinned(in: w.context)
        #expect(pinned.map(\.name) == ["上班包", "登山包"])
    }

    @Test("既是根節點又被釘選的容器，兩組都會出現")
    func aPinnedRootAppearsInBothSections() throws {
        let w = try makeWorld()
        let places = try Library.places(in: w.context).map(\.name)
        let pinned = try Library.pinned(in: w.context).map(\.name)
        #expect(places.contains("登山包"))
        #expect(pinned.contains("登山包"))
    }

    // MARK: - 搜尋

    @Test("搜尋比對名稱，不分大小寫")
    func searchMatchesNameCaseInsensitively() throws {
        let w = try makeWorld()
        let node = Node(name: "AirPods Pro", parent: w.study)
        w.context.insert(node)
        #expect(try Library.search("airpods", in: w.context).map(\.name) == ["AirPods Pro"])
    }

    @Test("搜尋也比對備註，因為型號常寫在那裡")
    func searchAlsoMatchesTheNote() throws {
        let w = try makeWorld()
        let hits = try Library.search("65W", in: w.context)
        #expect(hits.map(\.name) == ["充電器"])
    }

    @Test("搜尋結果依最近更新排序")
    func searchResultsAreSortedByMostRecentlyUpdated() throws {
        let w = try makeWorld()
        w.cable.updatedAt = Date(timeIntervalSince1970: 100)
        w.charger.updatedAt = Date(timeIntervalSince1970: 200)
        #expect(try Library.search("充電", in: w.context).map(\.name) == ["充電器", "充電線"])

        w.cable.updatedAt = Date(timeIntervalSince1970: 300)
        #expect(try Library.search("充電", in: w.context).map(\.name) == ["充電線", "充電器"])
    }

    @Test("空字串或全空白不回傳任何東西")
    func blankQueryReturnsNothing() throws {
        let w = try makeWorld()
        #expect(try Library.search("", in: w.context).isEmpty)
        #expect(try Library.search("   ", in: w.context).isEmpty)
    }

    // MARK: - 最近使用的容器

    @Test("最近使用的容器取自移動歷史，新的在前")
    func recentContainersComeFromMoveHistory() throws {
        let w = try makeWorld()
        try w.cable.move(to: w.workBag, in: w.context)
        try w.charger.move(to: w.study, in: w.context)

        let recent = try Library.recentContainers(excluding: nil, limit: 5, in: w.context)
        #expect(recent.map(\.name) == ["書房", "上班包"])
    }

    @Test("同一個容器只出現一次")
    func recentContainersAreDeduplicated() throws {
        let w = try makeWorld()
        try w.cable.move(to: w.workBag, in: w.context)
        try w.charger.move(to: w.workBag, in: w.context)

        let recent = try Library.recentContainers(excluding: nil, limit: 5, in: w.context)
        #expect(recent.map(\.name) == ["上班包"])
    }

    @Test("正在檢視的容器不會出現在自己的選項裡")
    func theContainerBeingViewedIsExcluded() throws {
        let w = try makeWorld()
        try w.cable.move(to: w.workBag, in: w.context)
        try w.charger.move(to: w.study, in: w.context)

        let recent = try Library.recentContainers(excluding: w.study, limit: 5, in: w.context)
        #expect(recent.map(\.name) == ["上班包"])
    }

    @Test("移到頂層不會產生一個空的最近項目")
    func movingToRootDoesNotProduceAnEmptyEntry() throws {
        let w = try makeWorld()
        try w.cable.move(to: nil, in: w.context)
        #expect(try Library.recentContainers(excluding: nil, limit: 5, in: w.context).isEmpty)
    }

    @Test("最近使用的容器數量受 limit 限制")
    func recentContainersRespectTheLimit() throws {
        let w = try makeWorld()
        try w.cable.move(to: w.workBag, in: w.context)
        try w.charger.move(to: w.study, in: w.context)

        let recent = try Library.recentContainers(excluding: nil, limit: 1, in: w.context)
        #expect(recent.map(\.name) == ["書房"])
    }
}
