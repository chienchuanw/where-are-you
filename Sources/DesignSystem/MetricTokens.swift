import CoreGraphics

/// 間距 token。名稱與 Figma `Spacing` collection 的 iOS code syntax 一字不差。
public enum Spacing {
    public static let xxs:  CGFloat = 2
    public static let xs:   CGFloat = 4
    public static let sm:   CGFloat = 8
    public static let md:   CGFloat = 12
    public static let lg:   CGFloat = 16
    public static let xl:   CGFloat = 20
    public static let xxl:  CGFloat = 24
    public static let xxxl: CGFloat = 32

    static let table: [String: CGFloat] = [
        "Spacing.xxs": xxs, "Spacing.xs": xs, "Spacing.sm": sm, "Spacing.md": md,
        "Spacing.lg": lg, "Spacing.xl": xl, "Spacing.xxl": xxl, "Spacing.xxxl": xxxl,
    ]
}

/// 圓角 token。名稱與 Figma `Radius` collection 對應。
public enum Radius {
    public static let sm:     CGFloat = 8
    public static let md:     CGFloat = 12
    public static let button: CGFloat = 14
    public static let lg:     CGFloat = 16
    public static let xl:     CGFloat = 22
    public static let full:   CGFloat = 999

    static let table: [String: CGFloat] = [
        "Radius.sm": sm, "Radius.md": md, "Radius.button": button,
        "Radius.lg": lg, "Radius.xl": xl, "Radius.full": full,
    ]
}

/// 尺寸 token。名稱與 Figma `Size` collection 對應。
public enum Size {
    public static let iconSm:   CGFloat = 20
    public static let iconMd:   CGFloat = 24
    public static let iconLg:   CGFloat = 28
    public static let thumb:    CGFloat = 40
    public static let rowMin:   CGFloat = 44
    public static let touchMin: CGFloat = 44
    public static let button:   CGFloat = 50

    /// 列高。v2 拿掉了分隔線，層級改由列高與群組間距撐起，見 `docs/SPEC.md` §9。
    public static let row: CGFloat = 56

    /// 空狀態的字符底盒。
    public static let iconHolder: CGFloat = 56

    static let table: [String: CGFloat] = [
        "Size.iconSm": iconSm, "Size.iconMd": iconMd, "Size.iconLg": iconLg,
        "Size.thumb": thumb, "Size.rowMin": rowMin, "Size.touchMin": touchMin,
        "Size.button": button, "Size.row": row, "Size.iconHolder": iconHolder,
    ]
}
