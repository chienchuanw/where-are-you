import SwiftUI

/// 字級 token。名稱與 Figma 的文字樣式（`Text/…`）一一對應。
///
/// **字型現況**：Figma 用 Inter 走拉丁與數字、中文交給系統黑體。Inter 尚未打包進 app，
/// 所以這裡暫時用系統字型搭配相同的字重與尺寸。要換成 Inter 時只需改 `font` 這個計算屬性，
/// 其餘的尺寸、行高、字距都已經與 Figma 對齊，且由 `TokenParityTests` 守著。
public enum TypographyToken: String, CaseIterable, Sendable {
    case largeTitle = "Text/Large Title"
    case title2     = "Text/Title 2"
    case title3     = "Text/Title 3"
    case headline   = "Text/Headline"
    case body       = "Text/Body"
    case subhead    = "Text/Subhead"
    case footnote   = "Text/Footnote"
    /// 徽章專用。與 `footnote` 同尺寸，只差字重 —— 見 `docs/SPEC.md` §9 為什麼不共用。
    case footnoteEmphasis = "Text/Footnote Emphasis"
    case caption    = "Text/Caption"

    public var size: CGFloat {
        switch self {
        case .largeTitle: 30
        case .title2:     21
        case .title3:     19
        case .headline:   17
        case .body:       17
        case .subhead:    14
        case .footnote, .footnoteEmphasis: 13
        case .caption:    12
        }
    }

    public var lineHeight: CGFloat {
        switch self {
        case .largeTitle: 35
        case .title2:     27
        case .title3:     25
        case .headline:   23
        case .body:       23
        case .subhead:    20
        case .footnote, .footnoteEmphasis: 18
        case .caption:    16
        }
    }

    public var tracking: CGFloat {
        switch self {
        case .largeTitle: -0.3
        case .title2:     -0.2
        case .title3:     -0.15
        case .headline:   -0.1
        case .body:       -0.1
        case .subhead:     0
        case .footnote, .footnoteEmphasis: 0
        case .caption:     1.6
        }
    }

    /// Figma 的 Inter 字重字串，例如 `Bold` / `Semi Bold` / `Medium` / `Regular`。
    public var figmaStyle: String {
        switch self {
        case .largeTitle, .title2: "Bold"
        case .title3, .headline, .footnoteEmphasis, .caption: "Semi Bold"
        case .body: "Medium"
        case .subhead, .footnote: "Regular"
        }
    }

    public var weight: Font.Weight {
        switch figmaStyle {
        case "Bold": .bold
        case "Semi Bold": .semibold
        case "Medium": .medium
        default: .regular
        }
    }

    public var font: Font { .system(size: size, weight: weight) }

    /// SwiftUI 的 `lineSpacing` 是「行與行之間額外的距離」，不是行高本身。
    public var lineSpacing: CGFloat { max(0, lineHeight - size) }
}

public extension View {
    /// 套用一個字級 token 的字型、字距與行距。
    func typography(_ token: TypographyToken) -> some View {
        font(token.font)
            .tracking(token.tracking)
            .lineSpacing(token.lineSpacing)
    }
}
