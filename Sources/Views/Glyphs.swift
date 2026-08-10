import SwiftUI

/// 向量字符的造型常數。座標直接抄自 Figma 的 `Icon/Glyph` 與 `Icon/Status` 元件，
/// 全部畫在 24×24 的格子上，再等比縮放到呼叫端要的尺寸。
///
/// 這裡的數字**不是設計 token** —— token 管的是顏色、間距、圓角、字級，
/// 字符的節點座標與線寬屬於美術資產，換一套圖就整組換掉，不會單獨被調。
/// 不用 emoji 的理由見 `docs/SPEC.md` §9：emoji 不能 tint、深色模式對比不可控。
private enum GlyphGrid {
    static let side: CGFloat = 24
    static let stroke: CGFloat = 2
    /// 狀態記號畫在填色的圓上，線要粗一點才咬得住。
    static let statusStroke: CGFloat = 2.2
    static let disc = CGRect(x: 1, y: 1, width: 22, height: 22)
}

/// 把 24 格座標系的路徑縮到目標尺寸。
private struct GlyphShape: Shape {
    let build: @Sendable (inout Path) -> Void

    func path(in rect: CGRect) -> Path {
        var path = Path()
        build(&path)
        let scale = Swift.min(rect.width, rect.height) / GlyphGrid.side
        return path.applying(CGAffineTransform(scaleX: scale, y: scale))
    }
}

private extension View {
    func glyphFrame(_ side: CGFloat) -> some View { frame(width: side, height: side) }
}

private func glyphStroke(_ width: CGFloat, side: CGFloat) -> StrokeStyle {
    StrokeStyle(lineWidth: width * side / GlyphGrid.side, lineCap: .round, lineJoin: .round)
}

// MARK: - 字符

struct SearchGlyph: View {
    var side: CGFloat = Size.iconSm
    var tint: Color = .textSecondary

    var body: some View {
        GlyphShape { path in
            path.addEllipse(in: CGRect(x: 4, y: 4, width: 13, height: 13))
            path.move(to: CGPoint(x: 15.4, y: 15.4))
            path.addLine(to: CGPoint(x: 21, y: 21))
        }
        .stroke(tint, style: glyphStroke(GlyphGrid.stroke, side: side))
        .glyphFrame(side)
    }
}

struct PlusGlyph: View {
    var side: CGFloat = Size.iconSm
    var tint: Color = .textSecondary

    var body: some View {
        GlyphShape { path in
            path.move(to: CGPoint(x: 12, y: 5))
            path.addLine(to: CGPoint(x: 12, y: 19))
            path.move(to: CGPoint(x: 5, y: 12))
            path.addLine(to: CGPoint(x: 19, y: 12))
        }
        .stroke(tint, style: glyphStroke(GlyphGrid.stroke, side: side))
        .glyphFrame(side)
    }
}

/// 返回鍵。Figma 是把 `Icon/Glyph/chevron-right` 轉 180 度，這裡直接畫成左向。
struct ChevronLeftGlyph: View {
    var side: CGFloat = Size.iconSm
    var tint: Color = .accent

    var body: some View {
        GlyphShape { path in
            path.move(to: CGPoint(x: 15, y: 5))
            path.addLine(to: CGPoint(x: 7.5, y: 12.5))
            path.addLine(to: CGPoint(x: 15, y: 20))
        }
        .stroke(tint, style: glyphStroke(GlyphGrid.stroke, side: side))
        .glyphFrame(side)
    }
}

/// 盤點頁每一列左邊的狀態記號。三種狀態的意義見 `docs/SPEC.md` §4.2b。
struct StatusGlyph: View {
    let status: ItemStatus
    var side: CGFloat = Size.iconSm

    var body: some View {
        ZStack {
            switch status {
            case .present:
                disc.fill(Color.stateOk)
                check
            case .missing:
                disc.fill(Color.stateMissing)
                cross
            case .foreign:
                // 空心圓：東西人在這裡，但這裡不是它的家。
                disc.stroke(Color.stateForeign, style: glyphStroke(GlyphGrid.stroke, side: side))
            }
        }
        .glyphFrame(side)
        .accessibilityLabel(accessibilityLabel)
    }

    private var disc: some Shape {
        GlyphShape { $0.addEllipse(in: GlyphGrid.disc) }
    }

    private var check: some View {
        GlyphShape { path in
            path.move(to: CGPoint(x: 7, y: 12.2))
            path.addLine(to: CGPoint(x: 10.6, y: 15.8))
            path.addLine(to: CGPoint(x: 18, y: 8))
        }
        .stroke(Color.textOnAccent, style: glyphStroke(GlyphGrid.statusStroke, side: side))
    }

    private var cross: some View {
        GlyphShape { path in
            path.move(to: CGPoint(x: 8, y: 8))
            path.addLine(to: CGPoint(x: 16, y: 16))
            path.move(to: CGPoint(x: 16, y: 8))
            path.addLine(to: CGPoint(x: 8, y: 16))
        }
        .stroke(Color.textOnAccent, style: glyphStroke(GlyphGrid.statusStroke, side: side))
    }

    private var accessibilityLabel: String {
        switch status {
        case .present: "在這裡"
        case .missing: "缺"
        case .foreign: "外來"
        }
    }
}

#Preview("Glyphs") {
    VStack(spacing: Spacing.xl) {
        HStack(spacing: Spacing.xl) {
            SearchGlyph()
            PlusGlyph()
            ChevronLeftGlyph()
        }
        HStack(spacing: Spacing.xl) {
            StatusGlyph(status: .present)
            StatusGlyph(status: .missing)
            StatusGlyph(status: .foreign)
        }
    }
    .padding(Spacing.xxl)
    .background(Color.bgGrouped)
}
