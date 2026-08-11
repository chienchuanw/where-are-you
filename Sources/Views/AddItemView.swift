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

            VStack(spacing: 0) {
                TextFieldRow(label: "名稱", placeholder: "例如：頭燈", text: $draft.name)

                PickerFieldRow(
                    label: "位置",
                    value: draft.location?.name ?? "不放在任何容器裡",
                    action: { picking = .location }
                )

                PickerFieldRow(label: "歸屬地", value: draft.homeLabel) { picking = .home }

                FilledButton(label: "完成建檔", isEnabled: draft.canSubmit) {
                    if create() { dismiss() }
                }
                // 按鈕緊接在最後一欄下面，不往畫面底部推 —— 這一頁是一連串由上往下
                // 填完就送出的動作，把送出鍵丟到遠處會讓它與最後一欄斷開。
                .padding(.top, Spacing.xxl)

                PlainTextButton(label: "再新增一件", isEnabled: draft.canSubmit) {
                    // 建完留在這一頁，只清掉名稱 —— 位置與歸屬地從頭到尾是同一個答案。
                    if create() { draft.startAnother() }
                }

                Spacer(minLength: 0)
            }
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

    /// 回傳是否真的建出來了。
    private func create() -> Bool {
        guard let created = draft.create(in: context) else { return false }

        do {
            try context.save()
        } catch {
            // 與 §4.2e 的移動同一個已知缺口：存檔失敗目前沒有畫面可以講。
            // 節點已經在記憶體裡了，硬把它抽掉會變成第三種與真實狀態都不符的說法。
            Self.log.error("""
                「\(created.name, privacy: .public)」已經建立，但存不進資料庫，重開 app 後會不見：\
                \(error.localizedDescription, privacy: .public)
                """)
        }
        return true
    }

    private static let log = Logger(subsystem: "com.chienchuanw.whereareyou", category: "add-item")
}
