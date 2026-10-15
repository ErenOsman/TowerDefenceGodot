# Style B "Painted Diorama": Unity build spec for Welcome, Main menu and Battle HUD (2026-10-08)

From: the UI/UX agent (wiki server). For: the game's agent and Eren. Game commit read: `96c7637`. Nothing here is in the game yet.
Read first: AGENTS.md Rules 5, 7, 11-14, 17; the component plan `notes/2026-10-08-ui-components-plan.md` (UITheme, UITweener,
UIFeedback, UIStateVisual, UI_Badge, TooltipPlacement…). This spec gives the values and the per-screen build; the plan gives the classes.

**Assets:** the sprite kit at http://92.5.94.11/art/ui/kit-b/ (`kit-b.zip`: `png/`, `slices.json`, `tokens.json`, `README.md`,
`unity/KitBImport.cs`, `sheet.png`, fonts). Reference looks: `mockups/art-direction/b-welcome.html`, `b-menu.html`, `b-hud.html`
(http://92.5.94.11/art/ui/art-direction/) and the playable prototype http://92.5.94.11/art/ui/prototype/ (cooldowns, board previews, hand tray).

**Decisions since the B mockups (user, 2026-10-08), all in this spec:**
1. Hand = a **tray of miniatures** (no cards, no fan): `UI_HandPiece` + `UI_HandTray` replace `UI_HandCard` + `UI_HandFan` from the plan.
   A placed tower's piece stays in the tray as an empty plinth with a colour portrait medallion, HP and cooldown pips.
2. **Cooldowns are the core resource.** Ability buttons show a segmented **clock ring** + a **corner badge** (not a big centred number).
   Every tower on the board shows one pip per ability. Ready towers glow. "Ready!" pops at turn start.
3. **Board previews**: enemy intent chips, path / stop decals, dashed attack arc, striped HP-loss preview, "Kills" tag, red name ribbon.
4. **Statuses over units are always visible**; only the HP bar follows the hover rule. (This corrects component plan §3.6, which said the
   whole plate fades.)
5. Keys are today's bindings (`GameKeys.cs`): abilities **1-9** (Shift+N quick cast, Ctrl+N hand piece), **End round = Enter** (also Shift+Space),
   **Space = skip / continue**, **P or Esc = pause** (Esc first cancels aiming / placing), **right click = cancel / deselect**, camera WASD + Q/E.
   The B mockup's Q/W/E/R ability keys stay an open question for Eren. Key labels always come from `InputBindings.Describe(...)`, never hard-coded.

6. **(2026-10-09) Blue = active, depth only in menus.** Every sprite is FLAT by default: face + thin rim (1 px, 2 px in the PNG) + soft top highlight,
   no bottom side, no press-sink; states by colour only (hover lighter, pressed darker, selected = cobalt ring/fill, disabled dimmed). The extruded side
   + sink exist only as `menu_btn_primary_*`, `menu_btn_wood_*` (dark wood side), `menu_panel`, `menu_panel_r14`: Welcome (plaque = `menu_panel`, Start =
   `menu_btn_primary_*`) and the main menu list (Continue = `menu_btn_primary_*`, others = `menu_btn_wood_*`). Cobalt only on: primary buttons,
   selected / hover / focus states, End turn (now a flat round cobalt button), tower medallion rings and 3D plinths. Where this spec mentions a
   band, a sink or "Label -4 px" for a non-menu sprite, it no longer applies; outsets are in `slices.json` / `manifest_ui.json` (3 px all round for flat sprites).

Live build check: /play is the 2026-10-05 build. UI commits since then (`git log --since=2026-10-05 -- Assets/Scripts/UI Assets/Editor/UI`)
touch range previews only (`e61ff7b`). The Welcome, Main menu and HUD screenshots in `~/uiux/out/play/ar-1080/` still show today's screens.

---

## 1. Importing the kit

- Copy `png/<group>/*.png` to `Assets/Art/UI/KitB/<group>/` (Folder Structure doc: interface-only sprites live in `Art/UI`).
  Copy `unity/KitBImport.cs` to `Assets/Editor/UI/KitBImport.cs` (Rule 9). It is an `AssetPostprocessor` that applies, to every file under
  `Assets/Art/UI/KitB/`:
  - Texture Type **Sprite (2D and UI)**, Sprite Mode **Single**, Mesh Type **Full Rect** (needed for 9-slice), sRGB on, Alpha Is Transparency on.
  - **Border** (`spriteBorder`, Vector4 left, bottom, right, top) from `slices.json`.
  - **Compression None**, **Mip Maps off**. Exception: `icon_*` has mip maps on (64 px sources shown at 20-40 px; without mips they shimmer at 1280x720).
  - Filter Bilinear, Wrap **Clamp**. Wrap **Repeat** for `wood_grain_tile`, `line_attack_dash`, `stripes_damage_preview`, `stripes_heal_preview`.
  - Non-Power-of-2 None, Max Size 4096. Pixels Per Unit **200** by default (the game's current import; see the PPU note below).
  - Hand-applied alternative: the same values in the Inspector; the borders are in the README table.
- **Pixels Per Unit Multiplier = 2** on every Image that uses a kit sprite (the PNGs are 2x the 1920x1080 reference). `UITheme` holds the value
  (`spritePpuMultiplier = 2`) and the builders set it; don't use Set Native Size (it gives 2x).
- Image Type: **Sliced** for sprites with a border (Fill Center on), **Simple** + Preserve Aspect for the rest, **Filled Radial 360**
  for `clock_ring_fill` and `cooldown_ring`, **Tiled** for `wood_grain_tile`.
- **Outsets:** rims, bands and glows sit outside the control's rect. A control's `"Background"` child stretches to the parent (anchors 0,0-1,1)
  with `offsetMin = (-outset.l, -outset.b)`, `offsetMax = (outset.r, outset.t)` (`outsetRef` in `slices.json`). The control's own rect
  stays the logical size in this spec, so layouts and hit areas don't include the band. Raycast Target off on Background and on every glow.
- Fonts: TMP font assets from `~/uiux/fonts-for-unity` (in the zip): **Plinth-Bold** (display, buttons, numbers) and **Nunito Medium / Bold /
  ExtraBold** (body). Include Turkish characters (ÇĞİıÖŞÜçğöşü). Ship `Nunito-OFL.txt`. Put them in `Assets/Art/Fonts/`.
  Plinth SDF: padding 9, atlas 1024. Nunito: padding 7.

---

## 2. `UITheme` values (style B)

One ScriptableObject (`Assets/Data/Settings/UITheme.asset`; script in `Scripts/UI/CoreUI/UITheme.cs`, `UITheme.Current`). Builders and
runtime read it; no colour literals in builders (user decision). Token names below are the field names (dots → nested or camelCase).

### 2.1 Colours

| Token | Hex | Use |
| --- | --- | --- |
| `wood.900` | #17110D | sockets, HP bar trough, stack badge |
| `wood.850` | #211913 | backdrops, cooldown face bottom |
| `wood.800` | #2A211B | panel face bottom, cooldown face |
| `wood.700` | #3A2D24 | tooltip icon tile, pressed secondary |
| `wood.600` | #4A3A2E | locked/benched face, separators on paper |
| `wood.500` | #5E4A3A | dividers, pip off, field ring, name plate top |
| `wood.top` / `wood.mid` / `wood.bottom` | #43342A / #33271F / #2A211B | panel face gradient 0 / 45 / 100 % (baked) |
| `rim` | #120C09 | outlines, text shadow on wood |
| `band` / `band.dark` | #3F78C9 / #2B5594 | cobalt plinth band (player) |
| `band.enemy` | #D94040 | enemy inspector band, enemy portrait ring |
| `cream.100` | #F5EAD6 | text on wood (12.2:1 on wood.mid) |
| `cream.200` | #DCCAAE | secondary text on wood (9.0:1) |
| `cream.300` | #BDA98C | muted text on wood (6.4:1), disabled labels |
| `paper` / `paper.2` / `paper.top` / `paper.bottom` / `paper.edge` | #EEE2C6 / #E2D2B0 / #F3E8CF / #E6D7B6 / #B89F78 | tooltips, stat tiles, fields |
| `ink` / `ink.2` | #2E2117 / #5F4936 | text on paper (12.1:1 / 5.7:1) |
| `accent` | #4D8FE6 | selection, focus ring, player |
| `accent.fill` | #3A6BB0 | primary buttons, phase tag, placed name plate (white text 5.4:1) |
| `accent.light` | #8DBBFF | tower names on wood, hover edges, recovered clock segments |
| `gold` / `gold.light` / `gold.dark` | #FFD46B / #FFE7A6 / #C9952A | energy, costs, aiming, picked, attention |
| `teal` | #5ED6C7 | speaker names, rewards |
| `good` / `bad` / `status` / `warn` | #7EE08A / #FF7A6B / #C59BFF / #FF991A | role colours on wood |
| `gold.ink` / `good.ink` / `bad.ink` / `status.ink` / `accent.ink` | #7A4E00 / #2D7238 / #A3301F / #6B3FB0 / #2B5594 | role colours on paper (all ≥ 4.5:1) |
| `chip.status.bg` / `chip.good.bg` / `chip.bad.bg` | #2A1F3A / #1D3322 / #3A1D1A | inspector status chips |
| `hp.high` / `hp.mid` / `hp.low` / `hp.ghost` | #33D94D / #F2D926 / #E62626 / #FF4D40 (55 %) | HP fills (> 60 % / > 30 % / below) |
| `fx.damage` / `fx.heal` / `fx.status` | #FF4D40 / #66FF73 / #D999FF | floating numbers, previews |
| `team.player` / `team.enemy` | #4080F2 / #D94040 | board team colours |
| `scrim` | #17110D at 88 % | behind windows (Welcome uses the radial `scrim_welcome` sprite) |

Gradients are baked in the sprites (`tokens.js` has every stop). Keep them in the theme anyway so builders can tint white sprites.

### 2.2 Type (TMP)

| Style | Font | Size | Colour (default) | Notes |
| --- | --- | --- | --- | --- |
| `type.display` | Plinth-Bold | 64 | cream.100 | banners ("Your turn" sweep 88 is the only bigger one) |
| `type.plaqueTitle` | Plinth-Bold | 56 | cream.100 | Welcome title (approved mockup). New size: see §8 |
| `type.h1` | Plinth-Bold | 44 | cream.100 | floating damage numbers 44-56 with 8 px outline |
| `type.h2` | Plinth-Bold | 32 | accent.light | inspector name (34 in the mockup → 32), pill numbers |
| `type.h3` | Plinth-Bold | 26-28 | ink / cream.100 | tooltip title 28, menu buttons 28, tracker round 28 |
| `type.button` | Plinth-Bold | 30 (wide) / 26 / 22 | white or cream.100 | primary 30, menu 28, small (Sell) 22 |
| `type.body` | Nunito Medium | 22 | ink (paper) / cream.200 (wood) | line spacing 1.25 → TMP Line Spacing 0 + font asset line height ×1.25 |
| `type.small` | Nunito Bold | 20 | ink.2 / cream.300 | labels, tags, help lines |
| `type.micro` | Plinth-Bold | 18 | per role | numbers only: keys, costs, pips, stacks |
| `type.plate` | Nunito ExtraBold | 18 | cream.100 | hand name plates |

Nothing under 18. Text over the board (floaters, ribbon, intents) gets an outline 0.2 at rim 80 % or a 2 px shadow; text on wood or paper doesn't.

### 2.3 Spacing, radii, sizes

- Grid 4: `space.4/8/12/16/20/24/32/48`. Safe margin **32** left/right, **16-20** top/bottom for the HUD.
- Radii (baked in sprites): `radius.chip 10-12`, `radius.control 14` (buttons, panels, pills), `radius.ability 16`, `radius.window 22`.
- Sizes: primary button 220×60 (wide 320×68), menu button 440×64 (Continue 440×96), icon button 56×56 (min 44), ability button 84×84,
  hand piece slot 124×150 (placed: 124×160), tray height 168, End turn 168×168, tooltip width 380 (min 300, max 420), inspector width 340.

### 2.4 Motion

| Token | Value | Curve |
| --- | --- | --- |
| `motion.instant` | 0.10 s | linear (colour swaps) |
| `motion.quick` | 0.18 s | `ease.lift` (hover lift, press) |
| `motion.normal` | 0.25 s | `ease.out` (slides, panel open) |
| `motion.slow` | 0.50 s | `ease.inOut` (banner, camera glide) |
| `ease.out` | cubic-bezier(.2,.8,.2,1) | AnimationCurve keys (0,0 tangent 4) (1,1 tangent 0) |
| `ease.lift` | cubic-bezier(.2,.9,.3,1.25) | overshoot: (0,0) (0.6,1.06) (1,1) |
| `ease.inOut` | cubic-bezier(.4,0,.2,1) | smoothstep-like |
| `pulse.attention` | 1.6 s ping-pong | glow alpha 0.35 ↔ 0.9, scale 1.00 ↔ 1.03 |
| `pulse.soon` | 1.1 s ping-pong | cd badge glow (cd_badge ↔ cd_badge_soon) |
| `pulse.target` | 0.9 s ping-pong | target decals alpha 1 ↔ 0.55 |
| `pulse.threat` | 1.2 s ping-pong | intent_glow alpha 0 ↔ 0.8 |
| `blink.preview` | 0.7 s ping-pong | stripes alpha 1 ↔ 0.45 |
| `tooltip.delay` | 0.4 s | stack delay 0.4 s too |

All HUD motion uses **unscaled time** (`UITweener`).

### 2.5 FeedbackProfiles (per control kind)

| Profile | Hover | Press | Denied (disabled click) | Other |
| --- | --- | --- | --- | --- |
| `Button` (primary/secondary/danger) | sprite → hover, scale 1.00, lift 0 | sprite → pressed (face 4 px lower), **Label/Icon offset -4 px**, scale 0.98, 0.1 s | shake x ±6 px, 0.32 s, 3 swings; tooltip shows reason | spawn: scale 0.9→1 + alpha, 0.2 s ease.lift |
| `MenuButton` | sprite → hover (wood) / primary_hover, **scale 1.03, pivot left-centre** | as Button | as Button | keyboard focus = hover look + focus_ring |
| `IconButton` | sprite → ibtn_hover, scale 1.05 | ibtn_pressed, icon -4 px | shake ±4 px | tooltip after 0.4 s |
| `Ability` | ability_hover, **lift 5 px** (Content), 0.18 s ease.lift | ability_pressed, lift 0 → sink 2 | shake ±6 px + tooltip reason | aiming keeps lift 5 |
| `HandPiece` | render lift **16 px**, scale 1.06, shadow scale 0.75 alpha 0.6 | — (click picks) | render shake ±7 px, 0.32 s | picked: lift **30 px**, scale 1.1, shadow 0.6 / 0.4, glow on |
| `EndTurn` | endturn_hover, scale 1.02 | endturn_pressed (face 8 px down), label -8 px | — | attention: endturn_attention + endturn_glow pulse |

### 2.6 ControlStyles (sprite + text colour per state; `UIStateVisual` applies them)

| Style | Normal | Hover | Pressed | Disabled | Selected / special | Label |
| --- | --- | --- | --- | --- | --- | --- |
| `Primary` | btn_primary_normal | btn_primary_hover | btn_primary_pressed | btn_primary_disabled | — | white; disabled cream.300 |
| `Secondary` | btn_secondary_normal | btn_secondary_hover | btn_secondary_pressed | btn_secondary_disabled | Selected = btn_primary_normal | cream.100; disabled cream.300 |
| `Danger` | btn_danger_normal | btn_danger_hover | btn_danger_pressed | btn_danger_disabled | — | cream.100 (4.8:1) |
| `Icon` | ibtn_normal | ibtn_hover | ibtn_pressed | ibtn_disabled | Selected (e.g. speed 2x) = ibtn_normal + icon gold | icon cream.100 / disabled cream.300 |
| `Ability` (overlay over the full face) | ability_overlay_ready | ability_overlay_hover | ability_overlay_pressed | ability_overlay_blocked | Aiming / Cooldown / Held = ability_overlay_aiming / _cooldown / _held | key cream.200, icon cream.100 (45 % on cooldown) |
| `EndTurn` | endturn_normal | endturn_hover | endturn_pressed | endturn_enemy | Attention = endturn_attention | white / enemy: cream.300 |
| `NamePlate` | nameplate_normal | nameplate_hover | — | nameplate_poor | Picked = nameplate_picked; Placed = nameplate_placed (+ _hover) | cream.100 / poor cream.300 / placed white |
| `Field` | field_paper_normal | field_paper_normal | — | — | Focus = field_paper_focus; Error = field_paper_error | ink, placeholder ink.2 |

Keyboard / controller focus everywhere: `focus_ring_r14` (or `focus_ring_pill`) tinted `accent`, a sibling after Background. Raycast off.

---

## 3. Shared prefabs (`Assets/Prefabs/UI/Elements/`)

All follow Rule 13: script on the root, everything under a `"Content"` child; Rule 11 parts named exactly as below.

- **`Button_Primary` / `Button_Secondary` / `Button_Danger`** (`UI_Button` + `UIFeedback` + `UIStateVisual`):
  `Root (UI_Button) → Content → Shadow (shadow_soft, outset 32, alpha 0.6, y -8) · Background (sliced) · FocusRing (off) · Icon (optional) · Label (TMP)`.
  Label: centred, Plinth, auto-size off. Horizontal padding 28, icon 26 with gap 12 (icon after the label for "Start ▶").
- **`Button_Icon`** 56×56: `Content → Background (ibtn_*) · Icon (24-28, cream.100) · Tag (optional TMP, e.g. "1x", Plinth 18, bottom-right)`.
- **`UI_Badge`** (plain `BaseUIElement`, parts `Background`, `Label`, optional `Icon`): variants Cost (`badge_cost` / `badge_cost_poor`,
  min 48×30, Plinth 20 gold / bad, horizontal padding 8), Key (`badge_key`, min 22×22, Plinth 18 ink, padding 4), Stack (`badge_stack` 32×24,
  hidden at 1), CooldownCorner (`cd_badge`, 38×38, Plinth 22 cream.100 or lock icon 20 gold).
- **`UI_TooltipBox`** (pooled): `Content → Background (tooltip_paper, outset 3/3/3/11) · Tail (tooltip_tail_down/up, positioned by TooltipPlacement at
  the anchor's x, clamped 28 px from the corners) · Header (IconTile 44×44 wood.700 r12 + rim, Title Plinth 28 ink, Tags Nunito Bold 20 ink.2) ·
  Body (Nunito Medium 22 ink, line 1.25) · Stats (row: icon 20 ink.2 + Plinth 24 gold.ink + Nunito 20 ink.2; dashed divider ink.2 35 %) ·
  Footer (left: hint Nunito Bold 20 ink.2; right: state)`. Padding 16 18 14 18, width 380.
- **`UI_StatusChip`** (inspector): `chip_status` / `chip_good` / `chip_bad`, height 36, padding 0 12 0 8, icon 20, name Nunito Bold 20 in status/good/bad,
  stacks Plinth 20.

---

## 4. Welcome screen (`WelcomeScene`, `UI_Welcome`, built by `Assets/Editor/UI/WelcomeBuilder.cs`)

Mockup: `art-direction/b-welcome.html`. Canvas Scaler 1920×1080, match 0.5 (already so in WelcomeBuilder).

```
Welcome (UI_Welcome : BaseUIPanel)                       stretch full screen
└ Content
  ├ Backdrop            Image level key art (blurred copy, 2440×1372 at -260,-150; or a blurred render) · raycast off
  ├ Scrim               Image scrim_welcome, stretch, raycast off
  ├ LogoSlot            top-centre, pivot (0.5,1), pos (0,-64), 440×132 (placeholder until the game has a name)
  └ Plaque              BaseUIElement, anchor centre, pivot (0.5,0.5), pos (0,-105), width 760, height by content
    ├ Background        window_frame (sliced, outset 3/3/3/12) + Shadow (shadow_soft)
    ├ MiniLeft / MiniRight   archer + guardian renders 250 / 236 wide, bottom -18, outside the plaque (-236 / -226), raycast off
    └ Column            VerticalLayout, padding 48 64 52 64, spacing 12, child align upper-centre
      ├ Eyebrow         "First time here"  Plinth 22 gold, letter spacing 12
      ├ Title           "Welcome, commander"  Plinth 56 cream.100, shadow 0 3 rim
      ├ Lead            Nunito Medium 22 cream.200, bottom margin 24
      ├ NameField       (BaseUIElement; parts "Input" = TMP_InputField) 632×72 + label above + help below
      │   Label "Your name" Nunito Bold 20 cream.200 · Field Background field_paper_* · Text Plinth 34 ink · Caret accent.fill 3 px
      │   Counter "4 / 16" Nunito 20 ink.2 right · Help "You can change it later in Settings." Nunito 20 cream.300
      ├ Start           Button_Primary wide 320×68, label "Start" Plinth 30 + icon play 26 after it
      └ SkipTutorial    text button, Nunito Bold 20 cream.200, underline 40 %, height 44, hover cream.100
```

- Element names stay as today (`NameField` with `Input`, `Start`, `SkipTutorial`), so `UI_Welcome.cs` needs no change except optional parts
  (`Counter`, `Help`: add as optional requirements if the script drives them).
- States: the field is focused on open (`input.ActivateInputField()` already): `field_paper_focus`. Empty or invalid name → keep `PlayerProfile.DefaultName`
  as placeholder; if the cleaned name is empty on Start, use the default (no error needed). If a rule is added later (bad words, length),
  show `field_paper_error` + help text in `bad` with the reason.
- Keys: Enter = Start (already `onSubmit`), Esc does nothing (`OnBackRequested` false). Tab moves focus Field → Start → Skip (focus ring).
- Motion: plaque fades + scales 0.96→1 in 0.25 s (`PanelTransition`), minis rise 12 px with 0.06 s stagger. Start pressed: face sinks, then scene fade.
- 1280×720: everything scales by 2/3 (match 0.5). Title stays ≥ 37 px, body ≥ 14.7 px on screen (= 22 at reference; rule is about reference px).

---

## 5. Main menu (`MainMenuScene`, `UI_MainMenu`)

Mockup: `art-direction/b-menu.html`.

```
MainMenu (UI_MainMenu : BaseUIPanel)                      stretch
└ Content
  ├ Backdrop            backdrop_wood (stretch) + level diorama render at (520,60) 1600×900 (UI_Background), raycast off
  ├ Scrim               scrim_menu, stretch, raycast off
  ├ Heroes              anchor bottom-right, pivot (1,0), pos (-120,40), 760×420: three renders (archer 220, guardian 250 front, mage 230)
  ├ MenuColumn          anchor top-left, pivot (0,1), pos (120,-96), width 560, VerticalLayout spacing 0
  │ ├ LogoSlot          560×220 (placeholder)
  │ ├ Greeting          TMP "Welcome back, <b>Eren</b>"  Nunito Medium 26 cream.200, name ExtraBold cream.100; margin 36 / 28
  │ └ List              VerticalLayout spacing 20, width 440
  │   ├ Continue        MenuButton primary 440×96: icon continue 36 · Title "Continue" Plinth 36 white · Sub "Spitters · round 3 of 8" Nunito Bold 20 #E6EFFF
  │   ├ Play            MenuButton secondary 440×64: icon play 28 · "Play" Plinth 28 cream.100 · Hint "Choose a level" Nunito Bold 18 cream.200 right (only on hover)
  │   ├ Codex · Settings · Credits     MenuButton secondary (icons codex, settings, credits)
  │   ├ Gap             height 4 (+20 spacing)
  │   └ Quit            MenuButton secondary (icon quit)
  ├ Miscellaneous       Button_Icon 56, anchor top-right, pos (-32,-32), icon misc, tooltip "Miscellaneous"
  └ Version             anchor bottom-left, pos (120,40), Nunito 20 cream.300 "Version 0.4 · build 2026-10-08"
```

- `MenuButton` = `UI_Button` with ControlStyle Secondary (Continue: Primary), Content → Background, Icon (left, 28), Label (left-aligned, padding 24,
  gap 16), optional Hint. Existing prefab `Assets/Prefabs/UI/MainMenu/MenuButton.prefab` gets restyled, not replaced.
- Element names unchanged (`Play`, `Settings`, `Credits`, `Miscellaneous`, `Quit`, `Greeting`, `Codex`, `Continue`). The Miscellaneous
  button moves out of the list to the top-right icon. When there is no run to continue, Continue is hidden and **Play becomes Primary** (one
  primary per screen).
- Keyboard: Up/Down move focus through the list (wraps), Enter presses, Esc on the main menu does nothing (Quit is explicit). The focused item looks
  like hover (sprite + scale 1.03 from the left) + focus ring. First focus = Continue (or Play).
- Motion: column items slide in from x -24 with alpha, 0.25 s, stagger 0.04 s; heroes rise 16 px, 0.4 s.

---

## 6. Battle HUD (`GameScene`, `UI_Level`, built by `Assets/Editor/Gameplay/GameHudBuilder.cs`)

Mockups: `art-direction/b-hud.html` (layout, look) + `prototype/` (cooldowns, previews, tray). Free board area for the camera (camera
"free rect"): screen minus top 96, bottom 168 (tray) + 140 while the action bar is up, right 372 while the inspector is open.

```
Level (UI_Level : BaseUIPanel)                               stretch
└ Content
  ├ Vignette            vignette sprite, stretch, raycast off
  ├ TopBar              (UI_LevelTopBar) stretch top, height 96
  │ ├ Resources         anchor top-left, pivot (0,1), pos (32,-20), HorizontalLayout spacing 12
  │ │ ├ HealthDisplay   (UI_ResourceDisplay) pill_wood h56, padding 8 20 8 8: Socket badge_circle_dark 40 + Icon heart 24 bad ·
  │ │ │                 ValueText Plinth 32 cream.100 "18" + Max Plinth 22 cream.300 "/ 20"
  │ │ └ EnergyDisplay   pill_wood: Socket badge_circle_gold 40 + Icon energy 24 ink · ValueText Plinth 32 gold · Delta (optional) Plinth 20 good/bad
  │ ├ Tracker           anchor top-centre, pivot (0.5,1), pos (0,-16), h64, HorizontalLayout padding 28 12, spacing 20, panel_wood
  │ │ ├ RoundText       Plinth 28 cream.100 "Round 2"
  │ │ ├ Sep             2×32 wood.500
  │ │ ├ WaveDisplay     icon wave 24 cream.300 · "Wave 1 / 3" Nunito Bold 20 cream.200 · Pips (pip_wave_on/off 26×10, gap 6)
  │ │ └ PhaseText       tag_phase_player / tag_phase_enemy h44, padding 18, Plinth 22 white ("Your turn" / "Enemy turn")
  │ └ Tools             anchor top-right, pivot (1,1), pos (-32,-20), spacing 8: SpeedButton (optional, see §8) · SkipButton · PauseButton (Button_Icon 56)
  ├ Inspector           (UI_InspectorCard, new) anchor top-right, pivot (1,1), pos (-32,-96), width 340
  ├ ActionBar           (UI_ActionBar, new) anchor bottom-centre, pivot (0.5,0), pos (0,196)
  ├ Tooltip             (UI_TooltipBox, pooled, top of the HUD sort order)
  ├ BottomBar           (UI_HandTray, new; replaces UI_LevelBottomBar's card list) anchor bottom-centre, pivot (0.5,0), pos (0,0), h168
  ├ EndTurnButton       anchor bottom-right, pivot (1,0), pos (-32,20), 168×168 (moves out of TopBar; TopBar keeps the reference by name)
  └ Hint                TMP (optional) bottom-centre above the tray, Nunito Bold 20 cream.100 on a pill_wood
```

`TowerRightBar` / `EnemyRightBar` are replaced by `Inspector` (one card, tower or enemy variant). `UI_Level` requirements change accordingly
(Rule 12, check `UI_LevelBar` subclasses first, Rule 7).

### 6.1 Top bar
- HP pill: at ≤ 30 % of max the number turns `bad` and the heart pulses once per hit (scale 1.15, 0.25 s). Hover tooltip "Base health: if it reaches 0, the level is lost".
- Energy pill: gaining/losing shows Delta "+20" / "-100" for 1.2 s (good / bad), number counts over 0.3 s. Tooltip lists income.
- Tracker: one pip per wave: `pip_wave_on` tinted `good` green once the wave is cleared (all its enemies spawned and dead), `pip_wave_on` while it runs (the first lit from the start), `pip_wave_off` before it starts (user, 2026-10-11); phase tag swaps sprite at phase change with a 0.18 s cross-fade; the banner sweep is separate (BannerLayer).
- Tools (tooltips below, preferred side Bottom): Skip = icon skip, enabled only while an animation can be skipped (Space). Pause = icon pause (P / Esc).
  Speed (if added) cycles 1x → 2x, Tag shows "1x"/"2x", Selected state at 2x.

### 6.2 Inspector card (`UI_InspectorCard`)
`Content → Background panel_wood (tower) / panel_wood_enemy (enemy), outset 3/3/3/12 · Column (VerticalLayout padding 20, spacing 18)`:
- Head row: Portrait 96 (portrait_ring / _enemy; child mask_circle + unit render) · Name Plinth 32 accent.light (enemy #FF9C90) + Sub Nunito 20 cream.300
  "Tower · level 1" · Info Button_Icon 40 top-right (icon info, cream.300).
- HP: row "Health" Nunito Bold 20 cream.200 + "20 / 20" Plinth 22 cream.100; bar 300×14 (`hpbar_frame` + `hpbar_ghost` + `hpbar_fill`, tinted by hp tokens) + shield segment if any.
- Stats: 2×2 grid of `paper_stat` 48 high, gap 8: icon 20 ink.2 · value Plinth 26 ink · label Nunito Bold 20 ink.2 (Power, Range, Speed, Armour).
- Abilities (new, tower and **enemy**): row of the ability button prefab at **scale 0.667 (56 px)** with clock ring + corner badge, non-interactive
  for enemies (hover → tooltip only). Enemy cooldowns use exactly the same ring/badge rules as towers.
- Statuses: `UI_IconBar` of `UI_StatusChip`, wrap, gap 8.
- Footer (towers): Sell Button_Danger 48 high, icon sell gold 22 + "Sell" + "+50" gold. Enemy: no footer; the "next action" line instead
  ("Next: moves 2" / "Next: Smash 8") with the intent chip.
- Open: slide in from x +380, alpha 0→1, 0.25 s ease.out; close 0.15 s. Right click / Esc deselects (closes it).

### 6.3 Action bar (`UI_ActionBar`) and ability button
- Shown while a tower is selected: slides up 24 px + fade, 0.2 s. `Content → Background panel_wood (outset 3/3/3/12) · Row (padding 14 16, spacing 26)`:
  Who (Name Plinth 24 accent.light, "2 ready" Nunito Bold 18 cream.300; width ≥ 110) · Divider 2×56 wood.500 · AbilityButton × n.
  Spacing 26 leaves room for the clock rings (7 px each side).
- **AbilityButton** (`UI_Button` variant or `UI_AbilityButton`) 84×84, **FULL-FACE (2026-10-09)**: the ability's own icon face fills the button.
  `Content → ClockRing (clock_ring_* or Fill+Gaps, outset 17) · Face (Image abilities_face/<Name>.png, 168 px = 84 at 2×, chip colour edge to edge, glyph 52)
   · Overlay (ability_overlay_<state>, outset 17, raycast off) · Key (TMP Plinth 18 cream.100 with 2 px rim shadow, top-left 8,4) · Cost (UI_Badge Cost 40×26,
   bottom-right, -6 outside; hidden at 0) · CdBadge (UI_Badge CooldownCorner 38, centred on the top-right corner, 12 px out) · FocusRing`.
  Overlay per state (colour only, nothing moves): ready = thin rim + top highlight; hover = 10 % lighter + accent.light ring; pressed = 18 % darker;
  aiming = gold ring + glow; cooldown = 55 % dark veil; held = dark veil + gold-dark inner line (+ lock in CdBadge); blocked = veil + bad inner line.
  The older wood-face frames (`ability_ready…blocked`) stay in the kit for reference only.
- **Cooldown display** (the core resource): one ring segment per cooldown turn (1-3; for longer cooldowns use the 3-segment ring with
  fill = recovered / total).
  - Ready: `clock_ring_N_ready` (full cobalt ring + glow), no badge, icon 100 %.
  - Cooling: `clock_ring_N_k` (k recovered segments in accent.light, the rest dark), **CdBadge** = turns left, icon alpha 0.45 + 40 % saturation,
    Overlay ability_overlay_cooldown. The ring and badge are the only cooldown signals; no big centred number, no radial over the face.
  - Ready next turn (1 left): CdBadge pulses `pulse.soon` (cd_badge ↔ cd_badge_soon).
  - Held (`Entity.CooldownHeld`, waits for a reset such as a kill): ring all dark, CdBadge shows **lock** (gold), Overlay ability_overlay_held,
    tooltip footer "Ready after a kill" (text from the ability's reset source; generic "Waits for a reset").
  - Blocked (ready but can't be cast: no target, energy, rooted): ability_overlay_blocked, icon 40 %, the click shakes and the tooltip shows the reason in bad.ink.
    Energy short = Cost badge `badge_cost_poor` (bad), not grey.
  - Alternative implementation (fewer sprites): `clock_ring_fill` Filled Radial 360 (origin Top, clockwise) tinted accent.light with
    fill = recovered/total, + `clock_ring_gaps_2/3` on top; ready = fill 1 tinted `#5591E0` + glow_r14 behind.
- Interaction (logic stays in `FillAbility`, `UI_LevelTowerRightBar.cs:201-239`): hover → range preview + tooltip **above the bar** (TooltipPlacement
  preferred Top, avoid rect = the board preview's screen bounds); click or key **N** → Aiming (gold); Shift+N quick cast; right click / Esc cancels aiming.
- Tooltip footer (cooldown in words + state): left "Every turn" (cooldown 1) / "Every 2nd turn" (2) / "Every 3rd turn" (3) / "Every N turns" (>3) /
  "Once, then after a kill" (`cooldownUntilReset`), with icon clock 20 ink.2; right state: "Ready" good.ink · "Ready next turn" ink · "Ready in 2 turns" bad.ink
  · "Ready after a kill" bad.ink · blocked reason bad.ink. Turkish: "Her tur" / "2 turda bir" / "3 turda bir", "Hazır", "Gelecek tur hazır", "2 tur sonra hazır".

### 6.4 Hand tray (`UI_HandTray`) and pieces (`UI_HandPiece`)
- Tray: `Content → Background hand_tray (outset 3/3/3/0; band on the top edge) · Row (HorizontalLayout padding 22 22 0 14 → placed pieces need 8, spacing 6, align bottom)`.
  Width = pieces × 124 + gaps + 44. Straight row, no fan. Ctrl+N picks piece N (key label from InputBindings).
- Piece slot 124×150 (`UI_HandPiece : BaseUIElement`, parts: `Shadow`, `Glow`, `Render`, `Plinth`, `Medallion`(+`Portrait` under a Mask), `NamePlate`(+`Name`, `OnBoardIcon`),
  `Cost` (UI_Badge), `Key` (TMP), `Hp` (frame+fill+label), `Pips` (row)). Pivot bottom-centre. The render animates, never the slot (layout stays still).
- States (`UIState` flags → priority Placed > Picked > CantAfford > InHand):

| State | Render | Plinth / shadow | Name plate | Top row | Under the name |
| --- | --- | --- | --- | --- | --- |
| **InHand** | miniature (its own plinth), 112 tall, bottom 34 | piece_shadow 104×30 at bottom 30 | nameplate_normal, Nunito ExtraBold 18 cream.100 | Cost coin top-left (badge_cost, gold), Key top-right Plinth 18 cream.200 | — |
| InHand + hover | lift 16, scale 1.06, 0.18 s ease.lift | shadow scale 0.75, alpha 0.6 | nameplate_hover | same | tooltip above the tray: tower card (stats, abilities with cooldown words, cost) |
| **Picked** | lift 30, scale 1.1; piece_glow gold alpha 0.7 behind | shadow 0.6 / 0.4 | nameplate_picked | same | stays raised until placed or cancelled (right click / Esc) |
| **CantAfford** | alpha 0.4, grey (tint #9A9A9A) | normal | nameplate_poor, name cream.300 | badge_cost_poor, number bad | click: shake ±7 px + tooltip "Needs 180 energy (you have 150)" |
| **Placed** | **Colour portrait medallion** 64 standing on the empty plinth (top 26 in the slot): `Medallion` (medallion_ring 80, outset 8) → `Mask` (Image mask_circle 64 + Mask, Show Mask Graphic off) → `Portrait` (Image, the unit's portrait render, head-and-shoulders: today `~/blender/out/ui/<Name>.png` 400 px scaled to 196 and offset so the head centres; dedicated bust renders can come later from the Blender agent). No silhouette (rejected: towers looked alike). | **piece_plinth_empty** 108×52 at bottom 30 (top centre ≈ 100 px from slot top) | **nameplate_placed** (cobalt), name white, `onboard` icon 16 white left | no cost coin; **mini pips** top-left (pip_mini_ready / wait / held 18, gap 4; one per ability) | **HP bar** 100×8 (hpbar_plate_frame + fill, hp colours), "14 / 20" Plinth 18 shown on hover only; slot height 160 |
| Placed + hover | medallion scale 1.06, 0.18 s | — | nameplate_placed_hover | — | its tower's ring on the board lights (ready_glow + selection outline) |

  - Placed piece click = select the tower (camera glides to it, 0.5 s ease.inOut). Placed pieces are not picked by Ctrl+N; Ctrl+N selects their tower instead.
  - Tower dies or is sold: the miniature returns to the plinth (render drops from -40 px with alpha, 0.3 s ease.lift; nameplate cross-fades to wood).
  - Placing: on success the render rises -160 px + scale 0.6 + fade (0.3 s, "pieceleave"), then the slot switches to Placed.

### 6.5 End turn (`EndTurnButton`, `UI_Button` style EndTurn)
`Content → Glow (endturn_glow, 240×240 centred, off) · Background (endturn_*, 240×240, outset 36) · Label "End\nturn" Plinth 30 white, line 0.95, shadow ·
Key (UI_Badge Key, "Enter" from InputBindings.Describe(GameKeys.EndRound), 8 px under the label)`.
- States: Normal (player phase, things left to do) · Hover · Pressed · **EnemyTurn** (endturn_enemy, label "Enemy\nturn" cream.300, not interactable, no key)
  · **Attention** = endturn_attention + endturn_glow pulse (`pulse.attention`): only when **no placed tower has a ready, usable ability and no
  hand piece is affordable**. Never on the first frame of the phase (wait 0.6 s so the "Ready!" pops play first).
- Hover (player phase): **preview next turn**: board pips that will be ready next turn show `pip_ability_ghost`; tooltip (preferred Left) lists
  "Usable now: Archer · Shoot" (good.ink), "Ready next turn: Guardian · Bash" (accent.ink), and the threat summary "Base -4 · Archer -6" (bad.ink, from enemy intents).
  If abilities are usable now, the tooltip title is "End turn anyway?" (no modal).

### 6.6 Board layer (BattleOverlay split: PlateLayer, FloaterLayer, BannerLayer + a PreviewLayer)
Screen-space overlay canvas (match 0.5, unscaled time) following units, except the decals and the attack arc which are world-space.

- **Per unit, stacked bottom-up above the unit's head:** HP plate (hpbar_plate_frame 64×10 + ghost + fill; **hover rule**: visible on hover, selection,
  for 2 s after a hit, while dying, or when the setting says always) → **status chips (always visible)**: chip_unit_status / _debuff / _buff 30 high,
  icon 18 + stacks Plinth 18 cream.100, gap 4, centred → enemy **intent chip** (enemies, player phase, always visible).
- **Under each tower (at its feet), always visible:** one **pip per ability**, 28 px, gap 5: pip_ability_ready (cobalt + glow) / pip_ability_wait
  (turns left Plinth 18 cream.100) / pip_ability_held (lock 16 gold). **ready_glow** under a tower that has ≥ 1 ready usable ability: world quad on the
  tile (or screen-space ellipse 130×120 squashed), tint accent alpha 0.45, breathe 1.6 s.
- **Turn start (player phase begins):** after the "Your turn" banner (0.2 in / 0.8 hold / 0.2 out), cooldowns tick: every pip whose number drops
  updates; an ability reaching 0 flashes (pip scale 1→1.45→1 with glow, 0.6 s ease.lift), its clock ring segment lights (0.25 s), and a
  **"Ready!" pop** (badge_ready_pop + Plinth 22 ink) rises 24 px over the tower and fades (0.9 s). Stagger 0.06 s per tower, left to right.
  ready_glow fades in after the pop.
- **Enemy intents** (one rule set drives the preview and the enemy turn): intent_move (icon back 22 + tiles "2"), intent_attack (icon power + damage),
  intent_attack + castle icon when it hits the base (+ intent_glow tinted fx.damage, `pulse.threat`), intent_wait (clock); a long-cooldown ability
  adds `cooldown_ring` 28 (Radial 360, fill = waited/total) + turns. Plinth 20 cream.100.
- **Hover an enemy:** path tiles = **decal_enemy_path** (dashed), stop tile = **decal_enemy_stop** (solid + glow); attack = dashed arc
  (LineRenderer with `line_attack_dash`, Texture Mode Tile, width 6-8 px equivalent, offset scroll -1 period / 0.6 s; end dot `line_attack_end`)
  to the target; the target's plate shows the loss as **stripes_damage_preview** over the lost part (RawImage, uvRect width = rect.width / 12, `blink.preview`).
- **Aiming an ability:** valid targets pulse **decal_target_valid** (heals: decal_heal_valid); hovering one shows the hit on its HP bar as stripes
  (heal: stripes_heal_preview) and **tag_kills** ("Kills" / "Öldürür", white Plinth 18) 30 px above the plate when lethal. Tooltips never cover the preview (avoid rect).
- **Enemy acting:** **ribbon_enemy** with the ability name ("Smash!", white Plinth 30, shadow 0 2 #000) over the enemy, pop 1.1 s
  (0 → scale 1.08 at 15 % → 1 → rise and fade at 80-100 %).
- Floaters (FloaterLayer): Plinth 44-56, 8 px rim outline, damage fx.damage, heal fx.heal, status fx.status, "Ready!" via badge (not a floater).
- Colour rule: player things = cobalt / gold, enemy things = red, never mixed. Pattern rule: dashed = path, solid = stop, stripes = predicted loss.

### 6.8 Attack preview by delivery (Melee / Projectile / Lobbed / Spell / Beam)
The preview shows how the attack travels, in enemy red or player cobalt (gold end points), never mixed. **All preview data comes from the game's own
dry run of the action** (the rules resolve final target, first blocker, redirects like Bodyguard / Taunt, every unit hit), never from UI-side geometry.

| Delivery | Draws | Renderer | Kit sprites |
| --- | --- | --- | --- |
| Melee | short solid chevron on the attacker → target edge | world quad (decal), rotated | `atk_melee_chevron_{enemy,player}` |
| Projectile | straight dashed LOW line (~0.3 m), stops at the first blocker | LineRenderer, 2 points, Texture Mode Tile, scroll 1 period / 0.6 s | `atk_line_dash_*` (+ `line_attack_end`) |
| Projectile blocked | ✕ on the blocker; blocker gets the damage stripes; aimed target greyed (plate alpha 0.4, no stripes) + chip "Blocked by Wall" | screen-space marker + chip | `atk_blocked_x`, `paper_stat` |
| Lobbed | dotted HIGH arc, ignores blockers; impact ring on the landing tile; splash decal on each area tile | LineRenderer with N = 16-24 points on a parabola (apex 0.35 × distance), Tile mode; decals | `atk_lob_dots_*`, `atk_impact_ring_*`, `atk_splash_*` |
| Spell | no line; rune under the target + faint link | decal (rune, slow spin 8 s) + LineRenderer 2 points alpha 0.45 | `atk_rune_*`, `atk_spell_link_*` |
| Beam | solid line; every unit on it gets its own preview | LineRenderer 2 points, Stretch mode | `atk_beam_*` |
| Redirected | the line bends at the original target to the new one + marker; tooltip names the cause | marker screen-space, line gets 3 points | `atk_redirect` |

Intent chip icon per delivery (screen-space, on `intent_attack`): `icon_del-melee` (sword), `icon_del-arrow`, `icon_del-arc`, `icon_del-spark`, `icon_del-beam`; the base-hit variant keeps the castle icon.

### 6.7 Dialogue box (tutorial / sequences; `UI_SequenceBubble` / `UI_TextBubble`)
`dialogue_box` ~1100×220 bottom-centre (pos 0, 24), padding 28 36; name plate = `pill_wood` h44 overlapping the top-left edge by 22 px, speaker name
Plinth 24 teal; body Nunito Medium 24 cream.100, letter reveal 40 chars/s; "next" icon 24 cream.200 bottom-right bobbing 4 px (only element that idles);
Skip = text button top-right "Skip (Space)". Bust portrait ~560 tall at the side. Targets are pointed at with a spotlight + bouncing arrow, not a tail.

---

## 7. Keyboard and mouse summary

| Input | Welcome | Main menu | HUD |
| --- | --- | --- | --- |
| Enter | Start | press focused | **End round** (also Shift+Space) |
| Space | (types) | — | Skip / continue animation or dialogue |
| Esc | — | — (closes sub-windows) | cancel aiming / placing → deselect → Pause |
| P | — | — | Pause |
| 1-9 | — | — | aim ability N of the selected tower; Shift+N quick cast; Ctrl+N hand piece N |
| Right click | — | close window | cancel aiming / placing, deselect (never presses) |
| Tab / arrows | focus field → Start → Skip | Up/Down through the list | — |

---

## 8. Rule notes, deviations and open points

- **Radius.** UI-RULES says radius 4/8/12; style B (decided) uses 14 for controls, 16 for ability buttons and 22 for windows. The kit follows B.
  Proposal: update the rule to `radius.chip 10-12 · control 14 · window 22`.
- **`type.plaqueTitle 56`**: the approved Welcome mockup uses 56, between h1 44 and display 64. Either add the size or use 64 (fits 632 px for
  "Welcome, commander" in Plinth; check Turkish "Hoş geldin, komutan").
- **Hand slot height** grows to 160 for placed pieces (HP bar under the plate): the tray keeps 168 with bottom padding 8 instead of 14.
- **Speed button**: game speed exists only as a Settings slider (`UI_Settings` GameSpeedSlider). The B mockup's HUD speed button is optional and
  must drive the same setting (Eren's call).
- **Ability keys**: 1-9 today; the mockups showing Q/W/E/R are out of date until Eren decides.
- **Icons**: 64 px masters with mip maps (an exception to "UI mipmaps off"), because they're drawn 3x smaller at 1280×720.
- **PPU**: the import script defaults to PPU 200 (the game's current setting, multiplier 1). Option B is PPU 100 + Image multiplier 2. Pick one project-wide.
- **Disabled label** contrast (cream.300 on the disabled face) is about 3.5:1. Disabled controls are exempt, and the tooltip still explains why.
- Contrast checked (WCAG): cream.100 on wood 12.2, cream.300 on wood 6.4, ink on paper 12.1, ink.2 on paper.2 5.7, gold.ink 5.6, good.ink 4.6,
  bad.ink 5.4, white on accent.fill 5.4, cream on danger 4.8, ink on gold 11.1, cream on intent red 7.0.

---

## 9. Status and ability icons (two-tone rule)

**Rule (user, 2026-10-08):** every status and ability icon = a coloured **chip** + a **two-tone glyph** (cream `#F5EAD6` fill + rim `#120C09` outline,
about 3 px at 64 px, baked). Meaning is carried by the chip: colour family **and shape**. At most 3 colours per icon. Unity never tints these
(only darkens for disabled, e.g. colour #808080). Plain white glyphs (`*_white.png`) are kept for the rare case a tint is needed.

- **Files** (kit-b.zip → `statuses/`, `abilities/`): `<Name>.png` = chip + glyph baked, 48 px chip at 2× (108 px), the asset icon. `parts/`:
  `chip_<Name>.png` (34 px chip at 2×), `glyph_<Name>.png` (64, two-tone), `glyph_<Name>_white.png`, `status_stack_badge`, `status_time_badge`, `ring_*` (duration rings), ability `chip_<role>.png`.
- **Unity paths** (Eren assigns them; the game repo is read-only for me): `Assets/Art/Icons/Statuses/<Name>.png` → `StatusAsset.icon`,
  `Assets/Art/Icons/Abilities/<Name>.png` → `AbilityAsset.icon` (file names without spaces: `AcidFlask.png`, `ChainLightning.png`…). `KitBImport.cs` covers
  both folders: Sprite, uncompressed, **mip maps on** (shown at 24-48 px from 108 px sources).
- **Status chip in UI** (`UI_StatusIcon`, board plates, inspector, tooltips): either the baked `<Name>.png` in one Image (simplest, today's `icon` field),
  or Image `chip_<Name>` + child Image `glyph_<Name>` (70 % of the chip) + `UI_Badge` Stack. Sizes: **34** board and inspector, **24** tooltips and inline text, **48** Codex.
- **Instances:** each status instance has Stacks + TurnsLeft (re-applying adds stacks and restarts the timer; Independent / PerSource stacking gives
  several instances = several chips side by side, each with its own badge and ring).
- **Stacks:** `status_stack_badge` 20×20 at the chip's bottom-right (overlapping 10 px), Plinth 18 cream.100; hidden at 1 (Shield always shows it: it is the
  absorb amount).
- **Duration (1-3 left): segmented ring** around the chip, like the cooldown clock: `ring_<shape>_<unit>_<n>_<lit>.png` (52 px canvas at 2×, centred on
  the 34 chip; shape = round / square / hex to match the chip). n = min(status duration, 3) segments, lit (cream) = left, they empty clockwise from the top as
  time runs out. unit `turns` = smooth segments with round caps; `rounds` = segments cut into square ticks (durationUnit Rounds).
  **4+ left:** `status_time_badge` (36×22 pill) at the chip's top-right with `icon_cooldown` (hourglass) 14 + number Plinth 18 cream.100, no ring.
  **Permanent:** no ring, no badge. Tooltips show exact text ("2 turns left", "Permanent").
- **Shape split:** round = Buff tag, rounded square = Debuff tag, hexagon = no Buff/Debuff tag (object / state: Burning, Enraged, Unknown).
- **Ability chip colour by role:** tagged Spell → purple (also when it deals damage); physical attack (Melee, Projectile, Lobbed, untagged) → red;
  heal / buff → green; taunt / provoke → gold; Movement → wood. No delivery mark on the icon (the board preview shows delivery).

### Status icons
| Status | Glyph | Chip colour | Shape | Chip shows |
| --- | --- | --- | --- | --- |
| Acid | drop with bubbles eaten into it | acid green | rounded square | stacks (damage per tick), turns left |
| Burn | single flame | fire orange-red | rounded square | stacks (fire damage per tick), turns left |
| Burning | campfire: three small flames on crossed logs (an object / tile on fire) | ember orange | hexagon | rounds left (no stacks shown unless > 1) |
| Enraged | anger vein mark (four bent strokes) | rage red | hexagon | nothing (permanent); Power +10 in the tooltip |
| Poison | skull (purple chip, green inner line) | purple + green inner line | rounded square | stacks, turns left |
| Rooted | boot held by roots growing into the ground | control slate | rounded square | turns left |
| Gorged | overflowing bowl (it ate a lot) | green | round | stacks (max HP +20 each); permanent |
| Haste | double chevron with speed lines | teal | round | stacks (Speed +1 each, max 2) |
| Rallied | two rank chevrons pointing up | gold | round | turns left (Power +2, Speed +1 in the tooltip) |
| Shield | heraldic shield, half lit | light blue | round | stacks = points it still absorbs (always shown, also at 1) |
| Taunted | magnet (pulled toward the taunter) | control slate + red inner line | rounded square | turns left; the taunter in the tooltip |
| Unknown | question mark (fallback while a status has no icon) | wood | hexagon | stacks if any |
### Ability icons
| Ability | Glyph | Chip colour (role) |
| --- | --- | --- |
| Acid Flask | round-bottom flask, liquid level, bubbles | purple (spell) |
| Bash | spiked mace | red (attack) |
| Bite | jaws with teeth meeting | red (attack) |
| Blink | dashed ghost circle -> solid circle (teleport) | wood brown (move) |
| Bolt | heavy ballista bolt, horizontal, fins | red (attack) |
| Bombard | round bomb with lit fuse | red (attack) |
| Brute Walk | big monster footprint (heel + three toes) with impact marks | wood brown (move) |
| Crush | press: two plates, arrows squeezing in | red (attack) |
| Chain Lightning | forked lightning jumping between two nodes | purple (spell) |
| Execute | executioner axe | red (attack) |
| Fire Wall | brick wall with flames on top | purple (spell) |
| Fireball | ball of fire with streaking tail | purple (spell) |
| Pinning Shot | arrow driven into the ground | red (attack) |
| Provoke | four arrows pulling in to a point | gold (control) |
| Raise Skeleton | gravestone with an up arrow | purple (spell) |
| Shield Bash | shield rushing forward (speed lines) | red (attack) |
| Volley | three arrows rising | red (attack) |
| Walk | one boot in profile with motion lines | wood brown (move) |
| Firebolt | flame flying diagonally (tilted flame + speed lines) | purple (spell) |
| Taunt | shout burst with an exclamation mark | gold (control) |
| Hop | jump arc landing on a mark | wood brown (move) |
| Mend | heart with a plus | green (support) |
| Nibble | round bite taken out of a disc + crumbs | red (attack) |
| Path Walk | dotted winding path ending in an arrow | wood brown (move) |
| Quicken | stopwatch with speed lines | green (support) |
| Rally | war drum, sticks raised | green (support) |
| Ram | curled ram horn | red (attack) |
| Shoot | fletched arrow, diagonal | red (attack) |
| Slam | big down arrow hitting cracked ground | red (attack) |
| Slime Mend | slime dome with a plus | green (support) |
| Smash | sledgehammer | red (attack) |
| Smite | ray from above with an impact burst | purple (spell) |
| Spark | four-point spark with two motes | purple (spell) |
| Spit | flying glob with a trail | red (attack) |
| Tower Walk | small tower with an arrow (the tower steps) | wood brown (move) |


### Passive icons
Round chip with a **double rim** (an "always on" ring) so a passive never looks like a clickable ability (abilities are square). Colour by role:
attack red, support green, defence light blue, special / boss gold, hazard ember. Files: `passives/<File>.png` → `Assets/Art/Icons/Passives/<File>.png`
(`PassiveAsset.icon`; Eren assigns). 64 / 128 px copies in `png/icons_64|128/passives/`.

| Passive | File | Glyph | Chip |
| --- | --- | --- | --- |
| Counter-attack | CounterAttack | U-turn arrow striking back + spark | red (attack) |
| War Beat | WarBeat | music note sending out aura arcs | green (support) |
| Bloodthirst | Bloodthirst | blood drop inside a reset arrow | red (attack) |
| Glutton | Glutton | wide-open round mouth eating a row of dots | gold (special) |
| Rock Eater | RockEater | faceted rock with a bite + crumbs | light blue (defence) |
| Shielded | Shielded | shield outline with a refill arrow | light blue (defence) |
| Burning ground | FireTile | flame on a diamond tile | ember (hazard) |

## 10. Screen parts (menus, settings, Codex, level select, dialogue, boot)
Sprites in `png/screens/`, look from `mockups/screens-b/kit-b.css`; `manifest_ui.json` maps each to its CSS class and role.
Tabs (`tab_normal/hover/selected`), list rows (`row_normal/hover/selected/locked`), slider (`slider_track`, `slider_fill`, `slider_knob_normal/hover/pressed`,
`value_box`), toggle (`toggle_on/off` or `toggle_track_*` + `toggle_knob`; the On/Off word is TMP beside it), dropdown (`dropdown_normal/hover/open`,
`dropdown_list`, `dropdown_item_hover`, `dropdown_arrow`), scrollbars (`scrollbar_track`, `scrollbar_handle_normal/hover`, paper variants), key slots
(`keyslot_normal/hover/listening/conflict/empty`), close button (`close_normal/hover/pressed`, x baked) and flat icon button (`ibtn_flat_*`), keycaps
(`kbd_paper`, `kbd_wood`), screens' wood button (`btn_wood_*` = `.k-btn`, dark band), `dialogue_nameplate` (cobalt), `speaker_frame`, boot bar
(`loadbar_track`, `loadbar_fill`, `loadbar_glow`), `codex_stage`, `codex_plinth`, `chapter_header`, `level_number(_locked)`, `new_dot`, `lock_badge`,
`medal_ring(_enemy)`, `well`. Unity mapping: Slider = Background `slider_track`, Fill `slider_fill`, Handle `slider_knob_*` (SpriteSwap or UIStateVisual);
Scrollbar = `scrollbar_track` + Handle `scrollbar_handle_*`; TMP_Dropdown = `dropdown_*` + Template `dropdown_list` + Item highlight `dropdown_item_hover`.


**Deprecated (2026-10-09):** `piece_selected_arrow` (selection is colour only: `nameplate_selected` + `medallion_ring_selected`; kept in the kit, flagged in manifest_ui.json).
