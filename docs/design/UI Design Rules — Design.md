# Tower Defence — UI Design Rules

Oct 8, 2026 · @Eren

## Purpose

These are the rules every screen of the game follows: colours, type, spacing, components, states and motion. It is a proposal for Eren. Nothing here is in the game until he says so.

- **Who reads it:** Eren, the game's agent (when it builds UI), and the `uiux` agent (when it reviews screens or makes mockups).
- **Scope:** the Godot game only (`~/godot/projects/td`: `game/ui/theme`, `game/ui/elements`, `game/ui/hud`, `game/ui/screens`, and the board overlay in `game/board/overlay`). Web build: http://92.5.94.11/art/godot/td/. The wiki has its own look.
- **Based on:** the game's code when this was written (`96c7637`), `Decisions.md`, the design docs and the Painted Miniatures art style. This doc picks one value per role and gives it a name (a **token**); the tokens live in `data/content/UITheme.json` (section 11).
- **How to use it:** new UI uses the tokens. Old UI moves to them when someone touches it anyway. Section 12 lists where the screens differed before the port.

## Principles

1. **The board comes first.** The HUD frames the board and never covers it without a reason. Panels sit on the edges (top 60, bottom 120, right 300); anything in the middle is short-lived (banners, bubbles, popups).
2. **One main action per screen.** Each screen has one obvious next step (Start, End turn, Play level), drawn as the primary button. Everything else is quieter.
3. **Colour means something.** A colour is used for its role only: gold = energy, cost and values; red = harm and enemies; green = healing and "yes"; cobalt = the player and selection. Decoration never borrows these colours.
4. **Readable at 1280×720.** The reference is 1920×1080, but every text must still read at 1280×720 (the smallest supported size). That sets the minimum font sizes in section 3.
5. **Every control answers.** Hover, press, disabled and selected look different on every clickable thing, and every action shows feedback within 0.1 s.
6. **Mouse first, keys as shortcuts.** Left click acts, right click cancels everywhere (Decisions.md). Every key has a visible mouse way to do the same.

## Colour palette

The UI is a cool, dark navy frame around a warm, colourful board. The old code had about 70 colours, many of them near-duplicates (for example `#ffd36a`, `#FFD46B` and `#ffcc4d` for gold). This palette keeps the look and gives each role one value. Contrast numbers are measured on the panel colour `#171A24`.

**Style decided 2026-10-08: direction B "Painted Diorama"** ([mockups](http://92.5.94.11/art/ui/art-direction/)). Surfaces are made of the same stuff as the miniatures' bases: painted dark wood with a thin dark outline, corners 14. Things read up close (cards, tooltips, stats, text fields) are cream paper with dark ink. The role colours below stay the same; on paper they switch to their dark ink versions. The navy `ink.*` ramp below is replaced by the wood ramp for surfaces.

**Two refinements after seeing the kit in the game (user, 2026-10-09):**

- **Blue means active.** No cobalt band under panels, windows, pills, cards, tabs, rows, wood buttons, the tray or the HUD parts: a cobalt edge on everything stopped meaning anything. Cobalt is kept for the one primary button per screen, for selected / hover / focus states, for End turn, for the towers' medallion rings and for the 3D plinths.
- **Depth only in menus.** The thick extruded side and the press-sink are kept only on the main menu and the Welcome screen. Everything else is **flat**: the face, a thin dark rim and a soft top highlight; hover makes it lighter, pressed slightly darker, and nothing moves. This covers the whole HUD (End turn is a flat round cobalt button), the windows (Pause, Settings, Codex, Level select, hand editor), the dialogue box, tabs, rows and sliders. The kit names the deep versions `menu_btn_*` / `menu_panel_*`; everything else is flat by default.

| Token | Hex | Used for | Contrast |
| --- | --- | --- | --- |
| `wood.900` | `#17110D` | Full-screen backdrop | — |
| `wood.850` | `#211913` | Darkest panels | — |
| `wood.800` | `#2A211B` | Panels, bars, buttons (bottom of the gradient `#43342A` → `#2A211B`) | base for the text numbers |
| `wood.700` | `#3A2D24` | Rows, raised parts | — |
| `wood.600` / `wood.500` | `#4A3A2E` / `#5E4A3A` | Hover, dividers | — |
| `rim` | `#120C09` | Outline and the rim under the band | — |
| `band` / `band.dark` | `#3F78C9` / `#2B5594` | Selected / active edge only (no longer a band under every panel, 2026-10-09) | — |
| `cream.1` | `#F5EAD6` | Text on wood (primary) | 13.2 on `wood.800` |
| `cream.2` | `#DCCAAE` | Secondary text on wood | 9.8 |
| `cream.3` | `#BDA98C` | Muted text on wood | 6.9 |
| `paper` / `paper.2` / `paper.edge` | `#EEE2C6` / `#E2D2B0` / `#B89F78` | Cards, tooltip, stats, text fields | — |
| `ink` / `ink.2` | `#2E2117` / `#5F4936` | Text on paper | 12.1 / 6.6 on `paper` |
| `gold.ink`, `bad.ink`, `good.ink`, `status.ink` | `#7A4E00`, `#A3301F`, `#2D7238`, `#6B3FB0` | Role colours on paper | 5.6, 5.4, 4.6, 5.5 |
| `accent.light` (B) | `#8DBBFF` | Accent text on wood, tower names | 8.0 |

### Surfaces (dark ramp)

| Token | Hex | Used for | Replaces |
| --- | --- | --- | --- |
| `ink.950` | `#0D0F14` | Tooltip background (95% opacity) | `#0D0D14`, `#0D0F14` |
| `ink.900` | `#0F1217` | Full-screen backdrop | same |
| `ink.850` | `#171A24` | Panels, bars, bubbles (92% opacity over the board) | same |
| `ink.800` | `#1C1F29` | Popup windows (opaque) | same, `#1C1F26` |
| `ink.700` | `#262B3A` | Cards, input fields, list rows | `#262633`, `#292E3D`, `#2E333D` |
| `ink.600` | `#333847` | Button (normal) | `#333340`, `#333333` |
| `ink.500` | `#4D5266` | Button (hover), dividers | `#4D4D61` |
| `ink.400` | `#666B80` | Outlines | `#666680` |
| `scrim` | `#000000` at 60% | Behind modal popups | same |

### Text

| Token | Hex | Contrast | Used for |
| --- | --- | --- | --- |
| `text.primary` | `#F2F4F8` | 15.8 | Titles, body, button labels |
| `text.secondary` | `#BFCCE6` | 10.7 | Descriptions, hints, labels |
| `text.muted` | `#9AA3B5` | 6.8 | Subtitles ("Tower · cost"), notes, "turns left" |
| `text.disabled` | `#7A8296` | 4.5 | Disabled labels, placeholders |
| `text.onLight` | `#12141A` | — | Only on light fills (the rare white button) |

### Accent and roles

| Token | Hex | Contrast | Meaning |
| --- | --- | --- | --- |
| `accent` | `#4D8FE6` | 5.3 | Cobalt, as on the miniatures' plinth band: the player, selection, active tab, focus ring. Fill version `accent.fill` `#3A6BB0` (white text 5.4:1) |
| `accent.light` | `#80B3FF` | 8.1 | Accent text and outlines on dark, tower names (the player's colour) |
| `gold` | `#FFD46B` | 12.3 | Energy, costs, numbers inside text, ability names |
| `teal` | `#5ED6C7` | 9.9 | Speaker names, rewards |
| `good` | `#7EE08A` | 10.7 | Helpful effects, healing text, "can do" |
| `bad` | `#FF7A6B` | 6.8 | Harmful effects, "can't afford", errors |
| `status` | `#C59BFF` | 7.9 | Statuses and passives |
| `neutral` | `#A8C8FF` | 10.2 | Neutral effects, information |
| `shield` | `#B0D0FF` | 11.0 | Shield amount |
| `warn` | `#FF991A` | — | Stop markers, warnings |

### Combat feedback (bright, short-lived)

| Token | Hex | Used for |
| --- | --- | --- |
| `fx.damage` | `#FF4D40` | Damage numbers, hit flash |
| `fx.heal` | `#66FF73` | Heal numbers |
| `fx.status` | `#D999FF` | Status pop-up text |
| `hp.full` / `hp.half` / `hp.empty` | `#33D94D` / `#F2D926` / `#E62626` | Health bar gradient, on plates **and** on hand cards |
| `team.player` / `team.enemy` | `#4080F2` / `#D94040` | Team tint on the board, minimap |

### Rules

- Body text needs at least **4.5:1** contrast against what is behind it; big titles (32+) and icons need **3:1**. Every text token above passes on `ink.850` and `ink.700`.
- Never put coloured text on a coloured fill. Coloured fills carry `text.primary`.
- Colour is never the only signal. A disabled button is also dimmer, a harmful effect also has its icon, and an unaffordable card also shows its cost in `bad`.
- Text-markup colours (`TooltipText`, `game/ui/elements/tooltip_text.gd`) come from these tokens, so a tooltip's "harmful" red is the same red everywhere.
- Board highlights (range, aim, area, place) stay as they are on the board (`LevelController`, `game/board`). They are tuned for the board, not the HUD.

## Typography

The game uses seven text sizes, all set at the 1920×1080 reference. At 1280×720 everything shrinks to two thirds, so body text starts at 22 (about 15 px on screen). The fonts are `.ttf` files in `res://art/fonts/`, read through the theme (`TdTheme.font(role)`). **Display font: Plinth** (`Plinth-Bold.ttf`), our own (chosen 2026-10-08): heavy, rounded, squircle bowls, Turkish letters, tabular digits. It is for titles, buttons and numbers (`type.display` to `type.h3`, `type.micro`, damage numbers); **Body font: Nunito** (chosen 2026-10-08; `Nunito-Regular.ttf`, `Nunito-Medium.ttf`, `Nunito-Bold.ttf`): Medium 500 for body and tooltips, Bold 700 for emphasis, Regular 400 only on light backgrounds. License SIL OFL 1.1 with no Reserved Font Name: free in a commercial game; ship `Nunito-OFL.txt` with the game (Licenses folder or credits) and never sell the font file on its own. Symbols the two fonts lack (✓ ● ⓘ ✕ …) come from the subset fallback fonts in the same folder. Plinth specimen: [/art/ui/font-plinth/](http://92.5.94.11/art/ui/font-plinth/).

| Token | Size | Weight | Used for | On screen at 1280×720 |
| --- | --- | --- | --- | --- |
| `type.display` | 64 | Bold | Screen titles (Camp, Victory / Defeat) | 43 px |
| `type.h1` | 44 | Bold | Screen headings, banners | 29 px |
| `type.h2` | 32 | Bold | Window titles, level title | 21 px |
| `type.h3` | 26 | Bold | Section headings, list rows, speaker name | 17 px |
| `type.body` | 22 | Regular | Body text, tooltips, descriptions, buttons | 15 px |
| `type.small` | 20 | Regular | Footers, hints, subtitles | 13 px |
| `type.micro` | 18 | Bold | Numbers only: plate names, HP labels, badges | 12 px |

- **Nothing smaller than 18.** The old tooltip body (18), tooltip footer (17), bubble hint (18) and the auto-sized labels that went down to 8 or 14 were too small at 1280×720. They move to `type.body` / `type.small`.
- **Line height:** 1.25× for body, 1.1× for titles. Paragraphs in tooltips are at most about 45 characters wide (the tooltip's 340 width at 22 fits that).
- **Weights:** Regular and Bold only. Italic only for hints such as "Click to continue".
- **Casing:** Sentence case everywhere ("End turn", "Level select"). Short labels above values may be caps with 8% spacing ("ENERGY").
- **Numbers:** use the font's tabular figures for counters that tick (energy, HP, wave), so the text doesn't jitter. Damage numbers are Bold with an outline.
- **Auto-size:** allowed for labels, but with a minimum of 18. Long names wrap or get cut with "..." (three dots).
- **Outline:** text over the board (plates, floating numbers, banners) gets a black outline (0.2, 80% opacity). Text on panels gets none.

## Layout and spacing

The whole game uses one scaling setup (`project.godot`): stretch mode **`canvas_items`**, aspect **`expand`**, reference **1920×1080**, so that ultrawide and 16:10 screens scale the same everywhere. Supported screens: 16:9 and 16:10, from 1280×720 up (decided). Ultrawide works through the anchors. 4:3 is not a design target: it should stay playable, but nobody polishes for it.

- **Spacing comes from a 4 px grid:** `space.1` 4, `space.2` 8, `space.3` 12, `space.4` 16, `space.6` 24, `space.8` 32, `space.12` 48. Inside a component use 8–16; between groups 24; between screen regions 32–48.
- **Safe margin:** 32 from every screen edge for anything that isn't a full-width bar.
- **Corners:** one radius per size: 4 for small controls (34×34 buttons, icons, chips), 8 for buttons, cards and rows, 12 for windows and the tooltip. Corners come from the kit's 9-slice sprites (`res://art/ui/KitB/`, drawn by `TdSliceBox`), one sprite per radius.
- **Anchors:** bars anchor to their edge. Windows use proportional anchors (as Settings and Level Select do) with a minimum size, so they work at 16:10 and 21:9.
- **Windows:** small 760×360 (end screen, confirms), medium 70% × 70% (chapter select), large 76% × 80% (hand editor, Codex, Settings). Title at the top-left with 24 padding, close (×) at the top-right, main buttons at the bottom-right. **One way to close:** a window that opens over something (Credits, Codex, Settings, hand editor) has only the × (Esc and right click close it too; the Esc hint is in its tooltip), never an extra Back or Done that only closes. Full screens that replace another (Level select) use a Back button bottom-left instead. Choice windows like Pause close with their primary button (Continue).
- **Confirmations:** every yes/no question uses one reusable popup, `TdConfirm` (small window, title, one line saying what happens, a danger or cobalt confirm button on the right, Cancel on the left; Esc and right click cancel): Skip tutorial, Unlock a form, Quit, Reset to defaults, removing a player (Eren, 2026-10-15).
- **Screen zones of the game HUD:**
  - Top bar: 60 tall. Status on the left (Energy, Health, Wave), the phase in the middle, Pause · Skip · End turn on the right. End turn is the widest (300) and stays in the top-right corner.
  - Bottom bar: 120 tall, the hand.
  - Right bar: the inspector card, 360 wide with a 32 px margin from the right edge, 96 from the top (`HudLayout.inspector_rect`). Tower or enemy details.
  - Middle: board only. Short-lived things go here: banner at 82% height, the hint line under the action bar (see Bottom row layout), speech bubbles near what they point at.

## Components

Build new UI from these parts (`game/ui/elements`, `game/ui/theme`) before writing a new class: a plain Control with named child parts is often enough.

| Component | Class | Sizes | Rules |
| --- | --- | --- | --- |
| Primary button | `TdButton` (PRIMARY) | 220×60, wide 300×60 | Fill `accent.fill`, label `type.body` Bold. **One per screen** (Start, End turn, Play) |
| Secondary button | `TdButton` (SECONDARY) | 220×60, small 150×44 | Fill `ink.600`, outline `ink.400`. Back, Retry, Settings |
| Danger button | `TdButton` (DANGER) | as secondary | Fill `#B83A3A` (white text 5.7:1). Sell, Quit, Reset keys. Asks for confirmation if it can't be undone, through the one shared confirm popup `TdConfirm` |
| Icon button | `TdButton` (ICON) | 44×44, at least 34×34 | Icon 24, always has a tooltip (Info, Upgrade, Close) |
| Ability button | `TdButton` (ABILITY) | full bar width × 56 | Icon left, name, cost in `gold` on the right. Quick cast = `good` edge, blocked = `bad` edge |
| Card | `HudHandPiece` (tray), `TdHandCard` (menus); chapter cards are `TdButton`s, stations live in `TdStationWorld` | Hand 100×100, chapter 260×120, station 380×150 | Fill `ink.700`, outline `ink.400`, radius 8. States: normal, placed, can't afford, locked, benched (section 6) |
| Icon | `TdIconChip` | 24, 34, 48, 68 | Square, same stroke style. Value badge bottom-right in `type.micro` |
| Icon bar | `TdIconBar` | 34 icons, gap 4 | Statuses on plates and the right bar. Board plate (user, 2026-10-10), two states: **Compact (default)**: the whole plate always fits inside its unit's tile (width = the tile's on-screen width − 8, about 96 px at default zoom; it follows the camera zoom): HP bar that wide, status chips 28 px with no badges, fixed 6 px gaps, at most 3 slots (from the 4th status on: 2 chips + "+N"). **Full (the hovered or selected unit only)**: the plate grows to the full version (HP bar 164 × 8, 32 px chips with time and stack badges, 12 px gaps, up to 4 slots, then 3 + "+N"), drawn on top with a thin translucent dark backing; the neighbours' plates dim to 50%. Which statuses get the slots: Shield and other defensive buffs first, then control (Rooted, Taunted), then damage over time (Burn, Poison, Acid), then the rest; newest first within a group. [Mockup](http://92.5.94.11/art/ui/screens-b/plates-crowd.html) |
| Tooltip | `TdTooltip`, `TdTooltipStack` (shown by `TdTooltipTrigger`) | 340 wide | `ink.950`, padding 16, radius 12, header `type.h3` + body `type.body` + footer band (`type.small`, value in `gold`). Delay 0.4 s (stack 0.25 s). Tooltips draw on the top layer: nothing (hint line, bars, cards) draws over a tooltip or its tail |
| Window | `TdPopup` (menus), `HudPopup` (battle), framed by `TdPanel` | section 4 | `ink.800` on `scrim` (`TdScrim`, which blocks the pointer over the whole screen). Esc and right click close it |
| Bar | `HudTopBar` | section 4 | `ink.850` at 92%, 1 px `ink.500` line on the board side |
| Speech bubble | `TdTextBubble` | 640×180 | `ink.850`, replaced by the dialogue box (see Dialogue below), speaker in `teal` `type.h3`, text `type.body`, hint `type.small` italic |
| Plate | `TdEntityStatus` + `TdHealthBar` | \~120 wide, 10 tall bar | Over the board, so outlined text. Shows on hover, selection, after a hit and while dying |
| Settings row | the slider, toggle, dropdown and key-slot rows of the Settings window (`game/ui/screens/settings.gd`) | full width × 56 | Label left (`type.body`), control right, 24 between rows |
| Text field | `LineEdit` (kit `fields/field_paper_*`) | 56 tall | `ink.700`, placeholder `text.disabled`, focus outline `accent` |

Text markup inside components uses the tokens: ability `gold`, passive and status `status`, harmful `bad`, helpful `good`, neutral `neutral`, tower `accent.light`, values `gold`, notes `text.muted`.

### Dialogue (visual-novel style, decided 2026-10-08)

The base does not talk; that was only an early idea. Dialogue works like a visual novel: a character portrait beside a dialogue box, not a speech bubble with a tail.

- **Dialogue box** (`TdDialogueBox`): bottom of the screen, about 1100×220, centred over the hand (the hand and action bar dim and step back while it shows). Name plate on its top edge in Plinth `type.h3`, text in Nunito `type.body` revealed letter by letter, "Click or Space" hint in `type.small`, Skip in the corner.
- **Portrait:** a bust about 560 tall, standing on the box's left (or right) edge and overlapping it. It slides in 0.25 s when a speaker first talks. The expression swaps in place (neutral, happy, worried, angry, surprised). With two speakers, the one not talking dims to 60% and sinks 12 px.
- **Pointing at things: two modes (user, 2026-10-09).** The visual-novel box alone lost what the old bubble did best: showing *where*.
  - **Story lines** (no *points at* target): the big dialogue box at the bottom with the speaker's portrait.
  - **Pointing lines** (the line has a *points at* target: a unit, a tile, a UI element): **the tutorial always speaks through the visual-novel dialogue box** (user, 2026-10-14, replacing the earlier speech-bubble rule): the Princess's name plate, the letter reveal, "Click or press Space", "Tutorial · n/N" and Skip at the top-right of the box, exactly as the tutorial had them before the port. The target still gets the soft light ring (and the board dims \~30% where the line doesn't wait for the player). The box sits at the bottom of the screen and docks at the top when it would cover the target. No tooltip-style speech bubbles on the board. Steps, flow and rules of the guided tutorial: Guided Tutorial — Design.md (one allowed action per step; Skip is click-only).
  - Switching between the modes inside one sequence is a short morph (the box shrinks into the bubble and back, 0.25 s).
- **Portraits** come from the Blender pipeline: one render per expression, transparent background, same framing.

**Welcome screen:** "Skip tutorial" is a quiet text button under Start ("Skip tutorial, I know how to play", underlined, no panel), not a full-width bar that reads like a disabled button. Boot, Welcome, main menu and loading share one background: the blurred board image (`res://art/ui/Backgrounds/Spitters Blurred.png`), centred. The title text stays "Tower Defence" for now (no logo placeholder). The main-menu miniatures face bottom-left, as they did before the port (Eren, 2026-10-13).

### Codex and the Tower / Enemy Info window (2026-10-09)

- **Ability and passive rows:** the icon sits next to the name, top-aligned with the name line and left of the name and description, about 88 px at 1080p (the kit's two-tone icons; 24 px icons are too small, user 2026-10-09). The column under the icon is not left empty: the cooldown state sits there, the pips plus "Ready" / "In 1 turn" (passives: "Always on"), in a column about 110 px wide so nothing wraps. The text column on the right holds the name + type line, the description, and the numbers as one short line of tags ("Range 2 · Damage 10"). The row is as tall as its taller column. Not an icon centred in the row.
- **Codex tower page (user, 2026-10-14):** page tabs Overview · Abilities (passives at the end) · Forms (rows of unlocked forms only; the base form is a plain "Archer · Base form" row; selecting a row switches the page to that form; no count, no Back, no "Open in Workshop", no comparison between forms) · Immunities (disabled, "Coming later"). Enemies have the same tabs, with Forms and Immunities disabled. The Codex header keeps its progress bar ("5 / 9 discovered") at one fixed width on every tab, so the header never changes width (user, 2026-10-14). **Overview:** the left column is ONLY the model preview (with the form badge as a \~48 px overlay at its top-right); the description, the facts and the stat tiles (a wrapping 2-column grid) live in the wide right column, so the panel never grows with the number of stats (Priest's 5 stats wrap in place).
- **Tower Info** (the inspector's (i) button) is a sibling of the Codex page, not a different layout: a flat wood window with × and no extra icon in the top-left corner; header (on the wood) = name + subtitle ("Tower · on the board") on the left, then a "Codex" button (opens this unit's Codex page), the Health label + number + bar, and × on the right; below it one paper card (reference: Eren's screenshot of the pre-port build, 2026-10-13): left = the rotating model box ("Drag to turn") with the 2×2 stat tiles under it; right = the unit's description, then one **Abilities** list (Codex rows with the live cooldown state: "Ready", "Ready in 1 turn"; passives at the end of the same list, no separate heading) and **Statuses**.
- **Statuses section:** every status on the unit with its 48 px chip (time pill top-left, stacks pill bottom-right), its name, its description with the live values ("Takes 3 fire damage at the start of each of its turns") and a line "2 turns left · applied by Slime Archer". Empty state: "No statuses".
- **Enemy Info:** the same window with the red accent; abilities as read-only rows with their cooldowns, plus a "Next turn: walks 1 tile, then rams the base for 2" line.

**Ability text and tags (user, 2026-10-09).** [Mockup](http://92.5.94.11/art/ui/screens-b/ability-rows.html).

- **Tags are the results of the ability's formulas**, named by what they are, not by the tower stat behind them: **Damage** (not "Power"), **Heal** for healing abilities, Range, Area, Hits, Jumps, **Duration** ("2 Duration", only when it scales; never "2 turns Burn"). All tags look alike: icon + bold number + name, one pill each. In ability rows the tag line sits at the bottom of the row, on the same baseline as the "1 turn CD" label under the icon (user, 2026-10-14).
- **Many tags wrap** onto as many lines as needed (gap 6 × 12); never truncated, never shrunk. Order: Damage/Heal, Range/Area, Hits/Jumps, Duration, the rest.
- **No bonus badge** ("+2") on ability tags and **no hover** on tags: they show the final value only. (Stat tiles keep their bonus badge.)
- **Long descriptions** are shown in full (no "…" or "more"; the window scrolls), at most about 60 characters per line; the row grows, icon and cooldown stay top-aligned. The action bar tooltip shows the same full text and the same tags (340 wide; tags wrap, it may grow tall, staying above the action bar). The mockup is the approved reference (user, 2026-10-09).
- **Numbers that can change are bold** in descriptions (anything that scales or depends on stats or level): "Shoots an arrow for **10** at an enemy up to **2** tiles away." When unsure, bold.
- **Keywords** (statuses such as Stunned) are in their role colour, **not underlined**, and open their own tooltip on hover (TooltipStack). All tooltips are paper (style B).

**Abilities and passives share one list** (user, 2026-10-09), in the Codex and the Info windows: abilities first, then passives, under the single "Abilities" heading. A passive is told apart by its double-rim square chip, the type label "Passive" next to its name (where an ability shows "Attack · melee"), and "Always on" on the right where an ability shows its cooldown; no "Passives" heading and no "No passives" line. Statuses keep their own heading: they are temporary effects on the unit, with a duration and a source.

**Stat tiles fit any stat (user, 2026-10-09):** two lines, so 3-digit values and long names never clip. Line 1: icon + the number (Plinth) + an optional bonus badge ("+2", "+20"); line 2: the stat's name in Nunito 18–20 ("Duration", "Potency", "Radius", "Max HP"), never truncated. Tiles sit in a 2-column grid with a fixed width; stats the unit doesn't have are left out, and more than four stats add rows. The same tile is used in the Codex, the Info windows and the HUD inspector card.

### Decisions from the build review (user, 2026-10-09)

| Topic | Decision |
| --- | --- |
| Enemy intent chips | None on the board (user, 2026-10-09, replaces the earlier "threats only" rule and the ground arrows). Enemy intent shows only on hover: hovering an enemy shows its whole next turn (path, stop tile, attack line, damage preview on the target); hovering one ability row in the enemy's card or Info window shows only that ability's preview. The End turn hover keeps the threat summary. |
| Cooldown dots | Removed from the tray pieces and from under the towers on the board. Cooldown shows as the soft glow under towers that can still act, and the clock ring on the ability buttons. |
| Selected tray piece | No arrow symbol: selection is colour only (cobalt name plate + bright medallion ring). |
| Inspector HP | A 14 px filled bar with "Health" and "20 / 20" on their own line above it; the number never sits on the bar. |
| Right bar abilities | Towers and enemies both list their abilities in the right bar (icon, name, cooldown) (user, 2026-10-09). The list is read-only: no pressed state, no click; hovering a row shows its tooltip (for an enemy, also that ability's board preview). Using an ability happens only in the action bar above the hand. On the enemy card the list is centred. The enemy card shows NO forecast line ("Next: moves 1", "Next: Smash on Archer"; Eren, 2026-10-13): the enemy's coming turn is previewed only on the board, on hover. |
| Info window | Smaller: about 960×640 at 1080p; the content scrolls. |
| Ability buttons | The icon fills the whole button (the icon's chip is the button face). A held key shows the pressed state until it is released, exactly like a held mouse button. |
| Denied feedback | The same for keys and mouse: pressing 1 on an ability that can't be used shakes the button and shows its reason tooltip ("Ready in 1 turn"), not only the hint line. |

## States and feedback

Every clickable thing has these states, and they look the same everywhere. `TdButton` draws them from the kit's sprites per style (`TdTheme.control_style`), in these palette colours.

| State | Fill (secondary button) | Outline | Other change |
| --- | --- | --- | --- |
| Normal | `ink.600` | `ink.400` | — |
| Hover | `ink.500` | `accent.light` at 60% | Lighter face, tooltip after 0.4 s (menus only: lifts a little) |
| Pressed | `ink.700` | `ink.400` | Slightly darker, no movement (menus only: sinks 4 px) |
| Selected | `accent.fill` | `accent.light` | Stays until something else is picked |
| Disabled | `ink.700` at 60% | none | Label `text.disabled`, no hover, tooltip says **why** ("Needs 40 energy") |
| Focus (keyboard) | as hover | 2 px `accent` | Only when moving with keys |

Card states in the hand and on Level Select:

| State | Look |
| --- | --- |
| Ready | `ink.700`, full colour icon |
| Can't afford | Icon at 40%, cost in `bad` (not grey: grey reads as "locked") |
| Placed | `good` outline and a small check badge; the card stays in place |
| Locked | `ink.700` at 60%, lock icon, `???` or "coming later" |
| Benched | 60% opacity, under a "Bench" label |

Feedback rules:

- **Answer within 0.1 s.** Hover and press react at once; an action that takes longer (an enemy turn) shows that it is busy (phase text, End turn disabled with "Enemies are moving").
- **Explain every "no" (reason lines stay at 18 px or more: they wrap to a second line, left-aligned with the icon inline, rather than shrink).** A refused click (not enough energy, wrong tile) shakes or flashes `bad` and shows the reason in the hint line, not a silent nothing.
- **Empty states say what to do.** An empty hand, an empty Codex tab or an empty list shows one line, for example "Pick up to 8 towers for your hand".
- **Right click cancels** aiming, placing, selection and popups, in that order. It never presses a button.
- **Errors** use `bad` text in place, never a popup, unless the player must decide something.

## In-game HUD

In battle, the player should be able to read three things at a glance: **whose turn it is, how much energy they have, and what will hit the base next**. The HUD shows those first and everything else on demand.

**Cooldowns are the core resource and must be readable at a glance** (user, 2026-10-08). Towers have no action points: what a tower can do this turn is decided by its abilities' cooldowns (1–3 turns, they drop by one when the player phase starts; a *held* cooldown waits for an event such as a kill).

- **On the board, always visible:** a soft cobalt glow under a tower that still has a ready ability, none when it has nothing left this turn, so the player sees which towers can act without clicking each one. (The row of cooldown pips under every tower was dropped after the build review on 2026-10-09: too much clutter.)
- **On the ability button:** the big turns-left number over a radial overlay, plus a pip bar under it (one segment per cooldown turn, lit = recovered). The segment that comes back next turn pulses. Held = lock icon, the tooltip says what resets it ("Ready after a kill").
- **In words:** tooltips and rows say the ability's cooldown number as it is: "1 turn CD" (cooldown 1 = once per turn; there is no "No CD"), "2 turn CD", "3 turn CD", "CD until reset" for held cooldowns (never "Every 2nd turn", user 2026-10-09), plus the state ("Ready", "Ready next turn", "Ready in 2 turns").
- **Turn start:** abilities that came off cooldown flash their pip and a "Ready!" pops over the tower (0.6 s, staggered tower by tower).
- **End turn:** hovering it lists what is still usable this turn and what will be ready next turn. Its attention glow starts when no tower has a ready ability and no card is affordable.
- **Enemies:** their cooldowns show the same way on the enemy inspector card, so the player sees what each enemy can do next. (Idea for Eren: an "intent" icon over enemies whose big ability is ready.)

Working demo: [HTML prototype](http://92.5.94.11/art/ui/prototype/); in the game: the [Godot web build](http://92.5.94.11/art/godot/td/).

### The hand is a tray of miniatures (decided 2026-10-08)

The hand's towers are not cards. They stand side by side as miniatures on a wooden tray at the bottom of the screen, like pieces waiting beside the board (as in Into the Breach), in a straight row, no fan.

- **Each piece:** the unit render on its plinth (about 112 tall), a name plate under it (Plinth 18 on wood), a cost coin top-left (gold; red when unaffordable), the key number top-right.
- **Hover:** the miniature lifts 16 px and its shadow shrinks, as if picked up (the lift is visual only: the hit area never moves, so the piece doesn't flicker under the cursor; the same for Hand select cards; user, 2026-10-15); the name plate gets the accent outline; the tooltip opens straight above that piece after 0.4 s.
- **Picked (placing):** lifted 30 px with a gold glow until it is placed or cancelled; on placing it flies up out of the tray.
- **Can't afford:** the miniature at 40% and greyed, the coin red; a click shakes it and says why.
- **Tray:** flat wood with a thin dark rim, 168 tall, at the bottom-left (see Bottom row layout); it holds up to 8 pieces. A piece's key badge and its tooltip show just the number ("1"), never "Ctrl+1" (user, 2026-10-13).

**Placed vs not placed (decided 2026-10-08).** A placed tower's card stays in the tray and must look clearly different:

|  | Not placed | Placed (on the board) |
| --- | --- | --- |
| Plinth | The miniature stands on it, full colour | **Empty**, with a round colour portrait medallion of the tower (head and shoulders, cobalt frame) standing on it: the piece is on the board, and you still see who it is (a silhouette was tried and rejected: towers became hard to tell apart) |
| Top-left | Cost coin (gold, red when unaffordable) | Gone |
| Under the name | Nothing | **HP bar**, readable (green → yellow → red), "14 / 20" on hover |
| Cooldowns | — | Mini cooldown pips, the same as under the tower on the board |
| Name plate | Wood | **Wood, no tag: the portrait medallion already shows the piece is placed (Eren, 2026-10-13; the ✓ "on board" tag is dropped). Not cobalt: cobalt is kept for the selected piece** |
| Click | Pick it up to place it | Selects the tower on the board, the camera glides to it |
| Hover | Lifts, tooltip | The tower's ring lights up on the board |

When the tower dies or is sold, the miniature drops back onto its plinth and the card is "not placed" again. The tray thus doubles as the team roster: who is hurt and who can still act, at a glance.

**The selected tower is selected in the tray too (user, 2026-10-09).** When a tower is selected on the board, its piece in the tray shows it: the piece lifts 8 px, its medallion gets a bright cobalt ring with a soft glow, the name plate turns cobalt, and a small arrow above the piece points up toward the board. It works both ways: selecting the tower on the board selects its piece; clicking the piece selects the tower and the camera glides to it; hovering the piece lights the tower's ring on the board. With two towers of the same type (two Archers) this is the only way to tell which piece is which, so it must never be skipped. Suggestion: the board's selection mark becomes the same cobalt ring, so "selected = blue" reads the same everywhere.

### Bottom row layout (user, 2026-10-09)

The bottom row reads left to right: what I have (tray), what I do (action bar), finish (End turn). Before, the tray, the action bar and the hint all stacked in the bottom-centre while the bottom-left stayed empty. Mockups: [compare page](http://92.5.94.11/art/ui/screens-b/hud-layout.html) (before, after, 6 towers, denied click, 8 towers × 6 abilities).

- **Tray:** bottom-left, left-aligned with the top-left pills' margin (32 at 1080p), grows to the right.
- **Action bar:** centred on the SCREEN (Eren, 2026-10-13), about 62 px above the bottom edge; never left-aligned next to the tray. If a wide tray would overlap it, it shifts RIGHT just enough to clear the tray by 24 px (never left); if that would touch End turn, it rises a row instead (below).
- **Hint line under the action bar:** centred on the bar (left-aligned with it when the bar has slid right), in the strip between the bar and the bottom edge, `type.small` 20, cream with a dark outline (red `bad` for a refused action). Every tooltip opens upward, so nothing can ever cover the hint. Example: pressing Tower Walk while its tooltip is open and it is cooling down shakes the button, flashes the tooltip's cooldown line red ("Ready in 1 turn") and shows "Tower Walk is ready in 1 turn." under the bar, all visible at once.
- **When the tray and the bar don't fit side by side** (at 1920: 130 × pieces + 110 × abilities > 1372, e.g. 8 pieces with 4+ abilities, 7 with 5+, 6 with 6+): the action bar and its hint line move up to a row above the tray's right part, centred on the screen. The tray never shrinks. The camera framing counts that raised row, so the board's front row is never hidden under it.
- **Right bar ability list:** up to 6 rows fit above Sell; from 7 abilities on, the list scrolls.

### Level select (2026-10-13/14)

Reference mockup: [level-select](http://92.5.94.11/art/ui/screens-b/level-select.html). Left: chapter groups with level rows (number, state "✓ Won" / "● New" / lock with its reason). Right: breadcrumb, title, description, fact tiles (waves, enemies, towers in hand, energy and income), the board preview (35° "contain" render with a blurred backing, the same as in co-op and chapter cards), the first-win reward line, Play. Bottom: the hand row with the level's cap divider ("Two Roads takes the first 4") and Change hand (opens Hand select before a level).

- **Enemies in this level** are shown only once the player has played the level at least once (user, 2026-10-14). Before that, the section keeps its heading "Enemies in this level" with one muted body line under it, "You'll see them when you play it.", and no chips; the enemies fact tile shows the count with a generic enemy icon (not a portrait).

### Camp and Guild places (2026-10-14)

Both are a 3D room or diorama with wood station buttons. Game rules: Camp & Chapters — Design, Missions & Guild — Design, Workshop — Design.

- **Station buttons sit on the floor, just in front of (below) their prop**, at the same baseline as the front-row buttons; never on or above a back wall, even for tall back-wall props (door, rack, fireplace). Leader lines stay short or are left out. If the spot in front would cover another prop (the Camp's campfire, the Workshop table), the button goes BESIDE its prop on the floor (the side facing the free space), still never on another prop; only if neither fits does it rise above the prop, with a leader line. Props don't move for buttons. Above all, a button must never look like it belongs to a different prop, and it stays inside the board's outline.
- **Going back is navigation, not a station:** "← Main menu" in the Camp and "← Camp" in the Guild sit at the screen's bottom-left. The prop that stands for the way back (the Guild Door) highlights on hover and is clickable too. The Camp's way to the Guild is a **Guild** station button, where Multiplayer used to stand (the Signpost prop stands there; no hotspot on the prop itself). Multiplayer exists only in the Guild. Pressing Guild slides the screen: the Camp out to the left, the Guild in from the right; going back plays it in reverse (user, 2026-10-15).
- One cobalt primary per place (the Guild's Missions). Stations that are not open yet are **not shown at all** (no greyed or locked state): the Guild and Workshop buttons appear once Chapter 2 is cleared (user, 2026-10-15). A developer layout editor (F1) lets props be dragged on the Camp and Guild boards and the layout saved; buttons follow their props.

### Co-op lobby and room (2026-10-13/14)

Game rules live in Multiplayer — Design and Missions & Guild — Design; mockups: the `lobby-` and `co-op-pass` pages in screens-b.

- **Join and Create** windows open centred over the dimmed list (\~65%).
- **Room:** players in one column of compact rows (turn number, medallion, name, ping dot, Host / You, the hand as 3 small medallions, Ready); empty slots are dashed rows with no text; Leave room always bottom-left; Ready / Start bottom-right; chat fixed size on the right (about 9 lines at 1080; never squeezed by the side card: in a mission room the mission name and plays go into the room header and the drops into one compact coin row, and the level picture shrinks before the chat does). The backdrop while waiting is the plain wood planks, not the blurred level picture (user, 2026-10-14).
- **Change hand** in the room sets the player to Not ready; the new hand is sent once, when the hand editor closes (user, 2026-10-14).
- **In the match:** Pass is a small wood coin at End turn's lower-left joined by a thin neck; Not your turn = a solid dark End turn with the current player's medallion; turn order as medallions in the tracker (✓ ended, ↻ passed); other players' towers show their abilities dimmed with "Şule's tower".

### Hand select (user, 2026-10-13)

Replaces the old hand editor. Large window (76% × 80%) titled "Your hand", × only; changes save as you go. Interactive reference: [hand-select](http://92.5.94.11/art/ui/screens-b/hand-select.html) (before a level: `?from=level`).

- **Towers are individuals.** Every tower has its own tower ID, so two Archers are two cards with their own numbers; nothing is ever stacked as "×2". There are no locked or unknown towers: the game is about collecting them.
- **Hand row (top):** up to 8 tray pieces in order (miniature, cost coin, key number); empty slots are dashed sockets; drag to reorder (the key follows), × on hover removes. From the Camp all 8 slots look the same; before a level a divider sits after that level's cap ("Two Roads takes the first 4") and the slots after it are slightly dimmed.
- **Layouts:** four fixed tabs beside the hand row (Eren, 2026-10-13). Layout 1 holds the starting hand, 2–4 start empty ("Empty 0/8"); each keeps its own 8 slots; rename only (24 characters; the pencil, and the name commits on Enter or when the field loses focus), no add or delete. A tab shows only the layout's name: no mini tower icons and no "0/8" count (user, 2026-10-14). The active layout (cobalt outline) is the one levels use.
- **Filters (left):** search, role chips (Attack, Spell, Support, Control, derived from the tower's abilities; no Movement chip and no "Can move" toggle, since every tower has Tower Walk), delivery chips (from the abilities' tags), a cost slider with ≤100 / ≤200 / 200+, toggles (Heals, Applies statuses, Hide my hand), a result count and Clear filters. Sort: Default (the release order, by the tower type's hidden number; Eren, 2026-10-13), Name, Cost.
- **Collection grid (centre):** compact cards: portrait, name, cost coin, and the key badge when the tower is in the hand. No stats on the cards and no tooltip on them (the detail panel is the information; Eren, 2026-10-15).
- **Detail (right):** no model image; name, number, cost, description, stat tiles, compact ability rows, passives; "Add to hand" (first empty slot), disabled with a reason when the hand is full.
- **Adding:** Add to hand, double-click, or drag a card onto a slot (onto a filled slot it replaces that tower).

### Board previews: intents and damage (decided 2026-10-08)

The board shows what will happen before it happens. Player actions preview in cobalt and gold, enemy actions in red; the two never share a colour. Every preview also has a pattern, so it reads without colour.

| What | When | Look |
| --- | --- | --- |
| **Enemy intent** | Hovering the enemy (its whole next turn), or one of its ability rows (that ability only) | No chip on the board (2026-10-09). The hover shows the path, stop tile, attack line and the damage preview below; the enemy's card lists its abilities with their cooldowns |
| **Enemy path** | Hovering an enemy | Tiles it walks over: red dashed outline. The tile it stops on: solid red with a soft glow |
| **Enemy attack** | Hovering an enemy | A dashed red arc from the enemy to its target, and the target's HP bar shows the loss |
| **Your ability's range** | Hovering an ability | Kit decal\_range: soft blue fill, single thin border (the double cobalt ring is only for selection). Area while aiming: decal\_area (hatched). Placing: decal\_place / decal\_place\_blocked. Walking: decal\_move, decal\_move\_step, decal\_move\_dest (cream, dotted). Sheet: http://92.5.94.11/art/ui/kit-b/sheet-decals.png |
| **Your valid targets** | Aiming | The targets' tiles pulse red; the rest of the range stays blue |
| **Damage preview** | Aiming and hovering a target | The part of the HP bar that will be lost blinks in white/red stripes; a "Kills" tag when it is lethal. Heals preview the gained part in green |
| **Threat summary** | Hovering End turn | "Base −4 · Archer −6", plus what is still usable and what is ready next turn |
| **Enemy acting** | Enemy phase | A red ribbon with the ability's name over the enemy ("Smash!") |

In the game: tile previews are decals just above the board (`game/board`, dashed outline = path); arcs are dashed, scrolling lines; chips, tags and HP previews are screen-space UI in the board overlay (`BattleOverlay`, `game/board/overlay`) that follows the unit (like the plates). Statuses on the board stay visible at all times; only the HP bar follows the hover rule.

**Attack previews follow how the attack travels** (user, 2026-10-08). The game tags attacks `Melee`, `Projectile`, `Lobbed`, `Beam` and `Spell`; walls (`blocksProjectiles`) and units that block projectiles stop straight shots, and replacement rules (e.g. Bodyguard) can redirect a hit. The preview must show where the attack really lands, not only who was aimed at. The same shapes are used for the player's attacks (cobalt/gold) and enemy intents (red).

| Delivery | Preview line | When something is in the way | Icon (ability rows, tooltips) |
| --- | --- | --- | --- |
| `Melee` | A short solid chevron from the attacker to the adjacent target | — (needs adjacency) | Sword |
| `Projectile` (straight) | A straight dashed line low over the board | The line stops at the first blocker (wall or blocking unit) with a ✕ marker; the blocker gets the damage preview (or "Blocked" if it takes none); the aimed target is greyed with "Blocked by Wall" | Arrow |
| `Lobbed` | A high dotted arc; an impact ring on the landing tile (and the splash area if any) | Flies over blockers: no ✕; a small "over" note when it passes a wall | Arc |
| `Spell` (direct) | No travel line: a rune mark pulses under the target, a faint link to the caster | Ignores blockers | Spark |
| `Beam` (no ability yet) | A solid line through every tile on its way | Hits everything on the line: each unit gets its own damage preview | Beam |

- **Redirects:** when a rule moves the hit (Bodyguard, Taunt), the line bends to the new target with a small "redirected" marker, and the damage preview moves with it.
- **Aiming:** targets that can't be hit (blocked) stay visible but greyed, and their tooltip says why. A target that is valid only by lobbing shows the arc on hover. The aiming ability's BUTTON shows it is the one in use (user, 2026-10-13): a gold rim (kit ability\_aiming) instead of the blue ready rim, lifted 5 px, a slow gold glow pulse (pulse.attention), its key badge turns gold; the other ability buttons of that unit dim to 60%; the action bar's label reads "Shoot: pick a target". Gold is the same "in your hand right now" colour as a picked tray piece. Right click, Esc or pressing the same key again cancels and restores all buttons.

- **Always on:** the top bar (energy, base health, wave x / y, phase, End turn) and the hand. Nothing else stays on screen by default.
- **On demand:** the right bar (when a tower or enemy is selected), tooltips (hover), the full plate (hovered or selected unit). Every unit always shows its compact plate (HP bar + up to 3 status chips, inside its tile; 2026-10-10, see the Icon bar row).
- **Phase is the loudest text.** The phase label sits in the top-bar centre in `type.h3`. On a new round a banner shows for 0.8 s; a newer banner replaces an old one, and banners never block clicks. A wave banner shows only the wave's name (no "begins"); the phase chip reads "Your turn" / "Enemy turn" (never "Level phase") (Eren, 2026-10-15).
- **End turn** is the primary button, in the bottom-right corner. It glows softly when the player has nothing left to do, and it is disabled during the enemy turn.
- **Tooltips never cover what they describe:** ability and passive tooltips open left of the right bar; hand card tooltips open straight above their own card (above the action bar when it shows), centred on the card and clamped to the screen, the tail pointing down at the card; they never jump to the side of the action bar (user, 2026-10-09); board tooltips follow the mouse at (16, −16).
- **Readable over the board:** bars are `ink.850` at 92%, so the board's greens and browns never show through text. Anything drawn straight over the board (plates, numbers, banners) has an outline.
- **Plates and numbers are screen-space** and follow their unit, so they read the same at any camera angle. Damage numbers start on the impact frame, rise and fade over 0.9 s; several numbers on one unit stack upwards and don't overlap.
- **Board highlights stay quiet:** build tiles look like ground until the player places a tower (Decisions.md). Range, aim and area use the `LevelController` colours at low alpha.
- **Enemy intent:** what an enemy will do next (path preview, aim) uses `bad` / `fx.damage`; what the player's tower will do uses `accent` / `good`. The two never share a colour.

Rules added after the screen test of 2026-10-08 (16:9, 16:10 and 4:3):

- **The camera frames the free area, not the whole screen.** The board is fitted between the top bar and the bottom row and centred on the WHOLE screen width; the right bar is not kept clear and may cover the board's edge while it is open (Eren, 2026-10-11). Mid-screen banners centre on the screen. The inspector card may cover edge build tiles (accepted). Turning the camera never refits the board; the zoom-out limit after a turn keeps tall boards clear of the HUD (Eren, 2026-10-15).
- **Tooltips stay off the board's previews.** While a range, aim or area preview shows, the tooltip opens where it covers none of it (inside the right bar under the ability list, or the far corner of the board).
- **Card size follows the text:** hand cards grow to about 104×112 so the name (`type.small`) and the cost (`type.micro`) fit at the minimum sizes; the bottom bar stays 120.
- **No text as images:** labels like "Wave" are text, so they scale and stay readable.
- **Menu panels fit their content** (no fixed height with empty space at the bottom).

## Icons and imagery

Icons follow the Painted Miniatures style: simple shapes, a dark 2 px outline, flat colour with one highlight, no tiny details.

- **Grid:** drawn on a 64×64 canvas with 4 px padding, readable at 24. Exported as PNG, power-of-two, sprites in `res://art/icons/` (gameplay) or `res://art/ui/KitB/` (interface).
- **Colour by role:** ability icons use their effect's colour (harm `bad`, help `good`, status `status`); resource icons use their token (energy `gold`, health `hp.full`). Interface icons (close, info, settings) are single-colour `text.primary`.
- **Unit portraits** for cards, the right bar and the Codex come from the Blender models (a 3/4 view on the dark plinth), so a tower looks the same on the board and in the hand.
- **Every icon has a name.** An icon alone always has a tooltip; in lists it has a label.
- **9-slice sprites** for panels and buttons (radius 4, 8, 12) go in `res://art/ui/KitB/` (borders in `game/ui/theme/kit_slices.json`, drawn by `TdSliceBox`), so corners stay sharp at every size.

### Status and ability icons (2026-10-08)

Every status and ability has its own icon ([kit](http://92.5.94.11/art/ui/kit-b/), folders `statuses/` and `abilities/`).

- **Two-tone glyph:** cream fill `#F5EAD6` with a dark rim `#120C09`, baked into the PNG. No other colours inside the glyph.
- **Meaning comes from the chip:** its colour and its shape. On screen an icon has at most three colours (chip, cream, rim). Shape keeps it readable without colour.
- **Sizes:** 48 (Codex, Info status rows), 40 (status chips on the right bar card), 34 (inspector, action bar), 32 (status chips on the full board plate), 28 (compact board plate, no badges), 24 (tooltips, text; status chips at 24 show no badges). Every glyph is checked at 24 px on wood, paper and board green.
- **In the game:** `res://art/icons/Statuses/<Name>.png` and `res://art/icons/Abilities/<Name>.png` (no spaces: `AcidFlask.png`), set as the `icon` of each entry in `data/content/Statuses.json` / `Abilities.json` (`Status/Burn`, `Ability/Acid Flask`) by Eren.

**Statuses.** Every status is a circle (user, 2026-10-09): buff = circle with a thin double rim, debuff and untagged = plain circle. Shapes by kind: ability = square, passive = square with a double rim, status = circle (buffs double-rimmed), so the shape alone says what a chip is. A status has **both** stacks and a duration (re-applying adds stacks and restarts the timer), so the chip always shows both:

- **Stacks:** number badge bottom-right, hidden at 1. Shield always shows it (the points it still absorbs).
- **Duration and stacks badges (user, 2026-10-09/10).** No ring around the chip. **Time left** = a **cream pill** (paper fill, thin dark rim, number in dark ink) at the chip's **top-left** corner, for every timed status; turns and rounds look the same (the tooltip says "2 rounds"); permanent statuses show no time badge. **Stacks** = a **dark pill** (cream number) at the **bottom-right** corner, hidden at 1 (Shield always shows it). Each badge is centred on the chip's edge (half outside), so they never meet and the glyph stays visible. Both are round for one digit and, for 2 and 3 digits, grow equally to both sides around that same centre (the badge never moves); 4 digits and more are shortened to one decimal + k (1250 → "1.2k"). Chips in a row are evenly spaced with a fixed gap, never by the badges' width (user, 2026-10-10): board 32 px chips with 12 px gaps (a row of 4 = 164 px), right bar 40 px chips with 12 px gaps. The gap is chosen so that even the widest pills ("1.2k" stacks next to "1.2k", "123" turns next to "123") never touch. Sizes at 1080p (chip / badge height / number): full board plate (hovered or selected unit) 32 / 18 / 14 (the compact plate shows no badges); right bar card 40 / 22 / 16; Info and Codex rows 48 / 24 / 18; numbers in Plinth Bold. The 14 and 16 px numbers are the one exception to the 18 px minimum (Slay the Spire's status numbers measure about 14 px at 1080p); the tooltip carries the exact values. Mockup of the three places (board plate, right bar card, Info window): http://92.5.94.11/art/ui/screens-b/entity-status.html
- **Re-applied:** the stacks badge bumps and the time badge flashes.
- **Several instances** (stacking *Independent* or *PerSource*): one chip per instance, side by side, each with its own stacks and time; the tooltip names who applied each.

The kit's first version showed turns-left dots only up to 3; this replaces it.

**Status durations in the UI.** The chip shows the instance's real turns left. Ability tooltips and Codex ability rows say the duration the ability applies ("Applies Burn for 2 turns").

| Status | Glyph | Chip | Shape | The chip shows |
| --- | --- | --- | --- | --- |
| Acid | Drop with bubbles eaten into it | Acid green | Circle | Stacks (damage per tick), turns left |
| Burn | Single flame | Fire orange-red | Circle | Stacks (fire damage per tick), turns left |
| Burning | Campfire on crossed logs | Ember orange | Circle | Rounds left (stacks if more than 1) |
| Enraged | Anger mark | Rage red | Circle | Nothing (permanent, +10 Power in the tooltip) |
| Poison | Skull | Purple, green inner line | Circle | Stacks, turns left |
| Rooted | Boot held to the ground by roots | Control slate | Circle | Turns left |
| Gorged | Overflowing bowl | Green | Double-rim circle (buff) | Stacks (+20 max HP each), permanent |
| Haste | Double chevron + speed lines | Teal | Double-rim circle (buff) | Stacks (+1 Speed each, max 2) |
| Rallied | Two rank chevrons | Gold | Double-rim circle (buff) | Turns left |
| Shield | Heraldic shield, half lit | Light blue | Double-rim circle (buff) | Points it still absorbs (always) |
| Taunted | Magnet | Control slate, red inner line | Circle | Turns left; who taunted it in the tooltip |
| Unknown | Question mark | Wood | Circle | Stacks if any |

**Abilities.** Rounded-square chip coloured by role: attack red, spell purple, movement wood, support/heal/buff green, control gold.

| Role | Abilities and glyphs |
| --- | --- |
| Attack (red) | Shoot: fletched arrow · Bolt: heavy ballista bolt · Bombard: bomb with fuse · Volley: three rising arrows · Pinning Shot: arrow in the ground · Spit: flying glob · Bash: spiked mace · Smash: sledgehammer · Slam: arrow onto cracked ground · Crush: plates squeezing · Ram: ram horn · Bite: jaws · Nibble: bitten disc · Execute: axe · Shield Bash: shield with speed lines |
| Spell (purple) | Firebolt: tilted flame · Fireball: fireball with streaks · Fire Wall: wall with flames · Acid Flask: flask · Chain Lightning: forked bolt · Smite: ray from above · Spark: four-point spark · Raise Skeleton: gravestone + up arrow |
| Movement (wood) | Walk: single boot with motion lines · Path Walk: winding dotted path · Brute Walk: three-toed monster footprint with impact marks · Tower Walk: small tower with an arrow · Hop: jump arc · Blink: ghost circle to solid circle |
| Support (green) | Mend: heart with plus · Slime Mend: slime with plus · Rally: war drum · Quicken: stopwatch |
| Control (gold) | Taunt: shout burst "!" · Provoke: arrows pulling to a point |

**Passives.** A rounded-square chip with a thin double rim ("always on"; user, 2026-10-09), so a passive never looks like a clickable ability; colour by role: attack red, support green, defence light blue, boss gold, hazard ember. Counter-attack (Guardian), War Beat (Drummer), Bloodthirst (Execute), Glutton (Slime Glutton), Rock Eater (Rockjaw), Shielded (Ironhide, Shield Slime) and FireTile (burning ground). Shielded (passive, double-rim square) and the Shield status (buff, double-rim circle) are both light blue: the shape tells them apart. Path: `res://art/icons/Passives/<Name>.png` (the `icon` of each `Passive/…` entry in `data/content/Passives.json`).

Walk, Brute Walk, Tower Walk, Rooted and Gorged were redrawn on 2026-10-08 after the first check at 24 px. The one glyph still to watch is **Gorged**: at small sizes the bowl can read a little like a face.

## Motion

Motion explains what happened; it is never decoration that makes the player wait. UI motion goes through `TdMotion` (`game/ui/theme/td_motion.gd`: channels that ease with smoothstep on unscaled time), with the durations and curves from the theme.

| Token | Duration | Used for |
| --- | --- | --- |
| `motion.instant` | 0.08–0.12 s | Colour change on hover, tooltip fade |
| `motion.quick` | 0.15–0.2 s | Press punch, hover scale, status icon pop, energy tick |
| `motion.normal` | 0.25–0.3 s | Panels opening, spawn pop, health bar slide, damage flash |
| `motion.slow` | 0.4–0.6 s | Death fade, ghost health bar, window slide |
| `motion.banner` | 0.8–1.2 s on screen | Round / phase (0.8), wave (1.2) banners |

- **Easing:** ease-out when something appears, ease-in when it leaves, a small overshoot (1.06) only for things that pop (cards, icons, buttons spawning).
- **Windows** open in 0.25 s (fade + scale from 0.96) and close faster (0.15 s).
- **Idle motion** (button bob, glow pulse) only on the one thing the player should press next (End turn when nothing is left to do, Start on Welcome). Everything else is still.
- **Game speed:** HUD motion uses unscaled time, so menus don't speed up or slow down with game speed. Combat feedback (numbers, flashes) follows game speed.
- **Instant Playback** (setting) skips combat animations but keeps the numbers.

## Accessibility

The game should be fully playable by someone who can't tell red from green, who plays on a small laptop, or who plays with keys only.

- **Contrast:** 4.5:1 for text, 3:1 for icons and outlines (section 2).
- **Colour blindness:** red and green are never the only difference. Health also has its number, harmful and helpful effects have their icons, and the board's range / aim / area also differ in pattern or outline. Check new screens with a deuteranopia filter.
- **Text size:** minimum 18 at 1920×1080 (section 3). A UI scale setting (90–130%) is a good later addition.
- **Keys:** every action in battle has a rebindable key (the `KeyBinds` autoload, `game/app/key_binds.gd`), and the Controls tab shows them. Tooltips and bubbles show the player's own bindings through `{key:…}` tokens.
- **Reduce motion** (later setting): turns off camera shake, the button bob and glow, and the overshoot.
- **Time:** nothing in the UI has a timer the player must beat. Bubbles wait for a click or Space.

## Implementation in Godot

The tokens live in one place that every screen and the runtime read.

- **One theme:** `data/content/UITheme.json` holds the colour, type-size, spacing and motion tokens. `tools/build_theme.gd` turns it (with the kit's `game/ui/theme/kit_slices.json`) into `TdTokens` (`game/ui/theme/td_tokens.gd`, generated, never edited) and the Godot Theme `game/ui/theme/td_theme.tres`. Code reads them through `TdTheme` (`TdTheme.color("accent")`, `TdTheme.font(role)`, `TdTheme.font_size(role)`, `TdTheme.apply_type(label, "body")`); `TdButton`, `TooltipText` and the board overlay read from it too. Decided 2026-10-08: screens don't keep their own colour and size constants.
- **Fonts:** Plinth and Nunito `.ttf` files in `res://art/fonts/`, with the subset symbol fonts as fallbacks. All text gets its font from the theme, never a default font.
- **Composition before new classes:** build from the parts in `game/ui/elements` and `game/ui/theme`; windows and screens block the pointer behind them with a full-screen scrim (`TdScrim`).
- **The code that builds a screen is the source of truth for layout** (its `.tscn` or the `.gd` that builds the tree, `HudLayout` for the battle HUD). A rule in this doc that changes a size or anchor changes that code, never a one-off tweak.
- **Checking a screen:** the `uiux` agent can play the Godot web build (http://92.5.94.11/art/godot/td/) at 1920×1080 and 1280×720 and compare screens with these rules. The web build must be re-exported so it shows the current UI.

## Today's screens vs these rules

These are the gaps found before the port (in the live build of 2026-10-05), biggest first. The Godot theme was built from these rules; check its screens against this list.

| # | Where | Today | Rule |
| --- | --- | --- | --- |
| 1 | Tooltip body / footer, bubble hint | 18 / 17 / 18 | `type.body` 22 / `type.small` 20 (section 3) |
| 2 | Auto-sized labels (buttons, HP label) | minimum 14 / 8 | minimum 18 |
| 3 | Colours | \~70 values, 3 golds, 4 reds, 2 health-bar sets | one token per role (section 2) |
| 4 | Fonts | the engine's default font only, no … glyph | a chosen font in `res://art/fonts/` |
| 5 | Main Menu, Boot, BattleOverlay scaling | match 0 | match 0.5 (now one project-wide stretch setup, section 4) |
| 6 | Button selected colour | `#4073B3`, tabs `#4D99FF` | `accent.fill` / `accent` everywhere |
| 7 | Credits, Miscellaneous panels | white buttons with black text, grey text | secondary buttons, `text.secondary` |
| 8 | Can't-afford card | grey `#8C8C85` | icon at 40% + cost in `bad` |
| 9 | Sprites | built-in sprite, no 9-slice | own 9-slice sprites, radius 4 / 8 / 12 |
| 10 | Quick cast button | `#339E52` with white text (3.4:1) | `#2E8A48` (4.3:1) or a `good` edge |

At that time the uiux agent had seen only the Welcome screen. A full pass over every screen of the Godot web build comes next.

### Open questions for Eren

- [ ] Is the cool navy UI the right frame for the warm Painted Miniatures board, or should panels move toward the plinth's dark brown?
- [ ] Display font: our own Plinth (yes, 2026-10-08). Body text: Nunito (yes, 2026-10-08). Still open: kerning for Plinth.
- [x] Cobalt replaces teal for tower names (yes, 2026-10-08). Teal stays for speaker names and rewards.
- [x] One theme (`data/content/UITheme.json`, read through `TdTheme`) instead of constants in each screen (yes, 2026-10-08).
- [x] 1280×720 is the smallest supported screen (yes, 2026-10-08). 4:3 is not a design target (recommended; confirm).
- [ ] Later settings: UI scale and Reduce motion?

### Eren's answers (2026-10-08, via the game's agent)

| Question | Answer |
| --- | --- |
| Enemy intents and board previews | Yes, even more detailed; shown only on hover |
| Dialogue speaker | The Princess, for now; the base doesn't talk |
| Ability keys | Stay 1–9 |
| HUD speed button | No; speed stays in Settings |
| Pause in a level | "Quit to level select" and "Quit game"; the tutorial's Pause also has "Exit tutorial" |
| Victory screen | Shows base HP left and towers lost |
| Main menu Continue | No mid-level save; Continue shows the next level |
