# UI components: review and plan for the redesign (2026-10-08)

From: the wiki server's UI/UX agent. For: Eren and the game's agent. Game commit reviewed: `96c7637`.
Goes with: the UI Design Rules doc (tokens, sizes, states) and the interactive HUD prototype (http://92.5.94.11/art/ui/prototype/).

**Verdict in one line:** keep the architecture, rebuild the element layer on a few shared parts. `BaseUIElement`, the Content rule, `UIManager` and the panel modes are good and stay. The elements on top (`UI_Button`, `UI_IconPro`, tooltips, plates) each carry their own colours, timings and animation code. That is why the same look is defined in many places and the new states (press-sink, denied, can't afford, aiming, cooldown) don't fit. A from-scratch rewrite is not needed. Most classes shrink.

All paths are under `Assets/Scripts/`. Follow AGENTS.md rules 11–14. Before changing a base class (`BaseUIElement`, `BaseUIPanel`), check every subclass (Rule 7). Rule 17 (reuse before adding) applies too: every new part below replaces code that exists two or three times today; nothing is added next to the old version.

---

## 1. What each class becomes

| Class | Lines | Used by today | Verdict | In short |
| --- | --- | --- | --- | --- |
| `BaseUIElement`, `UIManager`, `DebugUIElement` | — | everything | **Keep** | The foundation is sound. |
| `BaseUIPanel` | 106 | all panels | **Extend** | Add optional open/close transitions (section 3.7). |
| `UI_Button` | 1051 | every button, **hand cards**, **ability rows** | **Refactor** | Theme styles, real press, denied reason, attention state; the animation code moves out. |
| `UI_IconPro` | 902 | `StatusIcon.prefab` only | **Refactor → `UI_StatusIcon`** | Keep icon, stacks and bump; delete hover bob, glow, shine and click punch. |
| `UI_Icon` | 168 | base of `UI_IconPro` | **Keep** (trim) | Make "Mask" optional; merge into `UI_StatusIcon` later. |
| `UI_IconBar` | 660 | `EntityStatus.prefab` | **Refactor** (shrink) | About half is unused (overflow, expand-on-hover): delete it. Add remove animation and slide. |
| `UI_Card` | 278 | **nothing** (TestScene only) | **Replace** | Delete it; build `UI_HandCard` instead. |
| `UI_Tooltip`, `UI_TooltipTrigger`, `TooltipStack`, `UI_TooltipStackTrigger` | 1014 | all tooltips | **Refactor** | One placement solver with "avoid these rects", an owner, live refresh, a pooled box. |
| `UI_TextBubble` | 251 | tutorial | **Keep** (small extend) | Use the shared placement solver; values from the theme. |
| `UI_EntityStatus`, `UI_HealthBar`, `EntityStatusBinder` | 851 | plates, right bar | **Keep / extend** | Theme values, a shield segment, a damage-preview segment, fewer per-frame allocations. Statuses stay always visible. |
| `UI_LevelTowerRightBar`, `UI_LevelEnemyRightBar` | 270+ | battle HUD | **Replace** | Split into `UI_InspectorCard` + `UI_ActionBar`. Keep `FillAbility`'s logic. |
| `UI_LevelBottomBar` | — | the hand | **Rebuild** on `UI_HandCard` + `UI_HandFan`. |
| `BattleOverlay` (Gameplay) | 421 | plates, floaters, banner | **Refactor** | Split into PlateLayer, FloaterLayer, BannerLayer; delete the code-built fallback plate (~150 lines). |
| `FloatingText`, `Presenters` | — | combat numbers | **Extend** | `Float(pos, text, FloatKind)`; size, colour and curve from the theme; pooled. |
| `TooltipText`, `EntityText` | — | rich text | **Extend** | Colours from theme tokens; no `<size=70%>` under 18 pt. |
| `ElementList`, `UI_AbilityInfo` | — | lists | **Keep** + small fixes | `ElementList`: replace `EventTrigger` with a hover relay (it eats scroll events). |

---

## 2. The shared layer (new, small)

These replace roughly 40 hard-coded literals and about 25 `Coroutine` fields spread over `UI_Button`, `UI_IconPro`, `UI_HealthBar`, `UI_Tooltip` and `BattleOverlay`.

1. **`UITheme` (ScriptableObject, decided).** One asset with:
   - Colour tokens from the rules doc: `ink.*`, `text.*`, `accent*`, `gold`, `good`, `bad`, `status`, `fx.*`, `hp.*`, `team.*`.
   - Type: font assets (Plinth, Nunito Medium/Bold), the size scale 64/44/32/26/22/20/18, outline settings for text over the board.
   - Spacing (4 px grid) and radii, plus the 9-slice sprites per radius.
   - Motion: the durations (instant 0.1, quick 0.15–0.2, normal 0.25–0.3, slow 0.4–0.6) and curves (ease-out in, ease-in out, overshoot 1.06).
   - **`FeedbackProfile`** per control kind (button, card, ability, icon button): hover lift px, hover scale, press sink px, press scale, denied shake px and time, spawn.
   - **`ControlStyle`** per variant (Primary, Secondary, Danger, Icon, Ability, EndTurn, HandCard): a fill/outline/label colour per state and the background sprite.
   - A static `UITheme.Current` (loaded once) so runtime code and the editor builders read the same asset. Its folder follows `Folder Structure — Design.md`.
2. **`UITweener` (component).** One coroutine per element with named channels: Scale, Offset, Alpha, Colour. The final pose = home + lift + sink + shake (+ bob), so effects add up instead of stopping each other. Unscaled time. This also fixes "hover lost during spawn" in `UI_IconPro` and `UI_Button`.
3. **`UIFeedback` (component).**
   - Handles pointer enter/exit/**down/up**/click (left button only) and select/deselect/submit for keyboard focus (2 px accent ring).
   - Drives lift, sink, shake and the attention pulse through `UITweener`, using the theme's `FeedbackProfile`.
   - When not interactable it still gets the pointer: a click shakes and shows `DeniedReason` in the tooltip ("Needs 40 energy").
   - `UI_Button`, `UI_HandCard` and the ability button all use it.
4. **`UIStateVisual` (component).** Takes `[Flags] UIState` (Hover, Pressed, Selected, Picked, Disabled, CantAfford, Locked, Placed, Benched, Aiming, Cooldown, Attention). It resolves priority, looks up the `ControlStyle` and applies it to the referenced parts ("Background", "Outline", "Icon", "Label", "CostBadge"; Rule 11 composition). All per-instance colour fields go (e.g. `UI_Button.cs:85-120`).
5. **Small composable prefabs** (plain `BaseUIElement` where possible):
   - `UI_Badge`: cost, key number, stacks.
   - `UI_CooldownOverlay`: Image Radial360 fill plus a turns-left number.
   - `UI_TooltipBox`: Header, Body and Footer references, pooled; used by the tooltip and the stack (today `TooltipStack` finds them by hierarchy paths).
6. **`TooltipPlacement.Solve(content, anchor, bounds, preferredSides, avoidRects, gap)`.** A pure function: try each side, flip, slide along the edge, score overlap with the avoid rects. Used by `UI_Tooltip`, `TooltipStack` and `UI_TextBubble`, replacing three copies of the rect and clamp maths. `LevelController` registers the range/aim/area preview's screen bounds as an avoid rect.

---

## 3. Per component

### 3.1 `UI_Button` (keep the class, slim it)
- Visuals come from a `ControlStyle` + `UIFeedback` + `UIStateVisual`. Delete the 15 colour fields and the animation tuning fields. Keep a per-instance style override for rare cases.
- **Real press:** implement `IPointerDownHandler` / `IPointerUpHandler`. Down sinks (2 px, scale 0.97); up releases; click fires on up inside. Today the "pressed" colour only flashes after the click.
- **Disabled with a reason:** `SetInteractable(false, reason)`. A disabled button still gets hover (tooltip shows the reason) and a click shakes it. Today `OnPointerEnter` returns early, so a disabled button can't explain itself.
- **Attention state** (End turn when nothing is left to do): a slow glow and breathe from the theme, only when set.
- `Label` becomes optional (icon-only buttons). Shine sweep and hover bob become style options, off by default.
- Keep: `SimulateClick` (used by key shortcuts), `OnClick`, `SetLabel`, `SetIcon`, `Selected`.

### 3.2 `UI_HandPiece` + `UI_HandTray` (new; replace hand cards built on `UI_Button` and the unused `UI_Card`)
- **Changed 2026-10-08 (user):** the hand is a tray of miniatures side by side (like Into the Breach), not fanned cards. Each piece = unit render on its plinth, name plate, cost coin, key number. `UI_HandTray` is a plain row (no arc); the hovered piece lifts. The states below stay the same.
- Card states: Ready, Hover, Picked, CantAfford (icon 40%, cost badge `bad`), Placed, Locked, Benched, Disabled. Size about 104×112 to 126×136 at the reference.
- Parts: Portrait (unit render), Name (`type.small`, `accent.light`), `UI_Badge` cost (top-left), `UI_Badge` key (top-right).
- `UI_HandTray` positions the piece roots in a straight row; each piece animates its Content (lift, shadow), the split `UI_IconBar` already uses.
- Placing: the picked card stays raised until the tower is placed or cancelled (right click / Esc).

### 3.3 `UI_ActionBar` + ability button (new; replaces the right bar's ability list)
- Centred above the hand, shown when a tower is selected (slides up 0.2 s). One ability button per ability, about 84×84: icon, key number badge, cost badge, `UI_CooldownOverlay`.
- States: Ready, Hover (range preview on the board), Aiming (gold ring), Cooldown (radial and turns left), Blocked (denied reason).
- Reuse the logic in `UI_LevelTowerRightBar.FillAbility` (`:201-239`): cooldown, castability, quick-cast, `level.PreviewAbility`.
- The ability tooltip opens **above the action bar** with the preview's rect as an avoid rect.

### 3.4 `UI_InspectorCard` (new; replaces the full-height right bars)
- Right side, about 340 wide, only while something is selected. It slides in 0.25 s, with a top accent band (`accent` for towers, `team.enemy` for enemies).
- Contents: portrait, name (`type.h2`), subtitle, HP bar (`UI_HealthBar`), stats as label + number, statuses (`UI_IconBar`), Sell (towers only), Info (44×44 icon button).
- The camera's free area now loses only the card's width while a selection is open, or nothing if the card floats over the board's empty side. Decide this together with the camera "free rect" fix.

### 3.5 `UI_StatusIcon` (from `UI_IconPro`) and `UI_IconBar`
- `UI_StatusIcon`: icon, `SetStacks(int)` (the label is hidden at 1; no string parsing), value bump in `good`/`bad`, spawn and remove animations. No pointer handlers except the tooltip trigger, so plates don't swallow board clicks.
- `UI_IconBar`: delete the overflow / expand-on-hover code, `maxIcons` and the pointer interfaces. Pull the row maths into a small `UIRowLayout` (target positions plus slide). Remove = shrink, then destroy, while the neighbours slide.

### 3.6 Plates, floaters, banners (`BattleOverlay` split)
- **PlateLayer:** prefab plates only (delete `MakePlate` and the related code, `:241-421`). The visibility rule (hover, selection, after a hit, while dying, or the setting) stays on the HP bar only, now with a fade. **Statuses on the board stay visible at all times** (as today, `EntityStatusBinder.SetHealthVisible`). Add the enemy intent chip and the damage-preview stripes (see the UI doc, "Board previews"). Clamp the zoom scale so text never drops under 18 pt equivalent.
- **FloaterLayer:** pooled `FloatingText` with `Play(kind)`: pop with overshoot, rise, fade (0.9 s). Several numbers on one unit stack upwards. Skip points behind the camera.
- **BannerLayer:** a pooled `UI_Banner` prefab with a sweep (in 0.2 s, hold, out), `blocksRaycasts = false`, timings from the theme. A newer banner replaces a stale one.
- The layer canvas uses match 0.5 and unscaled time for HUD motion (today it gets the scaled `dt`, `LevelController.cs:252`).

### 3.7 Panels: open and close transitions
`BaseUIPanel.Disable()` hides Content at once, so a window can't animate out. Add an optional `PanelTransition` component: `Enable` = activate, then fade and scale from 0.96 (0.25 s); `Disable` = animate out (0.15 s), then deactivate. Panels without the component behave as today. Check every `BaseUIPanel` subclass before changing it.

### 3.8 Tooltips
- `UI_Tooltip.ShowAbove(anchor, content, owner)` and `ShowBeside(...)` through the placement solver. Add `Hide(owner)` and `Refresh(owner, content)`, so an open tooltip updates (cooldown, reason) and one trigger's exit doesn't hide another's tooltip.
- Hide by toggling Content (Rule 13), not by CanvasGroup alpha 0.
- One at a time between the tooltip and the stack. The stack delay goes to 0.4 s (today 0.25).
- Move passive plate hover-testing into one per-frame `PlateHoverService` (today every plate raycasts every frame and allocates).

---

## 4. Bugs and rule breaks worth fixing now (independent of the redesign)

| Where | Problem |
| --- | --- |
| `UI/Elements/coreElements/UI_IconPro.cs:503` | `OnPointerClick` has no left-button check: right click plays the press. Breaks "right click never presses". |
| `UI/Elements/coreElements/UI_IconBar.cs:556-566` | `PlaySpawnDelayed` touches `iconPro.gameObject` a frame later; if the icon was removed that frame it throws. Add `if (iconPro == null) yield break;`. |
| `UI_IconBar.cs:422,426` | Hides icons with `SetActive` on the root (Rule 13 says Content). |
| `UI/Elements/EntityStatus/UI_HealthBar.cs:192` | An equal value takes the heal branch, so a max-HP-only change flashes heal-green. The comment at `:194` says "drops immediately" but it lerps. |
| `UI_HealthBar.cs:367` | Label autosize minimum 8 (rule: 18). |
| `UI/Elements/Tooltip/UI_TooltipStackTrigger.cs:25` | Delay 0.25 s (rule: 0.4 s). |
| `UI/GameScene/TooltipText.cs:159`, `UI_LevelTowerRightBar.cs:212`, `EntityStatusBinder.cs:152` | Percentage sizes (70–75%) that end up under 18 pt. |
| `Gameplay/BattleOverlay.cs:102-104` | Canvas Scaler match 0 (rule: 0.5). |
| `UI/GameScene/ElementList.cs:110` | `EventTrigger` swallows scroll and drag events in a parent ScrollRect. |

---

## 5. Order of work

1. **`UITheme`** asset and `UITheme.Current`. Point `TooltipText`, `EntityText`, `Presenters` and the builders at it. No visual change yet; everything reads one source.
2. **`UITweener`, `UIFeedback`, `UIStateVisual`** and the badge / cooldown prefabs. Move `UI_Button` onto them (press, denied reason, attention).
3. **Tooltip solver and service**, `UI_TooltipBox`.
4. **New HUD:** `UI_HandPiece` + `UI_HandTray`, `UI_ActionBar`, `UI_InspectorCard`, the new top pills and tracker, the End turn button. Remove the right bars and the old bottom bar.
5. **BattleOverlay split** (plates, floaters, banners) and `PanelTransition`.
6. **Clean-up:** delete `UI_Card` (+ `UI_CardEditor`), the unused `UI_IconBar` and `UI_IconPro` paths, and the fallback plate.

Each step ships on its own and keeps the game working. The sprites (9-slice panels, buttons, badges, icons) and the layout spec for each screen come from the UI/UX agent as the screens are approved.
