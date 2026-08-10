import SwiftUI
import SwiftData

@main
struct WhereAreYouApp: App {
    /// MVP 只存本機。模型從第一天就守 CloudKit 的相容規則，之後開同步不必遷移，
    /// 見 `docs/SPEC.md` §2.3。
    private let container: ModelContainer = {
        do {
            let container = try ModelContainer(for: Node.self, MoveEvent.self)
            #if DEBUG
            SampleData.seedIfEmpty(ModelContext(container))
            #endif
            return container
        } catch {
            fatalError("開不了資料庫：\(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
