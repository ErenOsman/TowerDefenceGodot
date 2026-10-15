# UI fixes from the screen-size test (2026-10-08)

From: the wiki server's UI/UX agent. For: the game's agent, after Eren approves.
Source: the live web build of 2026-10-05 (UI unchanged since), played at 1920×1080, 1280×720, 1280×800 and 1024×768.
Rules referenced: the UI Design Rules doc (type sizes: body 22, small 20, micro 18 = the minimum, at the 1920×1080 reference).

Nothing overflows or gets cut at any size; the top bar fits everywhere. The problems are text size, the camera and tooltip placement.
The HUD and menus will be redesigned later. **Changes 1–4 survive the redesign** (they are about scaling, the camera and the tooltip logic). Change 5–6 are small and cheap; do them only if the redesign is far away.

---

## 1. Text too small in battle (biggest problem)

At 1280×720 the canvas scales by 0.667, so the battle HUD's text ends up at 6–12 px on screen.

| Where | Today (1080 ref) | On a 720p screen | Change to |
| --- | --- | --- | --- |
| Hand card name / cost / key (`Assets/Prefabs/UI/Level/BottomBar/BottomBar_Button.prefab`, fontSize 15 / 11 / 13, name autosize min 10) | 15 / 11 / 13 | 10 / 7 / 9 px | name 20, cost 18 Bold, key 18; autosize min 18 |
| Stat lines HP / Power / Speed / Range (`TowerRightBar.prefab`, `EnemyRightBar.prefab`) | 17 | 11 px | 20 |
| Tooltip body / footer (`Assets/Editor/Gameplay/GameHudBuilder.cs` :317, :333, :337) | 18 / 17 | 12 / 11 px | 22 / 20 |
| "Key 1 · Shift-click" line (`UI_AbilityInfo`) | 16 | 11 px | 20 |
| Autosize minimums: `TowerRightBar_Ability`, `RightBar_Passive`, `EnemyRightBar_Ability`, `GameHudBuilder.cs:160` (`fontSizeMin = 14`) | 13–14 | 9 px | 18 |
| "Wave" label in the top bar (a sprite, `Art/UI/Wave.png`) | image | ~6 px, unreadable | a TMP text label, size 24, like the other `ResourceDisplay` labels |

- The hand card must grow from about 88×96 to **104×112** to fit the bigger text. The bottom bar (120) still holds it.
- Check: at 1280×720 no text in the battle HUD is under 12 px on screen.

## 2. The ability tooltip covers the range it describes

Hovering Shoot opens its tooltip left of the right bar, level with the row, which is right where the tower's blue range tiles are. At 4:3 two range tiles are fully hidden.

- Change: while a range / aim / area preview is shown, the ability tooltip must not cover any previewed tile. Simplest: open it **inside the right bar, under the ability list** (the bar has empty space there). Otherwise place it at the side of the screen away from the previewed tiles.
- Code: the ability rows get their trigger in `Assets/Scripts/UI/GameScene/TooltipText.cs` (opens with `UI_Tooltip.ShowBeside`) and `ElementList.cs:135`. Placement is in `Assets/Scripts/UI/Elements/Tooltip/UI_Tooltip.cs`.
- Check: hover each ability of a tower in the middle of the board at 1024×768; no previewed tile is under the tooltip.

## 3. The camera frames the whole screen, not the free area

`Assets/Scripts/Gameplay/BoardCamera.cs` `Init` (line 44) fits the board to the full camera view and centres it. The HUD covers the top 60, the bottom 120 and the right 300, so the board sits off-centre in the free area. At 4:3 with the right bar open only about 14 px remain between the base column and the bar (First Steps). 12-wide levels will likely touch or go under the bar.

- Change: fit and centre the board in the **free rectangle** = screen minus top bar, bottom bar and right bar (scaled by the canvas scale). Count the right bar always, open or not, so the board doesn't jump when a tower is selected. A lens shift (`cam.lensShift`) or an offset on the focus point both work.
- Centre the placing hint ("Click a free tile…") and the banners on the same free area.
- Check: First Steps and a 12-wide level (Two Roads, Slime King) at 1024×768 and 1920×1080, with a tower selected: no tile under a bar, the board centred in the free area.

## 4. Main menu and boot scenes scale differently

`Assets/Scenes/MainMenuScene.unity` (line 180) and `Assets/Scenes/BootScene.unity` (line 660) have Canvas Scaler `Match Width Or Height = 0`. Every other scene uses 0.5. At 4:3 the menu shrinks to 0.53 (Settings labels ~17 px, a small Back button).

- Change: set both to **0.5**.
- The Main Menu, Settings and Pause panels keep a fixed height with ~25% empty space at the bottom. Make them fit their content (`ContentSizeFitter` on the panel, or a height from the button count).
- Check: main menu, Settings and Pause at 1024×768 and 1920×1080 look the same size relative to the screen, and have no empty band at the bottom.

## 5. "Welcome back, {name}" can't be read

The main menu's `Greeting` label (`Assets/Scripts/UI/MainMenuScene/UI_MainMenu.cs`, `ShowGreeting`) is light blue-white on the yellow background: contrast about 1.2:1.

- Change (interim, until the menu is redesigned): text `#F2F4F8` on a dark strip (`#171A24` at 90%), or a dark text colour on the yellow.

## 6. Small controls and silent buttons

- The right bar's "i" (info) button is about 22 px at 720p. Make it 44×44 (icon 24); the minimum is 34×34 at the reference.
- The disabled **Skip** button gives no reason. Add a tooltip that says why ("Nothing to skip").
- The hand editor's empty "Your other towers" box should say what to do ("Towers you win appear here").

---

Screenshots of every size are on the wiki server in `~/uiux/out/play/ar-1080/`, `ar-720/`, `ar-800/`, `ar-768/`, 12 frames each. Ask the user if you need them.
