import Testing
import UIKit
@testable import WhereAreYou

/// 這組測試是「app 與 Figma 同步」唯一能被機械檢查的部分。
///
/// `Resources/figma-tokens.json` 是從 Figma 匯出的，改 Figma 之後重新匯出，
/// 這裡就會紅到程式碼跟上為止。不要為了讓測試變綠而改 JSON。
struct TokenParityTests {

    // MARK: - 匯出檔案的形狀

    struct FigmaTokens: Decodable {
        struct ColorEntry: Decodable { let name: String; let ios: String; let light: String; let dark: String }
        struct MetricEntry: Decodable { let name: String; let ios: String; let value: Double }
        struct TextStyleEntry: Decodable {
            let name: String; let family: String; let style: String
            let size: Double; let lineHeight: Double; let tracking: Double
        }
        let colors: [ColorEntry]
        let metrics: [MetricEntry]
        let textStyles: [TextStyleEntry]
    }

    static let exported: FigmaTokens = {
        guard let url = Bundle(for: BundleMarker.self).url(forResource: "figma-tokens", withExtension: "json") else {
            fatalError("找不到 figma-tokens.json —— 它應該被打包進測試 target 的 resources")
        }
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(FigmaTokens.self, from: Data(contentsOf: url))
    }()

    private final class BundleMarker {}

    // MARK: - 顏色

    @Test("每個匯出的顏色 token 都有對應的 Swift token")
    func everyExportedColourHasASwiftToken() {
        let swiftNames = Set(ColorToken.allCases.map(\.rawValue))
        for entry in Self.exported.colors {
            #expect(swiftNames.contains(entry.ios), "Figma 有 \(entry.ios)，Swift 沒有")
        }
    }

    @Test("沒有多出來的 Swift 顏色 token")
    func noSwiftColourTokenIsUnknownToFigma() {
        let exportedNames = Set(Self.exported.colors.map(\.ios))
        for token in ColorToken.allCases {
            #expect(exportedNames.contains(token.rawValue), "Swift 有 \(token.rawValue)，Figma 沒有")
        }
    }

    @Test("顏色值與 Figma 逐一相符（Light 與 Dark 都比）")
    func colourValuesMatchFigma() throws {
        let byName = Dictionary(uniqueKeysWithValues: Self.exported.colors.map { ($0.ios, $0) })
        for token in ColorToken.allCases {
            let entry = try #require(byName[token.rawValue], "\(token.rawValue) 不在匯出檔裡")
            let (light, dark) = token.values
            #expect(hex(light) == entry.light.uppercased(), "\(token.rawValue) 的 Light 值不符")
            #expect(hex(dark) == entry.dark.uppercased(), "\(token.rawValue) 的 Dark 值不符")
        }
    }

    @Test("顏色 token 在深淺兩個 trait 下解析出不同的實際顏色")
    func colourTokensResolvePerTrait() {
        for token in ColorToken.allCases where token.values.light != token.values.dark {
            let lightResolved = token.uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            let darkResolved = token.uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
            #expect(lightResolved != darkResolved, "\(token.rawValue) 在深淺模式下解析成同一個顏色")
        }
    }

    // MARK: - 數值

    @Test("間距、圓角、尺寸的數值與 Figma 相符")
    func metricValuesMatchFigma() throws {
        let allTables = Spacing.table.merging(Radius.table) { a, _ in a }
            .merging(Size.table) { a, _ in a }
        for entry in Self.exported.metrics {
            let value = try #require(allTables[entry.ios], "Figma 有 \(entry.ios)，Swift 沒有")
            #expect(Double(value) == entry.value, "\(entry.ios) 的值不符")
        }
    }

    @Test("沒有多出來的 Swift 數值 token")
    func noSwiftMetricIsUnknownToFigma() {
        let exportedNames = Set(Self.exported.metrics.map(\.ios))
        let swiftNames = Set(Spacing.table.keys).union(Radius.table.keys).union(Size.table.keys)
        for name in swiftNames {
            #expect(exportedNames.contains(name), "Swift 有 \(name)，Figma 沒有")
        }
    }

    // MARK: - 字級

    @Test("字級的尺寸、行高、字距與 Figma 相符")
    func typographyMatchesFigma() throws {
        let byName = Dictionary(uniqueKeysWithValues: Self.exported.textStyles.map { ($0.name, $0) })
        for token in TypographyToken.allCases {
            let entry = try #require(byName[token.rawValue], "\(token.rawValue) 不在匯出檔裡")
            #expect(Double(token.size) == entry.size, "\(token.rawValue) 的字級不符")
            #expect(Double(token.lineHeight) == entry.lineHeight, "\(token.rawValue) 的行高不符")
            #expect(abs(Double(token.tracking) - entry.tracking) < 0.0001, "\(token.rawValue) 的字距不符")
            #expect(token.figmaStyle == entry.style, "\(token.rawValue) 的字重不符")
        }
    }

    @Test("字級數量與 Figma 一致")
    func typographyCountMatches() {
        #expect(TypographyToken.allCases.count == Self.exported.textStyles.count)
    }

    // MARK: -

    private func hex(_ rgb: UInt32) -> String {
        String(format: "#%02X%02X%02X", (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)
    }
}
