import SwiftUI

/// Figma 元件頁（`Rows` / `Fields` / `Badge & Button` / `Chrome`）的 SwiftUI 對應。
///
/// 每一支都只用 token 組成：顏色、間距、圓角、字級一律走 `Color.*` / `Spacing.*` /
/// `Radius.*` / `Size.*` / `.typography(_:)`，不出現任何裸數字。

// MARK: - Chrome

/// 大標題列。被推進去的畫面在標題上方帶返回鍵，首頁沒有。見 `docs/SPEC.md` §4.0。
///
/// Figma 的 `NavBar/Style=LargeTitle` 上方留了 52pt 給狀態列。程式碼這邊不複製那個數字 ——
/// 真實裝置的安全區高度各機不同，交給系統的 safe area 才會對。
struct LargeTitleBar: View {
    let title: String
    var onBack: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let onBack {
                Button(action: onBack) {
                    ChevronLeftGlyph(side: Size.iconSm, tint: .accent)
                        .frame(width: Size.touchMin, height: Size.touchMin)
                        .contentShape(Rectangle())
                }
                // 觸控範圍撐到 44pt，但版面上仍只佔字符本身的 20pt，
                // 否則大標題會被推離 Figma 的位置。
                .frame(width: Size.iconSm, height: Size.iconSm)
                .accessibilityLabel("返回")
            }

            Text(title)
                .typography(.largeTitle)
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.xxl)
        .padding(.bottom, Spacing.xs)
    }
}

/// 置中標題列。對照 Figma `NavBar/Style=Inline`。
///
/// 一次性的任務用這個而不是大標題：標題只需要說明「你正在做什麼」，
/// 不像盤點頁的容器名稱是那一頁最重要的一行字（§4.0）。
struct InlineTitleBar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Button(action: onBack) {
                ChevronLeftGlyph(side: Size.iconSm, tint: .accent)
                    .frame(width: Size.touchMin, height: Size.touchMin)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: Size.iconSm, height: Size.iconSm)
            .accessibilityLabel("返回")

            Text(title)
                .typography(.headline)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)

            // 右側留一個等寬的空位，標題才會真的置中。Figma 的 `trailing` 就是這個。
            Color.clear.frame(width: Size.iconSm, height: Size.iconSm)
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.bottom, Spacing.md)
    }
}

// MARK: - Fields

/// 表單列的底線。
///
/// 線寬不是設計 token —— 與 `Glyphs.swift` 的字符線寬同一類，屬於美術資產。
/// `docs/SPEC.md` §9 也已經講明它是刻意不合規的裝飾性邊界，不承載狀態辨識。
private struct FieldSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.borderSeparator)
            .frame(height: 1)
    }
}

private struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .typography(.caption)
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 表單列（Figma `FieldRow/Type=Text`）：標籤在上、可編輯的值在下。
struct TextFieldRow: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            FieldLabel(text: label)

            TextField(text: $text) {
                Text(placeholder).foregroundStyle(Color.textTertiary)
            }
            .typography(.body)
            .foregroundStyle(Color.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding(.vertical, Spacing.lg)
        .overlay(alignment: .bottom) { FieldSeparator() }
    }
}

/// 表單列（Figma `FieldRow/Type=Picker`）：右側帶「更改」提示，無 chevron。
struct PickerFieldRow: View {
    let label: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                FieldLabel(text: label)

                HStack(spacing: Spacing.sm) {
                    Text(value)
                        .typography(.body)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("更改")
                        .typography(.subhead)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.vertical, Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { FieldSeparator() }
    }
}

struct SearchField: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            SearchGlyph(side: Size.iconSm, tint: .textSecondary)

            TextField(text: $text) {
                Text(placeholder).foregroundStyle(Color.textTertiary)
            }
            .typography(.body)
            .foregroundStyle(Color.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: Size.touchMin)
        .background(Color.bgField, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

// MARK: - Rows

/// 群組標籤。零分隔線的版面裡，它是唯一的分組訊號，所以字距開到 1.6 而不是靠亮度差。
struct SectionHeader: View {
    let label: String

    var body: some View {
        Text(label)
            .typography(.caption)
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.xl)
    }
}

struct MissingBadge: View {
    let count: Int

    var body: some View {
        Text("缺 \(count)")
            .typography(.footnoteEmphasis)
            .foregroundStyle(Color.textDanger)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color.bgDangerSubtle, in: Capsule())
    }
}

/// 首頁的容器列：名稱、遞迴件數、缺件徽章。無 chevron —— 整列就是觸控目標。
struct ContainerRow: View {
    let node: Node

    var body: some View {
        let missing = node.missingCount

        HStack(spacing: Spacing.sm) {
            Text(node.name)
                .typography(.body)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(node.subtreeCount) 件")
                .typography(.subhead)
                .foregroundStyle(Color.textSecondary)

            if missing > 0 { MissingBadge(count: missing) }
        }
        .frame(minHeight: Size.row)
        .contentShape(Rectangle())
    }
}

/// 盤點頁的物件列：狀態記號、名稱、副標。副標只在「缺」與「外來」時出現。
///
/// 這一列有**兩個**觸控目標，不是一個：記號負責切換「在／不在」（見 `docs/SPEC.md` §4.2e），
/// 名稱那一段負責推進到子容器的盤點頁。合成一個的話，出門前想核對的人每點一次就會被
/// 推進下一頁，而那正是他最不想發生的事。
struct ItemRow: View {
    let row: InventoryRow
    /// 這一列的記號按下去該做什麼。`.unavailable` 時記號照畫，但不給觸控目標。
    let action: ToggleAction
    /// 有子節點的東西在 UI 上就是容器，點名稱進得去；缺件也要進得去 ——
    /// 那正是你要去確認它跑到哪的時候。
    let isNavigable: Bool
    let onToggle: () -> Void

    var body: some View {
        // 間距由記號那一塊自己吃掉，這樣它的觸控範圍剛好停在名稱開始的地方。
        HStack(spacing: 0) {
            toggle

            if isNavigable {
                NavigationLink(value: Route.container(row.node)) { label }
                    .buttonStyle(.plain)
            } else {
                label
            }
        }
        .frame(minHeight: Size.row)
    }

    /// 記號的觸控範圍是「字符 + 它與名稱之間的間距」寬、整列高。
    ///
    /// 刻意**不**撐成 44pt 寬：那會往左溢出到頁面的 24pt 內距裡，而那片空白正是捲動時
    /// 手指落下的地方。這顆按鈕做的是沒有確認、也沒有復原的寫入（`docs/SPEC.md` §4.2e），
    /// 誤觸的代價比目標窄一點高。`LargeTitleBar` 的返回鍵可以溢出，因為按錯只是回上一頁。
    @ViewBuilder
    private var toggle: some View {
        let glyph = StatusGlyph(status: row.status, side: Size.iconSm)
            .frame(width: Size.iconSm + Spacing.md, height: Size.row, alignment: .leading)

        if action == .unavailable {
            // 按了一定會失敗的控制項不該是可按的。記號本身照畫 —— 那個狀態是真的。
            glyph
        } else {
            Button(action: onToggle) {
                glyph.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(row.node.name)
                .typography(.body)
                .foregroundStyle(Color.textPrimary)

            if let subtitle = row.subtitle {
                Text(subtitle)
                    .typography(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        // 高度要撐滿整列，否則導覽的觸控目標只有文字本身那二十幾點，
        // 看起來是 56pt 的一列、實際上上下都是死區。
        .frame(maxWidth: .infinity, minHeight: Size.row, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// 「它在哪？」sheet 的一列選項。右側的「最近用過」是一句補充，不是一個分類 ——
/// 見 `docs/SPEC.md` §4.3a 為什麼不用區段標題把兩組分開。
struct DestinationRow: View {
    let destination: MoveDestination

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(destination.name)
                .typography(.body)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if destination.isRecent {
                Text("最近用過")
                    .typography(.subhead)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(minHeight: Size.row)
        .contentShape(Rectangle())
    }
}

// MARK: - Badge & Button

/// Figma `Button/Style=Tinted` 的外觀。拆成獨立的一支，是因為空狀態的動作是導覽，
/// 掛在 `NavigationLink` 上，那裡要的是一個 label 而不是一顆 `Button`。
struct TintedButtonLabel: View {
    let label: String

    var body: some View {
        Text(label)
            .typography(.headline)
            .foregroundStyle(Color.textAccent)
            .padding(.horizontal, Spacing.xl)
            .frame(height: Size.button)
            .background(
                Color.bgAccentSubtle,
                in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
            )
    }
}

struct TintedButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { TintedButtonLabel(label: label) }
    }
}

/// Figma `Button/Style=Filled`：主要動作，撐滿寬度。
///
/// `State=Disabled` 的底走 `bg/field`、字走 `text/tertiary`。不可按是新增物件那一頁的
/// 初始狀態而不是例外狀態（§4.5a），所以它有正式的樣式，不是把畫面調淡了事。
struct FilledButton: View {
    let label: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .typography(.headline)
                .foregroundStyle(isEnabled ? Color.textOnAccent : Color.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: Size.button)
                .background(
                    isEnabled ? Color.accent : Color.bgField,
                    in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                )
        }
        .disabled(!isEnabled)
    }
}

/// Figma `Button/Style=Plain`：文字動作，沒有底。
struct PlainTextButton: View {
    let label: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .typography(.headline)
                .foregroundStyle(isEnabled ? Color.textAccent : Color.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: Size.button)
                .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
    }
}

// MARK: - EmptyState

/// 把空狀態放在剩下的空間裡，重心偏上。
///
/// Figma 是用固定高度的 spacer 把它頂到那個位置的，那個數字沒有對應的 token，
/// 換一個機身高度也就不成立。這裡改成按比例分配：幾何正中央看起來會偏低，
/// 上一份、下兩份才落在 Figma 那個位置。
struct OpticallyCentred<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Spacing.xxxl)
            content
            Spacer(minLength: Spacing.xxxl)
            Spacer(minLength: 0)
        }
    }
}

/// 空狀態。動作那一格是插槽 —— 三個空狀態的動作全部是「去新增物件那一頁」，
/// 而導覽在 SwiftUI 裡是 `NavigationLink`，不是一顆按下去執行閉包的 `Button`。
struct EmptyStateView<Glyph: View, Action: View>: View {
    let glyph: Glyph
    let title: String
    let message: String
    @ViewBuilder let action: Action

    var body: some View {
        VStack(spacing: Spacing.md) {
            glyph
                .frame(width: Size.iconHolder, height: Size.iconHolder)
                .background(
                    Color.bgField,
                    in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                )

            Text(title)
                .typography(.title3)
                .foregroundStyle(Color.textPrimary)

            Text(message)
                .typography(.subhead)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            action
                .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xxxl)
    }
}

/// 空狀態的動作：長得像 Tinted 按鈕的導覽連結。
struct EmptyStateAction: View {
    let label: String
    let route: Route

    var body: some View {
        NavigationLink(value: route) { TintedButtonLabel(label: label) }
            .buttonStyle(.plain)
    }
}
