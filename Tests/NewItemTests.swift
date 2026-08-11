import Testing
import SwiftData
import Foundation
@testable import WhereAreYou

/// 新增物件表單的狀態與寫入。語意定義在 `docs/SPEC.md` §4.5a–§4.5c。
@MainActor
struct NewItemTests {

    struct World {
        let context: ModelContext
        let hikingBag: Node
        let drawer: Node
    }

    private func makeWorld() throws -> World {
        let container = try ModelContainer(
            for: Node.self, MoveEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let hikingBag = Node(name: "登山包")
        let drawer = Node(name: "書房抽屜")
        context.insert(hikingBag); context.insert(drawer)
        return World(context: context, hikingBag: hikingBag, drawer: drawer)
    }

    // MARK: - 名稱（§4.5a）

    @Test("名稱沒填就不能建檔")
    func aBlankNameCannotBeSubmitted() throws {
        let w = try makeWorld()
        var draft = NewItemDraft(location: w.hikingBag)

        #expect(!draft.canSubmit)

        // 只有空白字元一樣算沒填 —— 名稱是識別主鍵，一筆叫「   」的資料誰都認不出來。
        draft.name = "   "
        #expect(!draft.canSubmit)

        draft.name = "頭燈"
        #expect(draft.canSubmit)
    }

    @Test("名稱沒填時 create 什麼都不做")
    func creatingWithABlankNameDoesNothing() throws {
        let w = try makeWorld()
        var draft = NewItemDraft(location: w.hikingBag)
        draft.name = "  "

        #expect(draft.create(in: w.context) == nil)
        #expect(try w.context.fetchCount(FetchDescriptor<Node>()) == 2)
        #expect(try w.context.fetchCount(FetchDescriptor<MoveEvent>()) == 0)
    }

    // MARK: - 「同位置」（§4.5a）

    @Test("歸屬地預設是「同位置」，跟著位置走")
    func homeFollowsLocationUntilItIsSetByHand() throws {
        let w = try makeWorld()
        var draft = NewItemDraft(location: w.hikingBag)

        #expect(draft.homeLabel == "同位置")
        #expect(draft.home === w.hikingBag)

        draft.setLocation(w.drawer)
        #expect(draft.home === w.drawer)
        #expect(draft.homeLabel == "同位置")
    }

    @Test("使用者自己選過歸屬地之後，改位置不會再覆蓋它")
    func anExplicitHomeIsNotOverwrittenByLaterLocationChanges() throws {
        let w = try makeWorld()
        var draft = NewItemDraft(location: w.hikingBag)

        draft.setHome(w.drawer)
        #expect(draft.homeLabel == "書房抽屜")

        // 「先設好歸屬地、再改位置」就是「這件東西現在暫時放在別的地方」的建檔情境。
        draft.setLocation(w.hikingBag)
        #expect(draft.home === w.drawer)
        #expect(draft.homeLabel == "書房抽屜")
    }

    @Test("把歸屬地選成「不放在任何容器裡」也算使用者選過")
    func choosingNoHomeCountsAsExplicit() throws {
        let w = try makeWorld()
        var draft = NewItemDraft(location: w.hikingBag)

        draft.setHome(nil)
        #expect(draft.home == nil)
        #expect(draft.homeLabel == "不放在任何容器裡")

        draft.setLocation(w.drawer)
        #expect(draft.home == nil)
    }

    // MARK: - 三個入口（§4.5b）

    @Test("從盤點頁進來，位置預填那個容器")
    func comingFromAContainerPrefillsThatContainer() throws {
        let w = try makeWorld()
        let draft = NewItemDraft(.into(w.hikingBag))

        #expect(draft.name.isEmpty)
        #expect(draft.location === w.hikingBag)
        #expect(draft.home === w.hikingBag)
    }

    @Test("從首頁空狀態進來，建的是頂層的空間")
    func comingFromTheEmptyHomeCreatesATopLevelPlace() throws {
        let draft = NewItemDraft(.firstPlace)

        #expect(draft.name.isEmpty)
        #expect(draft.location == nil)
        #expect(draft.home == nil)
    }

    @Test("從搜尋無結果進來，名稱帶入搜尋字串、位置猜最近用過的")
    func comingFromAnEmptySearchCarriesTheQueryAndGuessesTheLocation() throws {
        let w = try makeWorld()
        let draft = NewItemDraft(.named("腳架", suggested: w.drawer))

        #expect(draft.name == "腳架")
        #expect(draft.canSubmit)
        #expect(draft.location === w.drawer)
    }

    @Test("沒有最近用過的容器時，搜尋帶進來的位置留空")
    func withNoRecentContainerTheLocationIsLeftEmpty() throws {
        let draft = NewItemDraft(.named("腳架", suggested: nil))

        #expect(draft.name == "腳架")
        #expect(draft.location == nil)
    }

    // MARK: - 寫入（§4.5c）

    @Test("建檔會寫一筆 from 為空的歷史")
    func creatingWritesACreationEvent() throws {
        let w = try makeWorld()
        var draft = NewItemDraft(.into(w.hikingBag))
        draft.name = "頭燈"

        let created = try #require(draft.create(in: w.context))
        #expect(created.name == "頭燈")
        #expect(created.parent === w.hikingBag)
        #expect(created.home === w.hikingBag)

        let events = try w.context.fetch(FetchDescriptor<MoveEvent>())
        let event = try #require(events.first { $0.nodeName == "頭燈" })
        // fromName 為空字串代表建檔，見 `docs/SPEC.md` §2.2。
        #expect(event.fromName == "")
        #expect(event.from == nil)
        #expect(event.toName == "登山包")
    }

    @Test("名稱前後的空白會被修掉")
    func theNameIsTrimmed() throws {
        let w = try makeWorld()
        var draft = NewItemDraft(.into(w.hikingBag))
        draft.name = "  頭燈  "

        let created = try #require(draft.create(in: w.context))
        #expect(created.name == "頭燈")
    }

    @Test("建檔會把容器標記成剛動過")
    func creatingTouchesTheContainer() throws {
        let w = try makeWorld()
        w.hikingBag.updatedAt = Date(timeIntervalSince1970: 0)

        var draft = NewItemDraft(.into(w.hikingBag))
        draft.name = "頭燈"
        _ = draft.create(in: w.context)

        // 容器的內容變了。與 §4.2d 的移動同一條理由：盤點頁的標頭不能在剛被寫入之後
        // 還顯示舊日期。
        #expect(w.hikingBag.updatedAt > Date(timeIntervalSince1970: 0))
    }

    @Test("建在頂層的東西沒有 parent，歷史的 to 也是空的")
    func creatingAtTopLevelLeavesNoParent() throws {
        let w = try makeWorld()
        var draft = NewItemDraft(.firstPlace)
        draft.name = "家"

        let created = try #require(draft.create(in: w.context))
        #expect(created.parent == nil)
        #expect(created.home == nil)

        let event = try #require(
            try w.context.fetch(FetchDescriptor<MoveEvent>()).first { $0.nodeName == "家" }
        )
        #expect(event.toName == "")
    }

    @Test("「再新增一件」只清掉名稱，位置與歸屬地留著")
    func startingAnotherKeepsTheLocation() throws {
        let w = try makeWorld()
        var draft = NewItemDraft(.into(w.hikingBag))
        draft.setHome(w.drawer)
        draft.name = "頭燈"
        _ = draft.create(in: w.context)

        draft.startAnother()

        #expect(draft.name.isEmpty)
        #expect(!draft.canSubmit)
        // 「把登山包裡八件裝備一次建完」時，位置與歸屬地從頭到尾是同一個答案。
        #expect(draft.location === w.hikingBag)
        #expect(draft.home === w.drawer)
        #expect(draft.homeLabel == "書房抽屜")
    }

    // MARK: - 選擇器（§4.5d）

    @Test("還不存在的東西沒有要排除的節點，但仍然選得到頂層")
    func destinationsForANewItemExcludeNothing() throws {
        let w = try makeWorld()
        let all = try w.context.fetch(FetchDescriptor<Node>())

        let options = MoveDestinations.options(for: nil, among: all, recent: [])
        #expect(options.map(\.name) == ["書房抽屜", "登山包", "不放在任何容器裡"])
    }
}
