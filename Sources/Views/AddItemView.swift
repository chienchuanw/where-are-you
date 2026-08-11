import SwiftUI
import SwiftData
import OSLog

/// 新增物件。對照 Figma `Screens — Light / Item — Add` 與 `Item — Add — Empty`，
/// 行為見 `docs/SPEC.md` §4.5。
///
/// 表單的規則（名稱必填、歸屬地跟著位置走）都在 `NewItemDraft` 裡，有測試守著。
/// 這一支只負責把它畫出來、把兩顆按鈕接上去。
struct AddItemView: View {
    @State var draft: NewItemDraft

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// 正在選哪一個欄位。`nil` 代表沒有在選。
    @State private var picking: Field?

    /// 已經按下去、正在建的那一次。`dismiss()` 不是同步移除畫面，少了這道閘，
    /// 連按兩下會建出兩筆一模一樣的資料。
    @State private var isCreating = false

    private enum Field: Identifiable {
        case location, home
        var id: Self { self }

        /// 兩者用同一支 sheet，只換標題。見 `docs/SPEC.md` §4.5d。
        var sheetTitle: String {
            switch self {
            case .location: "放在哪？"
            case .home: "歸屬在哪？"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            InlineTitleBar(title: "新增物件") { dismiss() }

            // 名稱欄一定會叫出鍵盤，而這一頁的送出鍵在最下面。機身矮一點的裝置上，
            // 沒有 ScrollView 就等於這個流程走不完。
            ScrollView {
                VStack(spacing: 0) {
                    TextFieldRow(label: "名稱", placeholder: "例如：頭燈", text: $draft.name)

                    PickerFieldRow(label: "位置", value: draft.locationLabel) { picking = .location }
                    PickerFieldRow(label: "歸屬地", value: draft.homeLabel) { picking = .home }

                    FilledButton(label: "完成建檔", isEnabled: isSubmittable) {
                        if create() { dismiss() }
                    }
                    // 按鈕緊接在最後一欄下面，不往畫面底部推 —— 這一頁是一連串由上往下
                    // 填完就送出的動作，把送出鍵丟到遠處會讓它與最後一欄斷開。
                    .padding(.top, Spacing.xxl)

                    PlainTextButton(label: "再新增一件", isEnabled: isSubmittable) {
                        // 建完留在這一頁，只清掉名稱 —— 位置與歸屬地從頭到尾是同一個答案。
                        if create() {
                            draft.startAnother()
                            isCreating = false
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .padding(.horizontal, Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bgGrouped)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $picking) { field in
            // 還不存在的東西沒有自己與子孫要排除，所以 node 傳 nil。
            WhereIsItSheet(title: field.sheetTitle, node: nil) { picked in
                switch field {
                case .location: draft.setLocation(picked)
                case .home: draft.setHome(picked)
                }
                picking = nil
            }
        }
    }

    // MARK: -

    private var isSubmittable: Bool { draft.canSubmit && !isCreating }

    /// 回傳是否真的建出來、而且存進去了。
    private func create() -> Bool {
        guard !isCreating else { return false }
        isCreating = true

        guard let created = draft.create(in: context) else {
            isCreating = false
            return false
        }

        do {
            try context.save()
        } catch {
            // 存檔失敗就當作沒建過：把節點與那筆歷史一起收回，留在這一頁。
            // 不收回的話這一頁會表演出一次成功 —— 畫面退回去、或名稱欄清空讓你接著建
            // 下一件 —— 使用者於是連續建了八件，八件全部沒有落地。見 `docs/SPEC.md` §4.5c。
            NewItemDraft.rollBack(created, in: context)
            isCreating = false

            Self.log.error("""
                「\(created.name, privacy: .public)」存不進資料庫，已經收回，什麼都沒有建立：\
                \(error.localizedDescription, privacy: .public)
                """)
            return false
        }
        return true
    }

    private static let log = Logger(subsystem: "com.chienchuanw.whereareyou", category: "add-item")
}
