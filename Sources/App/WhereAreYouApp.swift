import SwiftUI
import SwiftData
import OSLog

@main
struct WhereAreYouApp: App {
    private let container = Self.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

private extension WhereAreYouApp {

    static let log = Logger(subsystem: "com.chienchuanw.whereareyou", category: "store")

    /// MVP 只存本機。模型從第一天就守 CloudKit 的相容規則，之後開同步不必遷移，
    /// 見 `docs/SPEC.md` §2.3。
    ///
    /// 開不起來時把舊 store 移到旁邊再開一次，而不是當掉 —— schema 還在長的階段，
    /// 裝置上留著舊 schema 寫出來的 store 是常態。見 `docs/SPEC.md` §8。
    static func makeContainer() -> ModelContainer {
        do {
            return try openStore()
        } catch {
            let movedAside = setAsideExistingStore()
            do {
                let container = try openStore()
                log.error("""
                    資料庫讀不動，已改用新建的 store。原始錯誤：\(error.localizedDescription, privacy: .public)
                    舊檔移到：\(movedAside.map(\.lastPathComponent).joined(separator: ", "), privacy: .public)
                    """)
                return container
            } catch {
                // 移開舊檔之後還是開不起來，那就不是舊資料的問題了。
                fatalError("資料庫開不起來（舊檔已移到 \(movedAside.map(\.lastPathComponent))）：\(error)")
            }
        }
    }

    static func openStore() throws -> ModelContainer {
        let container = try ModelContainer(for: Node.self, MoveEvent.self)
        #if DEBUG
        SampleData.seedIfEmpty(ModelContext(container))
        #endif
        return container
    }

    /// 把現有的 store 檔搬到帶時間戳的備份名下，回傳實際搬走的檔案。
    ///
    /// **只搬不刪。** 沒有雲端備份的情況下，一次啟動失敗不該蒸發資料 ——
    /// 與 `docs/SPEC.md` §7 的刪除語意同一條理由。
    static func setAsideExistingStore() -> [URL] {
        let fileManager = FileManager.default
        guard let directory = try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return [] }

        // 冒號在檔名裡會被 Finder 顯示成斜線，換掉比較好認。
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")

        // SQLite 的 write-ahead log 與 shared memory 檔要跟著搬，
        // 只搬主檔的話新 store 會撿到舊的未提交交易。
        return ["default.store", "default.store-shm", "default.store-wal"].compactMap { name in
            let source = directory.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: source.path) else { return nil }

            let destination = directory.appendingPathComponent("\(name).\(stamp).bak")
            do {
                try fileManager.moveItem(at: source, to: destination)
                return destination
            } catch {
                log.error("搬不動 \(name, privacy: .public)：\(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
    }
}
