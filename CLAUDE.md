# Where Are You — 開發規範

記錄「每個物件目前在哪、最後一次在哪」的 iOS app。
完整規格在 `docs/SPEC.md`，設計在 Figma `a6S9XlccNqWHC8jJZ63kh6`。

---

## 開發管線（不可跳關）

```
需求 → docs/SPEC.md → Figma → 測試 → 程式碼
```

**任何一層要改，一律從最左邊改起。** 往右可以推進，往左不可以倒補。
發現問題時，回到問題所屬的那一層修，不要在下游打補丁。

---

## 1. Spec-Driven Development

任何**行為**改變，先改 `docs/SPEC.md`，再往下做。

- 程式碼只是規格的實作，不是規格本身
- 實作過程若發現規格有錯或有漏 → **停下來，先改 SPEC.md**，再繼續寫程式
- SPEC.md 與程式碼不一致時，以 SPEC.md 為準；程式碼是錯的
- 規格變更要連同「為什麼排除其他選項」一起寫，不要只寫結論

## 2. Figma 先行

任何**視覺**改動，先改 Figma，再改程式碼。**沒有門檻** —— 2px 的 padding 也算。

- 新畫面、新元件、版型或流程變更 → 先進 Figma
- 間距、字重、顏色的微調 → 也先進 Figma
- Figma 改的是**元件與 token**，不是只改單一畫面的實例
- 程式碼實作完成後，實機截圖要與對應的 Figma frame 逐項對照
- 兩邊不一致 = bug。不論是程式碼寫錯還是 Figma 沒更新，都要修到一致

**Figma 檔案結構**：`Cover` / `Getting Started` / `Foundations — Color` /
`Foundations — Type & Space` / 元件頁（`Icons` `Rows` `Badge & Button` `Fields` `Chrome`）/
`Screens — Light`（9 支）/ `Screens — Dark`（9 支）/ `Screens — Onboarding & Permissions`（5 支）。

深色版是從 token 推導的複製，**不要手動編輯深色頁** —— 改淺色頁與 token，再重新複製並釘 Dark mode。

## 3. Test-Driven Development

**邏輯層嚴格 TDD**：先寫測試 → 看它失敗 → 寫最小實作讓它通過 → 重構。
沒看過測試失敗，就不算寫過測試。

以下四項是最容易寫錯、且錯了會靜默壞資料的地方，**每一項都必須有測試**：

1. 遞迴子孫計數（含孫節點）
2. 缺件計算 —— 只有離開整棵子樹才算缺（見 SPEC §3.2 的橡皮擦反例）
3. 外來件計算
4. 循環防呆 —— 節點不得移進自己的子孫

**UI 不寫 XCUITest**。畫面的驗收方式是「跑起來截圖，與 Figma frame 逐項對照」。
理由：UI test 態、慢、易碎，而且抓不到「長得跟 Figma 不一樣」這種真正該抓的問題。

### 跨持久化邊界必須測

**只在記憶體裡操作 `ModelContext` 而不 `save()`，等於沒有測到 SwiftData。**
不存檔就不會觸發 delete rule 傳播、關聯 faulting、預設值套用、schema 驗證 ——
這些全部只在持久化邊界的另一側才會出錯。

以下三類操作，**每一項至少要有一個測試是 `save()` 之後重新 fetch 再斷言**：

1. 刪除模型（含 delete rule 對其他物件的連帶影響）
2. 讓關聯變成 `nil`（不論是手動清除還是 nullify 造成）
3. 新增或修改 `@Model` 的屬性與關聯（預設值、optional 性、inverse 是否正確配對）

這條規則是有代價才寫下來的：`MoveEvent` 的關聯少了 inverse 與 delete rule，容器被刪除
並存檔後再讀就拋 `This model instance was invalidated because its backing data could no
longer be found in the store`。當時**所有測試都沒有 `save()`**，所以整組測試對這個
情境完全盲目，是 code review 實際跑出來才發現的。

回歸測試若守的是既有正確行為，**要先確認它真的有牙齒** —— 暫時把修法拿掉、看它變紅、
再還原。永遠綠的測試不算測試。

## 4. Token 紀律（讓「同步」可被驗證）

SwiftUI 端**不得出現任何硬編碼的顏色、間距、圓角、字級**。

- Figma 的每個變數都設了 iOS code syntax（`Color.bgGrouped`、`Spacing.md`、`Radius.button`…）
- 程式碼端維護一份對應的 token 檔案，命名與 Figma 一字不差
- 改 token 值 → 先改 Figma 變數 → 再同步程式碼常數
- 這是「app 與 Figma 同步」唯一能被機械檢查的部分，不要繞過

## 5. 不使用 emoji

介面、程式碼、註解、文件、commit message 一律不用 emoji。
圖示走向量字符（Figma 的 `Icon/Glyph` 元件），可 tint、可綁 token。

---

## Git

全域 `~/.claude/CLAUDE.md` 的 Git/PR 規則全部適用。特別強調兩條：

- **commit message 絕不加 co-author 署名**，也不加任何「Generated with」字樣。訊息寫完本文就結束
- 不直接合併到 `dev`，一律開 PR

---

## 技術決策（細節見 SPEC.md）

| 項目 | 決定 |
|---|---|
| 部署下限 | iOS 18 |
| 設計基準 | iOS 26 視覺語言（但 v2 已脫離 iOS 原生外觀，見 SPEC §9）|
| UI | SwiftUI |
| 持久層 | SwiftData，MVP 只存本機 |
| 同步 | 不做，但模型從第一天就守 CloudKit 相容規則 |
| 專案檔 | XcodeGen，`project.yml` 進版控，`.xcodeproj` 不進 |
| 測試 | Swift Testing + in-memory ModelContainer |
| 字型 | Inter（拉丁與數字）+ 系統中文黑體 |

**CloudKit 相容規則**（現在就要遵守，否則之後開同步要痛苦遷移）：
所有純量屬性有預設值、所有關聯 optional、不用 `@Attribute(.unique)`、照片存檔案系統只在 DB 存檔名。

---

## 完成的定義

宣稱「做完了」之前，必須實際跑過並貼出輸出：

```bash
xcodegen && xcodebuild -scheme WhereAreYou -destination 'platform=iOS Simulator,name=iPhone 16' test
```

測試沒跑過就不要說通過。有測試失敗就直接說哪個失敗、貼輸出，不要含糊帶過。

**兩個會被誤讀成程式碼壞掉的環境問題**：

- `Simulator device failed to launch ... Busy ("Application failed preflight checks")`
  是模擬器卡住，不是程式碼問題。`xcrun simctl shutdown all` 之後重跑即可
- `Build input files cannot be found: .../Node.swift` 通常代表 `.xcodeproj` 是別的分支
  產生的。切分支後先跑 `xcodegen generate`

---

## Figma 操作已知地雷

以下都是實際踩過的，不要重新發現一次：

- `figma.createAutoLayout()` 建出的 frame **帶預設白色填色**，容器類一律要 `fills = []`
- TEXT 設 `layoutSizingHorizontal = 'FILL'` 時，**必須同時設 `textAutoResize = 'HEIGHT'`**，否則寬高塌成 0
- `addComponentProperty` 只能加在 **component set** 上，不能加在個別 variant
- 不能 `appendChild` 進 instance 內部（instance 子樹唯讀）。要疊內容就用絕對定位的兄弟節點
- `createNodeFromSvg` 回傳的外層 frame 有填色，重新上色時要跳過它、只塗向量
- **emoji 在此環境完全不渲染**（不只是規範問題，是技術限制）
- 透過 `setProperties` 寫入的文字，在後續改動後可能保留陳舊的 glyph layout 而整段不畫。
  症狀是節點屬性全對但畫面空白、`absoluteRenderBounds` 為 null。
  修法：把 TEXT 屬性值來回設一次（加一個 zero-width space 再設回原值）觸發重排
- 元件頁的展示襯底用的是未綁定的白色填色，那是文件裝飾，不是產品表面
