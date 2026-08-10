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
        } catch let original {
            let outcome = setAsideExistingStore()

            // 搬到一半就停住的話不能接著開 —— 新 store 會生在殘留的 -wal 旁邊，
            // 然後把舊的未提交交易重播進一個全新的資料庫。那比當掉還糟。
            guard outcome.failed.isEmpty else {
                fatalError("""
                    資料庫讀不動，而舊檔只搬走了一部分，不敢接著開新的。
                    原始錯誤：\(original)
                    搬不動：\(outcome.failed.joined(separator: ", "))
                    已搬走：\(describe(outcome.moved))
                    """)
            }

            do {
                let container = try openStore()
                log.error("""
                    資料庫讀不動，已改用新建的 store。原始錯誤：\(original.localizedDescription, privacy: .public)
                    舊檔移到：\(describe(outcome.moved), privacy: .public)
                    """)
                return container
            } catch let afterMoving {
                // 移開舊檔之後還是開不起來，那就不是舊資料的問題了。
                //
                // 兩個錯誤都要印。真正說明「為什麼壞掉」的是 original ——
                // afterMoving 講的是一個全新的空 store 也開不起來，那通常只是同一個
                // 環境問題的回音。只印後者的話，最有用的那條線索會被丟掉。
                fatalError("""
                    資料庫開不起來。
                    原始錯誤：\(original)
                    移開舊檔後再開一次仍然失敗：\(afterMoving)
                    舊檔處置：\(describe(outcome.moved))
                    """)
            }
        }
    }

    /// 把搬走的檔案講成人話。空的時候要說「一個都沒搬」而不是印出一對空括號 ——
    /// 「已移到 []」會讓人以為搬過了，但真正的情況是連目錄都沒摸到。
    static func describe(_ movedAside: [URL]) -> String {
        movedAside.isEmpty
            ? "沒有搬走任何檔案（本來就沒有舊 store，或是連 Application Support 都取不到）"
            : movedAside.map(\.lastPathComponent).joined(separator: ", ")
    }

    static func openStore() throws -> ModelContainer {
        let container = try ModelContainer(for: Node.self, MoveEvent.self)
        #if DEBUG
        SampleData.seedIfEmpty(ModelContext(container))
        #endif
        return container
    }

    /// 搬移的結果。`failed` 不是空的就代表搬到一半停住了 —— 那時**不可以**接著開新 store。
    struct SetAsideOutcome {
        var moved: [URL] = []
        var failed: [String] = []
    }

    /// 把現有的 store 檔搬到帶時間戳的備份名下。
    ///
    /// **只搬不刪。** 沒有雲端備份的情況下，一次啟動失敗不該蒸發資料 ——
    /// 與 `docs/SPEC.md` §7 的刪除語意同一條理由。
    static func setAsideExistingStore() -> SetAsideOutcome {
        let fileManager = FileManager.default
        let directory: URL
        do {
            directory = try fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
            )
        } catch {
            // 取不到目錄跟「沒有舊檔可搬」是兩件完全不同的事，但兩者都會讓這個函式
            // 回傳空陣列。不講出來的話，接下來那個必然失敗的重試會看起來像是
            // 「復原試過了，還是壞的」，真正的環境問題（權限、沙盒）反而被藏起來。
            log.error("取不到 Application Support 目錄，沒有任何舊檔被搬走：\(error.localizedDescription, privacy: .public)")
            return SetAsideOutcome()
        }

        // 冒號在檔名裡會被 Finder 顯示成斜線，換掉比較好認。
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")

        // SQLite 的 write-ahead log 與 shared memory 檔要跟著搬，
        // 只搬主檔的話新 store 會撿到舊的未提交交易。三個檔是一組，搬一半等於沒搬。
        var outcome = SetAsideOutcome()
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            let source = directory.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: source.path) else { continue }

            let destination = directory.appendingPathComponent("\(name).\(stamp).bak")
            do {
                try fileManager.moveItem(at: source, to: destination)
                outcome.moved.append(destination)
            } catch {
                log.error("搬不動 \(name, privacy: .public)：\(error.localizedDescription, privacy: .public)")
                outcome.failed.append(name)
            }
        }
        return outcome
    }
}
