# Style B "Painted Diorama": Unity sprite kit

Rendered from HTML/CSS with headless Chromium (`node render.js` in `~/uiux/kit-b`). Every value comes from `tokens.js`
(the same tokens as the UITheme table in `notes/2026-10-08-hud-menu-spec.md`): change a token, re-render, and the PNGs,
`slices.json`, `unity/KitBImport.cs`, this README and `sheet.png` are rebuilt.

## How to use the PNGs in Unity
- **Scale.** Sprites are rendered at **2x** the 1920x1080 reference. Put them on Images with **Pixels Per Unit Multiplier = 2**
  (the sprite's own PPU stays 100, like the Canvas' Reference Pixels Per Unit). A 9-slice border of 38 px in the PNG is then 19 px on the reference canvas.
  Don't use Set Native Size on these Images: it would give 2x. Size the RectTransform from the spec instead.
- **Import** (done for you by `unity/KitBImport.cs` → `Assets/Editor/UI/KitBImport.cs`, for files under `Assets/Art/UI/KitB/`):
  Texture Type Sprite (2D and UI), Sprite Mode Single, Mesh Type **Full Rect** (required for 9-slice), Border from `slices.json`,
  sRGB on, Alpha Is Transparency on, **Compression None**, **Generate Mip Maps off** (on for `icon_*` only: they are 64 px shown at 20-40 px),
  Filter Bilinear, Wrap Clamp (Repeat for `wood_grain_tile`, `line_attack_dash`, `stripes_*`), Non-Power of 2 None, Max Size 4096.
- **Image Type.** `Sliced` (Fill Center on) for every sprite with a border; `Simple` + Preserve Aspect for the rest; `Filled / Radial 360`
  for `clock_ring_fill` and `cooldown_ring`; `Tiled` for `wood_grain_tile`. Stripes and the dashed line are textures for RawImage / LineRenderer.
- **Outsets.** Rim, band and glow sit outside the control's rect. `outsetRef {l, r, t, b}` in `slices.json` says how far. The **Background**
  child of a control stretches to its parent (anchors 0,0 → 1,1) with `offsetMin = (-l, -b)` and `offsetMax = (r, t)`. Example: `panel_wood`
  has outset 3/3/3/12, so a 340x96 inspector card keeps its 340x96 rect and the band hangs 12 px below it.
- **White sprites are tinted.** `icon_*`, `glow_r14`, `focus_ring_*`, `hpbar_fill`, `hpbar_ghost`, `hpbar_plate_fill`, `mask_*`, `clock_ring_fill`,
  `cooldown_ring`, `ready_glow`, `endturn_glow`, `piece_glow`, `intent_glow` are white. The Image colour gives the token (e.g. accent, gold, hp.high).
- **No text in images.** Every label, number and key name is TextMeshPro (Plinth-Bold for display/numbers, Nunito for body) on top of the sprite.

## Groups
panels · fields · buttons · endturn · badges · bars · chips · hand · ability · cooldown · board · icons · backgrounds.
`sheet.png` shows each sprite on wood and on paper, native and 9-slice stretched, plus composites assembled like Unity will.

## Sprites
| Sprite | File | PNG px | 9-slice border px (L / R / T / B) | Outset at reference (L / R / T / B) | Use |
| --- | --- | --- | --- | --- | --- |
| `panel_wood` | png/panels/panel_wood.png | 268×204 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | Wood panel r14, cobalt band + rim baked. Pills, tracker, inspector, action bar, menu buttons (normal). |
| `panel_wood_enemy` | png/panels/panel_wood_enemy.png | 268×204 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | Same, band in team.enemy: the enemy inspector card. |
| `pill_wood` | png/panels/pill_wood.png | 252×124 | 64 / 64 / 60 / 62 | 3 / 3 / 3 / 3 | Fully round ends at 56 high (HP / energy pills, name plate). Height 48-64 keeps the ends round enough; for other heights scale the sprite. |
| `window_frame` | png/panels/window_frame.png | 412×332 | 66 / 66 / 66 / 66 | 3 / 3 / 3 / 3 | Large wood plaque r22 with the inner bevel line at 12 px: Welcome plaque, Settings / Codex / Pause windows. |
| `dialogue_box` | png/panels/dialogue_box.png | 412×292 | 66 / 66 / 66 / 66 | 3 / 3 / 3 / 3 | Visual-novel dialogue box (~1100x220), a shade darker than panels so the cream text reads over any scene. Name plate = pill_wood. |
| `paper_card` | png/panels/paper_card.png | 252×204 | 34 / 34 / 34 / 34 | 3 / 3 / 3 / 3 | Paper card r12 with a paper-edge band: generic readable card (rewards, codex entries). |
| `tooltip_paper` | png/panels/tooltip_paper.png | 332×252 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | Tooltip box r14 (340-380 wide, pad 16-18). Add a tail sprite for the pointing version. |
| `paper_stat` | png/panels/paper_stat.png | 200×104 | 28 / 28 / 28 / 28 | 2 / 2 / 2 / 2 | Small paper tile r10 (inspector stats 48 high, chips on paper). |
| `tooltip_tail_down` | png/panels/tooltip_tail_down.png | 80×52 | — | — | Tail for a tooltip ABOVE its anchor. Pivot (0.5, 1) at the anchor; its top 12 px overlap the box bottom (covers the edge band). |
| `tooltip_tail_up` | png/panels/tooltip_tail_up.png | 80×52 | — | — | Tail for a tooltip BELOW its anchor (rotate the same sprite or use this one). Top 4 px overlap the box. |
| `shadow_soft` | png/panels/shadow_soft.png | 256×256 | 104 / 104 / 104 / 104 | 32 / 32 / 32 / 32 | Soft drop shadow under any panel/button (the mockups' 0 18px 28px). Sibling before the Background, offset y -10, alpha 0.5-0.8. |
| `field_paper_normal` | png/fields/field_paper_normal.png | 344×168 | 40 / 40 / 40 / 40 | 6 / 6 / 6 / 6 | Text field (Welcome name 632x72). Ring wood.500. |
| `field_paper_focus` | png/fields/field_paper_focus.png | 344×168 | 40 / 40 / 40 / 40 | 6 / 6 / 6 / 6 | Focused / typing: accent ring. |
| `field_paper_error` | png/fields/field_paper_error.png | 344×168 | 40 / 40 / 40 / 40 | 6 / 6 / 6 / 6 | Invalid (empty name): bad ring + help text in bad says why. |
| `btn_primary_normal` | png/buttons/btn_primary_normal.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 |  |
| `btn_primary_hover` | png/buttons/btn_primary_hover.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 |  |
| `btn_primary_pressed` | png/buttons/btn_primary_pressed.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | Face sits 4 px lower (band 6 -> 2): move Label/Icon down 4 px with it. |
| `btn_primary_disabled` | png/buttons/btn_primary_disabled.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 |  |
| `btn_secondary_normal` | png/buttons/btn_secondary_normal.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 |  |
| `btn_secondary_hover` | png/buttons/btn_secondary_hover.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 |  |
| `btn_secondary_pressed` | png/buttons/btn_secondary_pressed.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | Face sits 4 px lower (band 6 -> 2): move Label/Icon down 4 px with it. |
| `btn_secondary_disabled` | png/buttons/btn_secondary_disabled.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 |  |
| `btn_danger_normal` | png/buttons/btn_danger_normal.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 |  |
| `btn_danger_hover` | png/buttons/btn_danger_hover.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 |  |
| `btn_danger_pressed` | png/buttons/btn_danger_pressed.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | Face sits 4 px lower (band 6 -> 2): move Label/Icon down 4 px with it. |
| `btn_danger_disabled` | png/buttons/btn_danger_disabled.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 |  |
| `menu_btn_primary_normal` | png/menu/menu_btn_primary_normal.png | 332×150 | 38 / 38 / 38 / 56 | 3 / 3 / 3 / 12 | Main menu Continue / Welcome Start (cobalt side).  |
| `menu_btn_primary_hover` | png/menu/menu_btn_primary_hover.png | 332×150 | 38 / 38 / 38 / 56 | 3 / 3 / 3 / 12 | Main menu Continue / Welcome Start (cobalt side).  |
| `menu_btn_primary_pressed` | png/menu/menu_btn_primary_pressed.png | 332×150 | 38 / 38 / 38 / 56 | 3 / 3 / 3 / 12 | Main menu Continue / Welcome Start (cobalt side). Face 4 px lower: move Label/Icon with it. |
| `menu_btn_primary_disabled` | png/menu/menu_btn_primary_disabled.png | 332×150 | 38 / 38 / 38 / 56 | 3 / 3 / 3 / 12 | Main menu Continue / Welcome Start (cobalt side).  |
| `menu_btn_wood_normal` | png/menu/menu_btn_wood_normal.png | 332×150 | 38 / 38 / 38 / 56 | 3 / 3 / 3 / 12 | Main menu list buttons (dark wood side).  |
| `menu_btn_wood_hover` | png/menu/menu_btn_wood_hover.png | 332×150 | 38 / 38 / 38 / 56 | 3 / 3 / 3 / 12 | Main menu list buttons (dark wood side).  |
| `menu_btn_wood_pressed` | png/menu/menu_btn_wood_pressed.png | 332×150 | 38 / 38 / 38 / 56 | 3 / 3 / 3 / 12 | Main menu list buttons (dark wood side). Face 4 px lower: move Label/Icon with it. |
| `menu_btn_wood_disabled` | png/menu/menu_btn_wood_disabled.png | 332×150 | 38 / 38 / 38 / 56 | 3 / 3 / 3 / 12 | Main menu list buttons (dark wood side).  |
| `menu_panel` | png/menu/menu_panel.png | 412×350 | 66 / 66 / 66 / 84 | 3 / 3 / 3 / 12 | Welcome plaque (deep, r22, inner line). |
| `menu_panel_r14` | png/menu/menu_panel_r14.png | 268×222 | 38 / 38 / 38 / 56 | 3 / 3 / 3 / 12 | Small deep menu panel (optional, e.g. Victory / Defeat). |
| `ibtn_normal` | png/buttons/ibtn_normal.png | 124×124 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | Icon button 56x56 (min 44): icon 24-28 centred, tooltip on hover. |
| `ibtn_hover` | png/buttons/ibtn_hover.png | 124×124 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 |  |
| `ibtn_pressed` | png/buttons/ibtn_pressed.png | 124×124 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 |  |
| `ibtn_disabled` | png/buttons/ibtn_disabled.png | 124×124 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 |  |
| `focus_ring_r14` | png/buttons/focus_ring_r14.png | 160×160 | 48 / 48 / 48 / 48 | 8 / 8 / 8 / 8 | White, tint accent: 2 px gap + 3 px ring around the face and rim (menu_* deep sprites: stretch it 9 px lower). On top of the Background, raycast off. |
| `focus_ring_pill` | png/buttons/focus_ring_pill.png | 224×144 | 72 / 72 / 70 / 70 | 8 / 8 / 8 / 8 | Same for pills and round buttons (logical 96x56 source; any width). |
| `glow_r14` | png/buttons/glow_r14.png | 224×224 | 88 / 88 / 88 / 88 | 24 / 24 / 24 / 24 | Soft glow (white, tint gold / accent) behind a control: attention pulse, aiming, ability ready. |
| `endturn_normal` | png/endturn/endturn_normal.png | 480×480 | — | 36 / 36 / 36 / 36 | Your turn, actions left. Label "End turn" + key badge "Enter". |
| `endturn_hover` | png/endturn/endturn_hover.png | 480×480 | — | 36 / 36 / 36 / 36 | Hover: lighter face + accent.light ring. Also shows next-turn ghost pips on the board (see spec). |
| `endturn_pressed` | png/endturn/endturn_pressed.png | 480×480 | — | 36 / 36 / 36 / 36 | Pressed: darker face; nothing moves. |
| `endturn_enemy` | png/endturn/endturn_enemy.png | 480×480 | — | 36 / 36 / 36 / 36 | Enemy turn: wood face, not interactable; label "Enemy turn" in cream.300. |
| `endturn_attention` | png/endturn/endturn_attention.png | 480×480 | — | 36 / 36 / 36 / 36 | Nothing left to do: gold ring + glow. Pulse endturn_glow alpha on top of this. |
| `endturn_glow` | png/endturn/endturn_glow.png | 480×480 | — | 36 / 36 / 36 / 36 | White glow ring (tint gold) behind the face; animate alpha 0.35-0.9, 1.6 s ping-pong. |
| `badge_cost` | png/badges/badge_cost.png | 124×88 | 44 / 44 / 42 / 44 | 7 / 7 / 7 / 7 | Cost coin: dark wood pill, gold ring. Number Plinth 20 in gold. Min 48 wide; grows with digits. |
| `badge_cost_poor` | png/badges/badge_cost_poor.png | 124×88 | 44 / 44 / 42 / 44 | 7 / 7 / 7 / 7 | Can't afford: ring in bad, number in bad (not grey). |
| `badge_key` | png/badges/badge_key.png | 56×56 | 18 / 18 / 18 / 18 | 2 / 2 / 2 / 2 | Key badge (paper, ink text Plinth 18). Grows for "Enter", "Ctrl 1". |
| `badge_key_dark` | png/badges/badge_key_dark.png | 56×56 | 18 / 18 / 18 / 18 | 2 / 2 / 2 / 2 | Key badge on paper backgrounds / tooltips (cream text). |
| `badge_stack` | png/badges/badge_stack.png | 72×56 | 30 / 30 / 26 / 28 | 2 / 2 / 2 / 2 | Stack count on status icons (hidden at 1). cream.100 Plinth 18. |
| `badge_circle_dark` | png/badges/badge_circle_dark.png | 92×92 | — | 3 / 3 / 3 / 3 | Icon socket in pills (HP heart). |
| `badge_circle_gold` | png/badges/badge_circle_gold.png | 92×92 | — | 3 / 3 / 3 / 3 | Energy coin socket (bolt icon tinted ink). |
| `badge_placed` | png/badges/badge_placed.png | 64×64 | — | 2 / 2 / 2 / 2 | Placed check on a hand card (top-right, replaces the key badge). |
| `hpbar_frame` | png/bars/hpbar_frame.png | 248×36 | 20 / 20 / 16 / 18 | 2 / 2 / 2 / 2 | Inspector HP bar frame (300x14). |
| `hpbar_fill` | png/bars/hpbar_fill.png | 240×28 | 16 / 16 / 12 / 14 | 0 / 0 / 0 / 0 | White with baked shading: tint hp.high / hp.mid / hp.low. Width = parent width x ratio (anchorMax.x); hide under 14 px. |
| `hpbar_ghost` | png/bars/hpbar_ghost.png | 240×28 | 16 / 16 / 12 / 14 | 0 / 0 / 0 / 0 | Flat white: tint hp.ghost 55 %; shrinks to the fill after 0.4 s. |
| `hpbar_plate_frame` | png/bars/hpbar_plate_frame.png | 136×28 | 12 / 12 / 12 / 12 | 2 / 2 / 2 / 2 | World plate over units (64x10). |
| `hpbar_plate_fill` | png/bars/hpbar_plate_fill.png | 128×20 | 6 / 6 / 6 / 6 | 0 / 0 / 0 / 0 | Plate fill and ghost (tint). |
| `pip_wave_on` | png/bars/pip_wave_on.png | 52×20 | 10 / 10 / 8 / 10 | 0 / 0 / 0 / 0 | Tracker wave pip: done / current. |
| `pip_wave_off` | png/bars/pip_wave_off.png | 52×20 | 10 / 10 / 8 / 10 | 0 / 0 / 0 / 0 | Tracker wave pip: to come. |
| `chip_status` | png/chips/chip_status.png | 200×80 | 42 / 42 / 38 / 40 | 2 / 2 / 2 / 2 | Status chip (neutral status): text status, Nunito Bold 20, number Plinth. |
| `chip_good` | png/chips/chip_good.png | 200×80 | 42 / 42 / 38 / 40 | 2 / 2 / 2 / 2 | Buff chip: text good. |
| `chip_bad` | png/chips/chip_bad.png | 200×80 | 42 / 42 / 38 / 40 | 2 / 2 / 2 / 2 | Debuff chip: text bad. |
| `tag_phase_player` | png/chips/tag_phase_player.png | 248×96 | 32 / 32 / 32 / 32 | 2 / 2 / 2 / 2 | "Your turn" tag in the tracker. White Plinth 22. |
| `tag_phase_enemy` | png/chips/tag_phase_enemy.png | 248×96 | 32 / 32 / 32 / 32 | 2 / 2 / 2 / 2 | "Enemy turn" tag. White Plinth 22 (5.6:1). |
| `portrait_ring` | png/badges/portrait_ring.png | 232×232 | — | 10 / 10 / 10 / 10 | Inspector portrait 96: paper disc + cobalt ring. Portrait render goes in a child masked by mask_circle. |
| `portrait_ring_enemy` | png/badges/portrait_ring_enemy.png | 232×232 | — | 10 / 10 / 10 / 10 | Enemy portrait. |
| `mask_circle` | png/badges/mask_circle.png | 192×192 | — | 0 / 0 / 0 / 0 | Mask sprite (Mask component, Show Mask Graphic off). |
| `mask_r8` | png/badges/mask_r8.png | 64×64 | 20 / 20 / 20 / 20 | 0 / 0 / 0 / 0 | Rounded mask for card art wells. |
| `hand_tray` | png/hand/hand_tray.png | 812×342 | 62 / 62 / 54 / 4 | 3 / 3 / 3 / 0 | Tray 168 tall at the bottom edge (bottom corners off-screen), flat wood + thin rim. Padding 0 22 14, gap 6. |
| `nameplate_normal` | png/hand/nameplate_normal.png | 232×72 | 28 / 28 / 26 / 28 | 4 / 4 / 4 / 4 | Name plate 108x28: Nunito ExtraBold 18 cream.100, centred. |
| `nameplate_hover` | png/hand/nameplate_hover.png | 232×72 | 28 / 28 / 26 / 28 | 4 / 4 / 4 / 4 | Hover: accent.light edge. |
| `nameplate_picked` | png/hand/nameplate_picked.png | 232×72 | 28 / 28 / 26 / 28 | 4 / 4 / 4 / 4 | Picked (placing): gold edge. |
| `nameplate_poor` | png/hand/nameplate_poor.png | 232×72 | 28 / 28 / 26 / 28 | 4 / 4 / 4 / 4 | Can't afford: darker plate, name cream.300 (cost coin in bad, render 40 % grey). |
| `nameplate_placed` | png/hand/nameplate_placed.png | 232×72 | 28 / 28 / 26 / 28 | 4 / 4 / 4 / 4 | Placed (tower is on the board): cobalt plate, white name + onboard icon 16 left of it. |
| `nameplate_placed_hover` | png/hand/nameplate_placed_hover.png | 232×72 | 28 / 28 / 26 / 28 | 4 / 4 / 4 / 4 | Placed + hover (its board ring lights up; click selects it). |
| `piece_plinth_empty` | png/hand/piece_plinth_empty.png | 216×104 | — | — | Empty plinth of a placed tower (108x52 at the piece's bottom centre, 34 px above the slot bottom like the render's base). The colour portrait medallion (medallion_ring) stands on it. |
| `medallion_ring` | png/hand/medallion_ring.png | 160×160 | — | 8 / 8 / 8 / 8 | Placed piece: colour portrait medallion 64 standing on the empty plinth (top 26 in the slot). Paper disc + cobalt ring; the portrait is a child Image under a Mask (mask_circle 64), drawn on top of the disc, ring sprite again not needed. |
| `piece_shadow` | png/hand/piece_shadow.png | 208×60 | — | — | Ground shadow under the render (centre 30 px above the slot bottom). Hover: scale 0.75, alpha 0.6; picked: scale 0.6, alpha 0.4. |
| `piece_glow` | png/hand/piece_glow.png | 256×280 | — | — | Soft glow behind the render (tint gold, alpha 0.7) while picked; accent alpha 0.35 on hover is optional. |
| `ability_ready` | png/ability/ability_ready.png | 236×236 | 70 / 70 / 70 / 70 | 17 / 17 / 17 / 17 | Ready: raised wood face. Icon 40 cream.100, key badge top-left (inside), cost badge bottom-right, clock ring around. |
| `ability_hover` | png/ability/ability_hover.png | 236×236 | 70 / 70 / 70 / 70 | 17 / 17 / 17 / 17 | Hover: lifts 5 px (UIFeedback), accent.light edge; range preview on the board + tooltip above the bar. |
| `ability_pressed` | png/ability/ability_pressed.png | 236×236 | 70 / 70 / 70 / 70 | 17 / 17 / 17 / 17 | Pressed: sinks 2 px. |
| `ability_aiming` | png/ability/ability_aiming.png | 236×236 | 70 / 70 / 70 / 70 | 17 / 17 / 17 / 17 | Aiming (waiting for a target): gold edge + glow, stays lifted. Right click / Esc cancels. |
| `ability_cooldown` | png/ability/ability_cooldown.png | 236×236 | 70 / 70 / 70 / 70 | 17 / 17 / 17 / 17 | On cooldown: dark face, icon alpha 0.45 + saturation 40 % (tint), clock ring shows recovered segments, corner badge = turns left. |
| `ability_held` | png/ability/ability_held.png | 236×236 | 70 / 70 / 70 / 70 | 17 / 17 / 17 / 17 | Held cooldown (waits for a reset, e.g. a kill): gold-dark inner line, corner badge shows the lock, ring all dark; tooltip "Ready after a kill". |
| `ability_blocked` | png/ability/ability_blocked.png | 236×236 | 70 / 70 / 70 / 70 | 17 / 17 / 17 / 17 | Ready but cannot be used now (no target, energy, rooted): icon 40 %, faint bad line; click shakes + tooltip reason. |
| `clock_ring_1_0` | png/cooldown/clock_ring_1_0.png | 236×236 | — | 17 / 17 / 17 / 17 | Cooldown 1, 0 of 1 turns recovered (accent.light), 1 dark. |
| `clock_ring_1_ready` | png/cooldown/clock_ring_1_ready.png | 236×236 | — | 17 / 17 / 17 / 17 | Cooldown 1: ready = all segments cobalt + glow. |
| `clock_ring_2_0` | png/cooldown/clock_ring_2_0.png | 236×236 | — | 17 / 17 / 17 / 17 | Cooldown 2, 0 of 2 turns recovered (accent.light), 2 dark. |
| `clock_ring_2_1` | png/cooldown/clock_ring_2_1.png | 236×236 | — | 17 / 17 / 17 / 17 | Cooldown 2, 1 of 2 turns recovered (accent.light), 1 dark. |
| `clock_ring_2_ready` | png/cooldown/clock_ring_2_ready.png | 236×236 | — | 17 / 17 / 17 / 17 | Cooldown 2: ready = all segments cobalt + glow. |
| `clock_ring_3_0` | png/cooldown/clock_ring_3_0.png | 236×236 | — | 17 / 17 / 17 / 17 | Cooldown 3, 0 of 3 turns recovered (accent.light), 3 dark. |
| `clock_ring_3_1` | png/cooldown/clock_ring_3_1.png | 236×236 | — | 17 / 17 / 17 / 17 | Cooldown 3, 1 of 3 turns recovered (accent.light), 2 dark. |
| `clock_ring_3_2` | png/cooldown/clock_ring_3_2.png | 236×236 | — | 17 / 17 / 17 / 17 | Cooldown 3, 2 of 3 turns recovered (accent.light), 1 dark. |
| `clock_ring_3_ready` | png/cooldown/clock_ring_3_ready.png | 236×236 | — | 17 / 17 / 17 / 17 | Cooldown 3: ready = all segments cobalt + glow. |
| `clock_ring_fill` | png/cooldown/clock_ring_fill.png | 236×236 | — | 17 / 17 / 17 / 17 | Alternative to the frames: white ring for Image Filled Radial360 (origin Top, clockwise), tinted; put clock_ring_gaps_N on top. |
| `clock_ring_gaps_2` | png/cooldown/clock_ring_gaps_2.png | 236×236 | — | 17 / 17 / 17 / 17 | Rim-coloured segment gaps for a 2-turn cooldown (over clock_ring_fill). |
| `clock_ring_gaps_3` | png/cooldown/clock_ring_gaps_3.png | 236×236 | — | 17 / 17 / 17 / 17 | Rim-coloured segment gaps for a 3-turn cooldown (over clock_ring_fill). |
| `cd_badge` | png/cooldown/cd_badge.png | 120×120 | — | 11 / 11 / 11 / 11 | Corner badge (38, centre on the button's top-right corner, 12 px out): turns left, Plinth 22 cream.100. Held: lock icon 20 gold instead. |
| `cd_badge_soon` | png/cooldown/cd_badge_soon.png | 120×120 | — | 11 / 11 / 11 / 11 | "Ready next turn" (1 left): glow baked; pulse alpha between cd_badge and this over 1.1 s. |
| `pip_ability_ready` | png/cooldown/pip_ability_ready.png | 80×84 | — | 6 / 6 / 6 / 8 | Board pip (28) per ability: ready. Flash on refill (scale 1.45, 0.6 s). |
| `pip_ability_wait` | png/cooldown/pip_ability_wait.png | 80×84 | — | 6 / 6 / 6 / 8 | Waiting: turns left on it (Plinth 18 cream.100). |
| `pip_ability_held` | png/cooldown/pip_ability_held.png | 80×84 | — | 6 / 6 / 6 / 8 | Held: lock icon 16 gold on it. |
| `pip_ability_ghost` | png/cooldown/pip_ability_ghost.png | 80×84 | — | 6 / 6 / 6 / 8 | Preview while End turn is hovered: will be ready next turn. |
| `pip_mini_ready` | png/cooldown/pip_mini_ready.png | 52×54 | — | 4 / 4 / 4 / 5 | Mini pip 18 for a placed hand piece (same meaning as the board pips). |
| `pip_mini_wait` | png/cooldown/pip_mini_wait.png | 52×54 | — | 4 / 4 / 4 / 5 | Mini pip waiting: number Plinth 18 is too big for 18 px; show the number only on hover (tooltip), or no number. |
| `pip_mini_held` | png/cooldown/pip_mini_held.png | 52×54 | — | 4 / 4 / 4 / 5 | Mini pip held (gold-dark line). |
| `ready_glow` | png/cooldown/ready_glow.png | 256×256 | — | — | Ground glow under a tower that can still act (>= 1 ready ability): flat quad on the tile, tint accent alpha 0.45, breathe 1.6 s. |
| `cooldown_ring` | png/cooldown/cooldown_ring.png | 128×128 | — | 0 / 0 / 0 / 0 | Small radial clock (Filled Radial360) for round things: enemy intent chip "long cooldown", enemy card abilities. |
| `badge_ready_pop` | png/cooldown/badge_ready_pop.png | 204×84 | 44 / 44 / 40 / 40 | 3 / 3 / 3 / 3 | "Ready!" pop over a tower when an ability comes off cooldown at turn start. Text ink, Plinth 22. |
| `decal_enemy_path` | png/board/decal_enemy_path.png | 256×256 | — | — | Tile decal (1 tile = 128 px texture): enemy path step. Quad on the tile top, unlit transparent. |
| `decal_enemy_stop` | png/board/decal_enemy_stop.png | 256×256 | — | — | Tile where the enemy stops: solid + inner glow. |
| `decal_target_valid` | png/board/decal_target_valid.png | 256×256 | — | — | Valid target while aiming: pulse alpha 1 -> 0.55, 0.9 s. |
| `decal_heal_valid` | png/board/decal_heal_valid.png | 256×256 | — | — | Valid ally target for heals / buffs (green), same pulse. |
| `line_attack_dash` | png/board/line_attack_dash.png | 48×20 | — | — | Dash 14 + gap 10 (one period, wrap Repeat). LineRenderer width 6-8 px equivalent, Texture Mode Tile, scroll offset -24 px / 0.6 s. |
| `line_attack_end` | png/board/line_attack_end.png | 48×48 | — | — | Arc end dot on the target. |
| `stripes_damage_preview` | png/board/stripes_damage_preview.png | 24×24 | — | — | Predicted HP loss on a plate / HP bar: RawImage, uvRect.width = rect.width / 12, blink alpha 1 -> 0.45 over 0.7 s. |
| `stripes_heal_preview` | png/board/stripes_heal_preview.png | 24×24 | — | — | Predicted heal (green). |
| `tag_kills` | png/board/tag_kills.png | 152×56 | 26 / 26 / 24 / 26 | 2 / 2 / 2 / 2 | "Kills" / "Öldürür" tag 30 px above a plate when the preview is lethal. White Plinth 18. |
| `intent_attack` | png/board/intent_attack.png | 140×84 | 44 / 44 / 40 / 40 | 3 / 3 / 3 / 3 | Enemy intent: sword / castle icon 22 + damage (Plinth 20 cream.100). Castle (hits the base) pulses intent_glow. |
| `intent_move` | png/board/intent_move.png | 140×84 | 44 / 44 / 40 / 40 | 3 / 3 / 3 / 3 | Enemy intent: move, back-arrow icon + tiles (← 2). |
| `intent_wait` | png/board/intent_wait.png | 140×84 | 44 / 44 / 40 / 40 | 3 / 3 / 3 / 3 | Enemy intent: waits (clock icon only, or cooldown_ring + turns for a long cooldown). |
| `intent_glow` | png/board/intent_glow.png | 256×176 | 92 / 92 / 80 / 80 | 24 / 24 / 24 / 24 | White glow behind an intent chip (tint fx.damage): "hits the base" threat pulse 1.2 s. |
| `ribbon_enemy` | png/board/ribbon_enemy.png | 400×96 | 88 / 88 / 20 / 20 | — | Enemy action name ("Smash!") over the acting enemy: white Plinth 30 + 2 px black shadow; pop 1.1 s. |
| `chip_unit_status` | png/board/chip_unit_status.png | 92×72 | 38 / 38 / 34 / 32 | 3 / 3 / 3 / 3 | Status over a unit (always visible): icon 18 + stacks Plinth 18 cream. Neutral / control status. |
| `chip_unit_debuff` | png/board/chip_unit_debuff.png | 92×72 | 38 / 38 / 34 / 32 | 3 / 3 / 3 / 3 | Damage-over-time / debuff (burn, poison). |
| `chip_unit_buff` | png/board/chip_unit_buff.png | 92×72 | 38 / 38 / 34 / 32 | 3 / 3 / 3 / 3 | Buff (shield, focus). |
| `atk_melee_chevron_enemy` | png/attack/atk_melee_chevron_enemy.png | 80×64 | — | — | Melee: short solid chevron on the edge between attacker and target tile (world quad, rotated to the direction). |
| `atk_line_dash_enemy` | png/attack/atk_line_dash_enemy.png | 48×20 | — | — | Projectile: straight dashed LOW line (2 points, ~0.3 m above the tiles), stops at the first blocker. Repeat wrap, scroll 1 period / 0.6 s. |
| `atk_lob_dots_enemy` | png/attack/atk_lob_dots_enemy.png | 32×20 | — | — | Lobbed: dotted HIGH arc: LineRenderer with N = 16-24 points on a parabola (apex = 0.35 × distance), ignores blockers. |
| `atk_beam_enemy` | png/attack/atk_beam_enemy.png | 16×28 | — | — | Beam: solid line (2 points, Stretch texture mode). Every unit on it gets its own damage preview. |
| `atk_spell_link_enemy` | png/attack/atk_spell_link_enemy.png | 32×12 | — | — | Spell: no attack line; only this faint link (caster → target, alpha 0.45) plus the rune under the target. |
| `atk_impact_ring_enemy` | png/attack/atk_impact_ring_enemy.png | 256×256 | — | — | Lobbed: impact ring decal on the landing tile. |
| `atk_splash_enemy` | png/attack/atk_splash_enemy.png | 256×256 | — | — | Splash area: one decal per tile in the area (dotted = area, not path). |
| `atk_rune_enemy` | png/attack/atk_rune_enemy.png | 256×256 | — | — | Spell: rune decal under the target (slow spin 8 s / turn). |
| `atk_melee_chevron_player` | png/attack/atk_melee_chevron_player.png | 80×64 | — | — | Melee: short solid chevron on the edge between attacker and target tile (world quad, rotated to the direction). |
| `atk_line_dash_player` | png/attack/atk_line_dash_player.png | 48×20 | — | — | Projectile: straight dashed LOW line (2 points, ~0.3 m above the tiles), stops at the first blocker. Repeat wrap, scroll 1 period / 0.6 s. |
| `atk_lob_dots_player` | png/attack/atk_lob_dots_player.png | 32×20 | — | — | Lobbed: dotted HIGH arc: LineRenderer with N = 16-24 points on a parabola (apex = 0.35 × distance), ignores blockers. |
| `atk_beam_player` | png/attack/atk_beam_player.png | 16×28 | — | — | Beam: solid line (2 points, Stretch texture mode). Every unit on it gets its own damage preview. |
| `atk_spell_link_player` | png/attack/atk_spell_link_player.png | 32×12 | — | — | Spell: no attack line; only this faint link (caster → target, alpha 0.45) plus the rune under the target. |
| `atk_impact_ring_player` | png/attack/atk_impact_ring_player.png | 256×256 | — | — | Lobbed: impact ring decal on the landing tile. |
| `atk_splash_player` | png/attack/atk_splash_player.png | 256×256 | — | — | Splash area: one decal per tile in the area (dotted = area, not path). |
| `atk_rune_player` | png/attack/atk_rune_player.png | 256×256 | — | — | Spell: rune decal under the target (slow spin 8 s / turn). |
| `atk_blocked_x` | png/attack/atk_blocked_x.png | 80×80 | — | — | Blocked: screen-space marker where the shot stops (on the blocker). The blocker gets the damage preview; the aimed target is greyed (plate alpha 0.4, no stripes) with a chip "Blocked by Wall" (paper_stat, ink.2). |
| `atk_redirect` | png/attack/atk_redirect.png | 80×80 | — | — | Redirected (Bodyguard, Taunt): marker at the bend; the line goes from the original target to the new one, tooltip names the cause. |
| `btn_wood_normal` | png/screens/btn_wood_normal.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | .k-btn: secondary button on screens (dark band). |
| `btn_wood_hover` | png/screens/btn_wood_hover.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | .k-btn.is-hover (+ scale 1.03). |
| `btn_wood_pressed` | png/screens/btn_wood_pressed.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | .k-btn.is-pressed: face 4 px lower; move the label with it. |
| `btn_wood_disabled` | png/screens/btn_wood_disabled.png | 332×132 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | .k-btn.is-disabled (label cream.300, tooltip says why). |
| `tab_normal` | png/screens/tab_normal.png | 292×124 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | .k-tab: Plinth 26 cream.200, icon 24, padding 0 24, height 56. |
| `tab_hover` | png/screens/tab_hover.png | 292×124 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | .k-tab.is-hover: label cream.100. |
| `tab_selected` | png/screens/tab_selected.png | 292×124 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | .k-tab.is-active: white label, cobalt band below. |
| `row_normal` | png/screens/row_normal.png | 420×140 | 38 / 38 / 38 / 38 | 5 / 5 / 5 / 5 | .k-row: min height 60, padding 6 16 6 8, gap 14, Nunito Bold 22 cream.100 (Codex list, level list). |
| `row_hover` | png/screens/row_hover.png | 420×140 | 38 / 38 / 38 / 38 | 5 / 5 / 5 / 5 | .k-row.is-hover. |
| `row_selected` | png/screens/row_selected.png | 420×140 | 38 / 38 / 38 / 38 | 5 / 5 / 5 / 5 | .k-row.is-selected: white text, accent.light ring. |
| `row_locked` | png/screens/row_locked.png | 420×140 | 38 / 38 / 38 / 38 | 5 / 5 / 5 / 5 | .k-row.is-locked: cream.300 text + lock_badge; tooltip / sub line says how to unlock. |
| `slider_track` | png/screens/slider_track.png | 256×48 | 26 / 26 / 22 / 22 | 4 / 4 / 4 / 4 | .k-slider .track: height 16, full width. |
| `slider_fill` | png/screens/slider_fill.png | 248×40 | 22 / 22 / 18 / 18 | 2 / 2 / 2 / 2 | .k-slider .fill (Slider Fill Rect). |
| `slider_knob_normal` | png/screens/slider_knob_normal.png | 104×104 | — | 8 / 8 / 8 / 8 | .k-slider .knob 36 (Slider Handle). |
| `slider_knob_hover` | png/screens/slider_knob_hover.png | 104×104 | — | 8 / 8 / 8 / 8 | .k-slider.is-hover .knob: accent.light ring (also keyboard focus). |
| `slider_knob_pressed` | png/screens/slider_knob_pressed.png | 104×104 | — | 8 / 8 / 8 / 8 | Dragging: darker paper, sunk 3 px. |
| `value_box` | png/screens/value_box.png | 176×96 | 28 / 28 / 28 / 28 | 2 / 2 / 2 / 2 | .k-value: slider read-out, Plinth 24 cream.100. |
| `toggle_off` | png/screens/toggle_off.png | 160×88 | — | 2 / 2 / 2 / 2 | .k-toggle (off): 76x40 with the knob left. Always with the word "Off" (Nunito ExtraBold 20 cream.200) 14 px to the right. |
| `toggle_on` | png/screens/toggle_on.png | 160×88 | — | 2 / 2 / 2 / 2 | .k-toggle.is-on: cobalt, knob right; word "On" cream.100. |
| `toggle_track_off` | png/screens/toggle_track_off.png | 160×88 | 44 / 44 / 42 / 42 | 2 / 2 / 2 / 2 | Track only (if the knob animates as its own Image). |
| `toggle_track_on` | png/screens/toggle_track_on.png | 160×88 | 44 / 44 / 42 / 42 | 2 / 2 / 2 / 2 | Track only, on. |
| `toggle_knob` | png/screens/toggle_knob.png | 80×84 | — | 4 / 4 / 4 / 6 | Knob 32; slides 36 px in 0.15 s ease.out. |
| `dropdown_normal` | png/screens/dropdown_normal.png | 344×128 | 40 / 40 / 40 / 40 | 6 / 6 / 6 / 6 | .k-select: min 300x52, padding 0 12 0 18, Nunito Bold 22 ink, arrow = icon_next 24 tinted ink at the right. |
| `dropdown_hover` | png/screens/dropdown_hover.png | 344×128 | 40 / 40 / 40 / 40 | 6 / 6 / 6 / 6 | Hover / focus. |
| `dropdown_open` | png/screens/dropdown_open.png | 344×128 | 40 / 40 / 40 / 40 | 6 / 6 / 6 / 6 | Open (arrow flips 180). |
| `dropdown_list` | png/screens/dropdown_list.png | 332×252 | 34 / 34 / 34 / 34 | 3 / 3 / 3 / 3 | Options panel under the field (padding 6). |
| `dropdown_item_hover` | png/screens/dropdown_item_hover.png | 320×88 | 20 / 20 / 20 / 20 | 0 / 0 / 0 / 0 | Hovered / selected option (ink text stays). |
| `dropdown_arrow` | png/screens/dropdown_arrow.png | 64×64 | — | — | White chevron (tint ink); same as icon_next. |
| `scrollbar_track` | png/screens/scrollbar_track.png | 32×136 | 16 / 16 / 18 / 18 | 2 / 2 / 2 / 2 | .k-scrollbar: 12 wide, 6 from the right edge. |
| `scrollbar_handle_normal` | png/screens/scrollbar_handle_normal.png | 32×136 | 16 / 16 / 18 / 18 | 2 / 2 / 2 / 2 | .k-scrollbar i. |
| `scrollbar_handle_hover` | png/screens/scrollbar_handle_hover.png | 32×136 | 16 / 16 / 18 / 18 | 2 / 2 / 2 / 2 | Hover / drag. |
| `scrollbar_track_paper` | png/screens/scrollbar_track_paper.png | 32×136 | 16 / 16 / 18 / 18 | 2 / 2 / 2 / 2 | On paper (credits roll). |
| `scrollbar_handle_paper` | png/screens/scrollbar_handle_paper.png | 32×136 | 16 / 16 / 18 / 18 | 2 / 2 / 2 / 2 | Handle on paper. |
| `keyslot_normal` | png/screens/keyslot_normal.png | 456×152 | 52 / 52 / 52 / 52 | 14 / 14 / 14 / 14 | .k-slot: 200x48, Plinth 22 ink ("Enter", "Ctrl 1"). |
| `keyslot_hover` | png/screens/keyslot_hover.png | 456×152 | 52 / 52 / 52 / 52 | 14 / 14 / 14 / 14 | .k-slot.is-hover (also focus). |
| `keyslot_listening` | png/screens/keyslot_listening.png | 456×152 | 52 / 52 / 52 / 52 | 14 / 14 / 14 / 14 | .k-slot.is-listening: "Press a key…" Nunito ExtraBold 20 white; Esc cancels, Backspace clears. |
| `keyslot_conflict` | png/screens/keyslot_conflict.png | 456×152 | 52 / 52 / 52 / 52 | 14 / 14 / 14 / 14 | .k-slot.is-conflict: bad.ink text + warning; the note row under it names the other action. |
| `keyslot_empty` | png/screens/keyslot_empty.png | 456×152 | 52 / 52 / 52 / 52 | 14 / 14 / 14 / 14 | .k-slot.is-empty ("Not set"): Nunito Bold 20 cream.300. |
| `close_normal` | png/screens/close_normal.png | 116×116 | — | 3 / 3 / 3 / 3 | .k-close 52x52 (x baked, cream + rim). Top-right of windows; Esc / right click do the same. |
| `close_hover` | png/screens/close_hover.png | 116×116 | — | 3 / 3 / 3 / 3 | .k-close hover. |
| `close_pressed` | png/screens/close_pressed.png | 116×116 | — | 3 / 3 / 3 / 3 | .k-close pressed (face 3 px lower). |
| `ibtn_flat_normal` | png/screens/ibtn_flat_normal.png | 116×116 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | .k-ibtn 52 (no band; put any icon on it). |
| `ibtn_flat_hover` | png/screens/ibtn_flat_hover.png | 116×116 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | .k-ibtn hover. |
| `ibtn_flat_pressed` | png/screens/ibtn_flat_pressed.png | 116×116 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | .k-ibtn pressed. |
| `kbd_paper` | png/screens/kbd_paper.png | 68×68 | 20 / 20 / 20 / 20 | 2 / 2 / 2 / 2 | .k-kbd keycap 30 high, Plinth 18 ink, padding 0 8. |
| `kbd_wood` | png/screens/kbd_wood.png | 68×68 | 20 / 20 / 20 / 20 | 2 / 2 / 2 / 2 | .k-kbd-dark (cream text). |
| `dialogue_nameplate` | png/screens/dialogue_nameplate.png | 332×124 | 38 / 38 / 38 / 38 | 3 / 3 / 3 / 3 | .vn-box .vn-name: wood plate (blue = active only) overlapping the dialogue box top-left (left 36, top -30), padding 0 26, speaker name Plinth 28 teal + role Nunito ExtraBold 18 cream.300. |
| `speaker_frame` | png/screens/speaker_frame.png | 372×452 | 80 / 80 / 80 / 82 | 3 / 3 / 3 / 3 | Framed speaker portrait (codex / small dialogue). The big VN bust (~440x560) stands free without a frame. |
| `loadbar_track` | png/screens/loadbar_track.png | 332×56 | 32 / 32 / 30 / 30 | 3 / 3 / 3 / 3 | .boot-bar: 760x22, cobalt band below. |
| `loadbar_fill` | png/screens/loadbar_fill.png | 120×32 | 18 / 18 / 14 / 16 | 0 / 0 / 0 / 0 | .boot-bar i: inset 3 px in the track; width = progress. |
| `loadbar_glow` | png/screens/loadbar_glow.png | 168×80 | 44 / 44 / 38 / 38 | 12 / 12 / 12 / 12 | Glow behind the fill (same rect). |
| `codex_stage` | png/screens/codex_stage.png | 400×400 | 36 / 36 / 36 / 36 | 0 / 0 / 0 / 0 | .stage: paper stage behind the 3D model (the RenderTexture / camera view sits on top). |
| `codex_plinth` | png/screens/codex_plinth.png | 496×180 | — | 4 / 4 / 4 / 22 | .stage .plinth 240x64 (if the model has no base of its own). |
| `chapter_header` | png/screens/chapter_header.png | 400×88 | 140 / 8 / 4 / 4 | — | .chap: header line under "Chapter 1" (Plinth 26 cream.200; count Nunito ExtraBold 18 cream.300 at the right). |
| `level_number` | png/screens/level_number.png | 88×88 | — | 2 / 2 / 2 / 2 | .chapters .num: level number disc, Plinth 22 ink. |
| `level_number_locked` | png/screens/level_number_locked.png | 88×88 | — | 2 / 2 / 2 / 2 | Locked number disc (cream.300). |
| `new_dot` | png/screens/new_dot.png | 60×60 | — | 8 / 8 / 8 / 8 | .k-new: dot 14 + the word "New" (Nunito ExtraBold 18 accent.light) - colour is never the only signal. |
| `lock_badge` | png/screens/lock_badge.png | 104×104 | — | 4 / 4 / 4 / 4 | .k-medal.is-locked: 44 disc with the lock (cream.300 + rim). |
| `medal_ring` | png/screens/medal_ring.png | 120×120 | — | 6 / 6 / 6 / 6 | .k-medal: 48 portrait medal in list rows (portrait under mask_circle). |
| `medal_ring_enemy` | png/screens/medal_ring_enemy.png | 120×120 | — | 6 / 6 / 6 / 6 | .k-medal.is-enemy. |
| `well` | png/screens/well.png | 328×248 | 36 / 36 / 36 / 36 | 2 / 2 / 2 / 2 | .k-well: sunken area inside a window (lists, pages). |
| `wood_grain_tile` | png/backgrounds/wood_grain_tile.png | 128×128 | — | — | Tileable grain overlay (Image Type Tiled, alpha 0.6-1) for big wood panels. |
| `backdrop_wood` | png/backgrounds/backdrop_wood.png | 1920×1080 | — | — | Full-screen table backdrop for menus (1920x1080, PPU multiplier 1). |
| `vignette` | png/backgrounds/vignette.png | 960×540 | — | — | HUD vignette, stretch full screen, raycast off (multiplier 0.5). |
| `scrim_menu` | png/backgrounds/scrim_menu.png | 960×540 | — | — | Main menu: darkens the left column over the 3D backdrop (stretch full screen). |
| `scrim_welcome` | png/backgrounds/scrim_welcome.png | 960×540 | — | — | Welcome: radial scrim over the blurred level backdrop. |

## Icons (46, white, 64×64 px, 4 px padding, 24-unit grid with 2.2 strokes; png/icons/icon_<name>.png)
`pause` · `play` · `fast-forward` · `skip` · `settings` · `codex` · `credits` · `quit` · `continue` · `info` · `close` · `lock` · `check` · `heart` · `energy` · `power` · `range` · `speed` · `armour` · `sell` · `wave` · `shoot` · `move` · `eye` · `plus` · `sound` · `music` · `keyboard` · `monitor` · `cooldown` · `sliders` · `misc` · `walk` · `volley` · `cards` · `edit` · `back` · `castle` · `clock` · `onboard` · `del-melee` · `del-arrow` · `del-arc` · `del-spark` · `del-beam` · `next`

Role names: power = damage/attack stat, armour = shield, sell = coin, wave = flag, shoot = arrow ability, move = tower walk, continue = resume, codex = book, credits = star, misc = grid, cooldown = hourglass, castle = the base, clock = waits / cooldown, back = intent move.
