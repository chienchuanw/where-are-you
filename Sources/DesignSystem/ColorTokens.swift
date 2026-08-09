import SwiftUI
import UIKit

/// 顏色 token。**唯一真相來源是 Figma**（檔案 a6S9XlccNqWHC8jJZ63kh6 的 `Color` collection）。
///
/// 這裡的名稱與 Figma 變數的 iOS code syntax 一字不差。改任何一個值之前，
/// 先改 Figma 變數、重新匯出 `Resources/figma-tokens.json`，再讓 `TokenParityTests` 帶你改到一致。
public enum ColorToken: String, CaseIterable, Sendable {
    case accent           = "Color.accent"
    case bgAccentSubtle   = "Color.bgAccentSubtle"
    case bgDangerSubtle   = "Color.bgDangerSubtle"
    case bgElevated       = "Color.bgElevated"
    case bgField          = "Color.bgField"
    case bgGrouped        = "Color.bgGrouped"
    case bgSurface        = "Color.bgSurface"
    case borderField      = "Color.borderField"
    case borderSeparator  = "Color.borderSeparator"
    case stateForeign     = "Color.stateForeign"
    case stateMissing     = "Color.stateMissing"
    case stateOk          = "Color.stateOk"
    case textAccent       = "Color.textAccent"
    case textDanger       = "Color.textDanger"
    case textOnAccent     = "Color.textOnAccent"
    case textPrimary      = "Color.textPrimary"
    case textSecondary    = "Color.textSecondary"
    case textTertiary     = "Color.textTertiary"

    /// Light / Dark 兩個 mode 的 RGB 值，與 Figma 的 Color collection 對應。
    public var values: (light: UInt32, dark: UInt32) {
        switch self {
        case .accent:          (0x2F6F4E, 0x4CAF7D)
        case .bgAccentSubtle:  (0xE9F1EC, 0x132219)
        case .bgDangerSubtle:  (0xFCEBEA, 0x2A1412)
        case .bgElevated:      (0xFFFFFF, 0x16191A)
        case .bgField:         (0xF3F4F5, 0x17191B)
        case .bgGrouped:       (0xFFFFFF, 0x0B0C0D)
        case .bgSurface:       (0xFFFFFF, 0x0B0C0D)
        case .borderField:     (0xEDEEEF, 0x212426)
        case .borderSeparator: (0xEDEEEF, 0x212426)
        case .stateForeign:    (0x6F757B, 0x8A9198)
        case .stateMissing:    (0xC9251C, 0xFF6F63)
        case .stateOk:         (0x2F6F4E, 0x4CAF7D)
        case .textAccent:      (0x2F6F4E, 0x4CAF7D)
        case .textDanger:      (0xC9251C, 0xFF6F63)
        case .textOnAccent:    (0xFFFFFF, 0x0B0C0D)
        case .textPrimary:     (0x111315, 0xF2F4F4)
        case .textSecondary:   (0x6B7278, 0x9BA1A8)
        case .textTertiary:    (0x6F757B, 0x8A9198)
        }
    }

    public var uiColor: UIColor {
        let (light, dark) = values
        return UIColor { trait in
            UIColor(rgb: trait.userInterfaceStyle == .dark ? dark : light)
        }
    }

    public var color: Color { Color(uiColor: uiColor) }
}

public extension Color {
    static var accent: Color          { ColorToken.accent.color }
    static var bgAccentSubtle: Color  { ColorToken.bgAccentSubtle.color }
    static var bgDangerSubtle: Color  { ColorToken.bgDangerSubtle.color }
    static var bgElevated: Color      { ColorToken.bgElevated.color }
    static var bgField: Color         { ColorToken.bgField.color }
    static var bgGrouped: Color       { ColorToken.bgGrouped.color }
    static var bgSurface: Color       { ColorToken.bgSurface.color }
    static var borderField: Color     { ColorToken.borderField.color }
    static var borderSeparator: Color { ColorToken.borderSeparator.color }
    static var stateForeign: Color    { ColorToken.stateForeign.color }
    static var stateMissing: Color    { ColorToken.stateMissing.color }
    static var stateOk: Color         { ColorToken.stateOk.color }
    static var textAccent: Color      { ColorToken.textAccent.color }
    static var textDanger: Color      { ColorToken.textDanger.color }
    static var textOnAccent: Color    { ColorToken.textOnAccent.color }
    static var textPrimary: Color     { ColorToken.textPrimary.color }
    static var textSecondary: Color   { ColorToken.textSecondary.color }
    static var textTertiary: Color    { ColorToken.textTertiary.color }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue:  CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
