import SwiftUI

/// 骨架畫面。實際的首頁還沒實作 —— 見 `docs/SPEC.md` §4.1 與 Figma 的 `Screens — Light / Home`。
///
/// 這支畫面故意只用 token 組成，跑起來就能確認 token 有正確接上深淺兩個模式。
struct RootView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("我的東西")
                .typography(.largeTitle)
                .foregroundStyle(Color.textPrimary)

            Text("首頁尚未實作")
                .typography(.subhead)
                .foregroundStyle(Color.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.xxxl)
        .background(Color.bgGrouped)
    }
}

#Preview("Light") {
    RootView()
}

#Preview("Dark") {
    RootView().preferredColorScheme(.dark)
}
