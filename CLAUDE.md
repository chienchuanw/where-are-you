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
xcodegen && xcodebuild -scheme WhereAreYou -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.1' test
```

測試沒跑過就不要說通過。有測試失敗就直接說哪個失敗、貼輸出，不要含糊帶過。

### 兩台基準機，各有各的職務

| 機型 | 尺寸 | 用途 |
|---|---|---|
| iPhone 16 | 393×852（1179×2556 @3x） | 跑測試、截圖與 Figma frame 逐項對照 |
| iPhone SE (3rd generation) | 375×667（750×1334 @2x） | 鍵盤遮擋與捲動的驗收 |

這兩台**通常不在 Xcode 的預設清單裡**。先查再建，不要無條件跑 `create` ——
`simctl` 不擋同名裝置，建重複了 `-destination` 的 `name=` 就會指向兩台，
`xcodebuild` 要不是拒絕，就是安靜地跑在那台剛建好、從沒開機的替身上：

```bash
for D in "iPhone 16" "iPhone SE (3rd generation)"; do
  xcrun simctl list devices available | grep -q "^    $D (" || echo "缺 $D，要建"
done
```

真的缺了才建：

```bash
xcrun simctl create "iPhone 16" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-16 com.apple.CoreSimulator.SimRuntime.iOS-26-1
xcrun simctl create "iPhone SE (3rd generation)" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation com.apple.CoreSimulator.SimRuntime.iOS-26-1
```

**截圖與啟動一律指名裝置，不要用 `booted`。** 同時開著兩台基準機時 `booted` 會自己挑一台，
挑到 SE 就是拿 375×667 的截圖去對 393×852 的 frame —— 對照的結論整組作廢，而且不會有人發現。
`DebugLaunch.swift` 註解裡的示例指令已經改成指名 `"iPhone 16"`，照抄即可。

**為什麼是 iPhone 16：** 它與 Figma frame 同為 393×852，截圖可以直接疊上去比，
不必先在腦裡扣掉一個差值。差值只要存在，就會變成「這 3pt 應該是機身差吧」的藉口，
而真正的版型錯誤就藏在那句話後面。**它不是唯一的選擇** —— iPhone 14 Pro / 15 / 15 Pro
也都是 393×852，device type 都還在。挑 16 只因為它是其中最新的；上述任何一台
在 26.1 上都可以頂替，不要因為 16 建不出來就放棄逐項對照。

**但垂直位置對不上，而且那是對的。** 實測同一支首頁：大標題上緣在 iPhone 16 落在 64.3pt、
在 16e 落在 52.3pt，差 12pt。原因是安全區 —— 每一台 393×852 的機型都有動態島（59pt），
而 16e 是瀏海（47pt）。Figma `NavBar` 的上內距 52 是狀態列的**預留佔位，不是 token**，
元件說明已經寫明「程式碼不複製它，交給系統的 safe area」。

所以對照時**比的是安全區以下的相對節奏，不是絕對 y 座標**。整頁一起下移不是 bug，
不要去「修」它；真正要看的是列高、群組間距、左右內距這些相對量。
換基準機換到的是**版面寬度與可視高度**的精確，不是狀態列的精確 —— 後者沒有任何一台對得上。

**為什麼另外需要一台矮機身：** 有一整類 bug 只在畫面不夠高的時候看得見。
PR #8 的 review 抓到新增表單沒有 `ScrollView`、鍵盤會蓋住送出鍵 —— 那在 852pt 上
完全正常，在 667pt 上流程直接走不完。只用一台高機身等於對這類問題全盲，
而截圖對照剛好是最不可能發現它的驗收方式（截圖裡沒有鍵盤）。

**所以 SE 是一個真的關卡，不是一列說明。** 只要這次改動碰到**任何有輸入欄位的畫面**
（表單、搜尋列、sheet 裡的搜尋），宣稱做完之前必須在 SE 上跑起來、**把鍵盤叫出來**，
確認送出鍵與最後一列仍然按得到，並貼出那張截圖。沒有輸入欄位的改動不必跑。

```bash
xcrun simctl boot "iPhone SE (3rd generation)"
xcrun simctl launch "iPhone SE (3rd generation)" com.chienchuanw.whereareyou -open-container 登山包 -add-item
# 點進名稱欄叫出鍵盤，再截圖
xcrun simctl io "iPhone SE (3rd generation)" screenshot /tmp/se.png
```

**基準機的尺寸是可以一行指令驗證的事實，不要靠記憶寫進文件。** 直接讀 device type 的
profile，**不需要開機**，而且印出來的是 pt（Figma 對照依賴的單位），縮放比是算出來的、
不是記來的：

```bash
D="iPhone 16"
P="/Library/Developer/CoreSimulator/Profiles/DeviceTypes/$D.simdevicetype/Contents/Resources/profile.plist"
read w h s < <(/usr/libexec/PlistBuddy -c "Print :mainScreenWidth" -c "Print :mainScreenHeight" \
  -c "Print :mainScreenScale" "$P" | tr '\n' ' ')
echo "$D: $(bc <<< "$w/$s")x$(bc <<< "$h/$s") pt (${w}x${h} px @${s%.*}x)"
```

（`xcrun simctl io ... screenshot` 也可以，但它**要求裝置已開機** —— 剛 `create` 出來的是
Shutdown，那條路會卡住然後吐 `Timeout waiting for screen surfaces`，而且 `sips` 只印像素，
pt 還是得自己換算。要驗尺寸就讀 profile。）

**曾經寫錯，留著當記號：** 這一節原本寫「用 iPhone 16e 是因為它是 393×852」，
但 16e 是 390×844 —— 寬 3pt、**高 8pt**，兩個方向都不對，而縱向那 8pt 才是影響
「一頁塞得下多少」的那一個。這個錯誤在文件裡活了好幾輪。

**同時要澄清一件事，免得下一個人也弄反：** PR #5 記錄的「整體差 2–3pt 來自狀態列高度
（Figma 畫 52，iPhone 16e 的安全區是 47）」**不是**這個錯誤造成的，那筆歸因是對的，
講的是上面說的安全區差異。兩件事各自獨立：機身尺寸寫錯是一回事，狀態列預留對不上是另一回事，
換基準機只解決前者。

**已經通過的畫面是在 390×844 上對照的。** 那 9 支 Screens 的「逐項對照」結論嚴格說並不成立。
不為此另開一支 PR 回頭重掃，但**下次因為別的理由動到某一支畫面時，順手在 iPhone 16 上重對一次**，
這比一次性的大掃除更可能真的發生。

**三個會被誤讀成程式碼壞掉的環境問題**：

- `xcodebuild: error: Unable to find a device matching the provided destination specifier`
  **不是程式碼問題**，而且有兩種原因，先用 `xcrun simctl list devices available` 分辨：
  上面那兩台基準機不是預設就有的，最可能是**這台機器還沒建過**，照上一節的 `simctl create` 補；
  若是 Xcode 升級換掉了整批模擬器，才是把 `-destination` 與上面那一節一起改掉，
  不要讓下一個人再撞一次
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
