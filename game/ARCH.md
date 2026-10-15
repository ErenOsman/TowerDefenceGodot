# Game layer architecture (res://game) — read with PORT.md

Godot pass 2026-10-15: the Godot build is the game; the Unity repo (`~/game`) is frozen and read-only.

The simulation (`res://sim`) is a 1:1 port of the Unity game's engine-free C#. The game layer is NOT a 1:1
port of the Unity MonoBehaviours/uGUI (14k lines of Unity-specific UI): it is a Godot-native rebuild of the
same screens and behaviours, built from the design docs in `docs/design/`. The frozen Unity code stays a
reference for *what* happened there (`~/game/Assets/Scripts/Gameplay/*.cs`, `~/game/Assets/Scripts/UI/**/*.cs`);
the look comes from the UI/UX docs.

## Docs that define the look and flow
- `docs/design/UI Design Rules — Design.md` — the UI rules (tokens, type scale, components, HUD, states, motion).
- `docs/notes/ui/hud-menu-spec.md` — style B "Painted Diorama": every screen part with sizes, sprites, states, keys (a Unity-era spec, kept for the kit).
- `docs/design/Animation & Presentation — Design.md` — Director/presenters/view model/camera (built in sim/presentation + here).
- `docs/design/Level Select — Design.md`, `Camp & Chapters — Design.md`, `Codex — Design.md`, `Guided Tutorial — Design.md`,
  `Tutorial, First Run & Sequences — Design.md`, `Tiles — Design.md` (step 5: the look of tiles), `Workshop — Design.md`,
  `Missions & Guild — Design.md`, `Multiplayer — Design.md`, `Game Overview — Design.md`.
- `docs/GODOT-NOTES.md` — where the Godot build differs, and how its newer parts (co-op, Workshop, Guild, tutorial) are wired.
- `~/game/Assets/.agents/CONTEXT.md` — how the frozen Unity game was wired (scene flow, save, keys, sequences, codex, camp, rewards).
- `~/uiux/UI-RULES.md` — short rules copy; `~/uiux/kit-b/README.md`, `slices.json`, `manifest_ui.json`, `tokens.json` — the sprite kit.

## Assets already in the project (imported; `./check.sh` keeps them valid)
- `res://art/models/<Unit>.fbx` — 45 units/projectiles from the Blender pipeline (Painted Miniatures style). Each unit
  FBX has an AnimationPlayer with clips `<Name>|Idle`, `|Walk`, `|Attack`, `|Cast`, `|Hit`, `|Die` (last frame = corpse),
  `|Spawn`; many have a `Muzzle` node (projectile start). Projectiles (`Arrow`, `Ballista Bolt`, `Cannon Shell`, `Fire Orb`,
  `Acid Flask`, `Spit Glob`, `Wisp Spark`) have one clip. 1 unit = 1 tile, origin at the feet, model faces −Z.
  The Unity `view` path `Assets/Art/Models/<Unit>/<Unit> Blender.prefab` maps to `res://art/models/<Unit>.fbx`.
- `res://art/tiles/*.fbx` — the 30-piece map kit (`~/blender/out/tiles/README.md` has the axis/side rules): Ground A–D,
  Build Ground A/B, Road Straight/Corner/T/Cross/End, Chasm 0–4 variants, Wall pieces, Board Edge Side/Corner, Bridge, Bush, Fence, Fire Tile…
- `res://art/camp/*.fbx` — Camp props (Campfire, Codex Lectern, Miniature Shelf…).
- `res://art/icons/{Abilities,Passives,Statuses,Units,Units/Miniatures}/*.png` — the Unity icon PNGs. A JSON icon ref
  `Assets/Art/Icons/Abilities/Shoot.png#Shoot` → `res://art/icons/Abilities/Shoot.png`.
- `res://art/ui/KitB/<group>/*.png` — the style B sprite kit (895 sprites; 9-slice borders in `game/ui/theme/kit_slices.json`,
  a copy of `~/uiux/kit-b/slices.json`; 2× the 1920×1080 reference: draw at half size). Groups: abilities, abilities_face,
  ability, attack, backgrounds, badges, bars, board, buttons, chips, cooldown, endturn, fields, forms, hand, icons(_64/_128),
  menu, panels, passives, screens, statuses, tokens, units.
- `res://art/fonts/Plinth-Bold.ttf` (display), `Nunito-{Medium,Bold,ExtraBold}.ttf` (body) + `Nunito-OFL.txt`.
- `res://art/music/{menu,map1,map2,map3,battle}.mp3`. `res://art/portraits/<Unit>.png` (bust renders).
- VFX: `game/level/vfx/effects.json` (a copy of `~/vfx/spec/effects.json`: 43 effects, 104 layers in Shuriken terms) + the
  cut-out sprites in `game/level/vfx/sprites/`, approximated with CPUParticles3D by `VfxKit` (GL Compatibility renderer:
  no GPUParticles collisions, keep it simple).

## Scenes and ownership
| Area | Folder | Owner (phase 2 agent) |
|---|---|---|
| App shell: autoloads `GameApp` (content library + converter + catalog, loaded once), `SaveData` (GameData JSON in `user://gamedata.json`: settings, towers, profile, progress, codex), `SettingsMgr` (applies audio buses, window, game speed), `AudioMgr` (music crossfade, SFX pool), `SceneFlow` (Boot → Welcome/MainMenu → LevelSelect/Camp → Loading → Level), `KeyBinds` (InputBindings: rebindable actions, two slots + modifiers, `{key:Id}` text) | `game/app/` | shell agent |
| UI theme: a Godot `Theme` built from the kit (StyleBoxTexture 9-slices, fonts, colours as named constants = the tokens), reusable controls: TdButton (styles Primary/Secondary/Danger/Icon/Ability/EndTurn/NamePlate, hover/press/denied shake/attention pulse), tooltip (+stack), icon chip with badges (status time/stacks), health bar, dialogue box, text bubble, panel transition | `game/ui/theme/`, `game/ui/elements/` | ui-kit agent |
| Menus: Welcome (name, Start/Skip tutorial), Main menu (Continue/Play/Codex/Settings/Credits/Quit, greeting, scrolling list), Settings (Audio/Display/Gameplay/Controls with key capture), Pause, Credits, Loading screen (tip + bar), Codex (tabs, rows ???/new dot, page with stat tiles, abilities, model preview turning), Level select (chapter headings, detail with minimap, hand strip), Hand editor, Camp (stations + tour), Chapter select, End screen | `game/ui/screens/` | menus agent |
| Board: `BoardView` (tiles from TileLook → map kit meshes; frame/border; build decals), `EntityView` (FBX instance, clip contract, flash, face, Muzzle), `BoardCamera` (pan/zoom/rotate 90°, follow), overlay layers in a CanvasLayer following 3D positions: plates (HP bar + status chips, hover rule), markers/decals (range, aim, routes, previews: intents, stop decals, damage stripes), floaters (numbers, words), banners (round/phase/wave) | `game/board/` | board agent |
| Level: `LevelController` (same public API as the Unity one — see `~/game/Assets/Scripts/Gameplay/LevelController.cs` — owns session, FrameRecorder, Director, presenters, input: select/placing/aim/quick cast/route, Skip/End round, sequences, codex recording, result recording, next level), presenters per event type (`game/level/presenters/`), VFX kit, sounds | `game/level/` | board agent (controller + presenters) |
| HUD: top bar (round/phase/energy/base HP/waves, Skip, End turn with attention, Pause), hand tray (pieces: cost, key, placed plinth + medallion + HP + pips), inspector card (selection/placing: portrait, stats tiles, abilities read-only for enemies, statuses, Next line, Sell), action bar (ability buttons: clock ring, badge, key, aiming/held/cooldown states, hover range preview), hint line, sequence bubble/dialogue, info popups | `game/ui/hud/` | hud agent |

All of these read the `ViewFrame` (`Director.shown`) for what is drawn, never `GameState`, and call `LevelController` commands.

## Scene and part rules
- **One owner script per screen scene.** Every `game/ui/screens/<name>.tscn` is a single root node with its script
  (`<name>.gd`); the script builds the tree.
- **Built in code from the kit.** Screens build their nodes in code with the `TdMenu` helpers (`game/ui/screens/parts/td_menu.gd`:
  labels, panels, backgrounds, buttons) and the kit widgets, not hand-laid `.tscn` layouts.
- **Shared pieces live in one place.** Pieces several screens use are `Td*` parts in `game/ui/screens/parts/`
  (`TdCollection`, `TdTowerCard`, `TdStationWorld`, `TdLevelPreview`…); kit widgets (buttons, tooltips, chips, bars,
  dialogue box) are in `game/ui/elements/`. A screen reuses them instead of keeping its own copy.
- **Logic out of scene scripts.** Texts, states and rules a screen shows are static functions in `*_logic.gd` classes
  (`MenuLogic`, `HandLogic`, `WorkshopLogic`, `MissionUiLogic`), tested without a scene (`tests/test_menu_logic.gd`,
  `test_hand_editor_logic.gd`, `test_workshop_ui.gd`, `test_mission_ui.gd`).
- **HUD pieces under `game/ui/hud/`.** The level's HUD (`Hud` and its `Hud*` parts) lives there, not in the screens.
- **Popups:** menu windows extend `TdPopup` (`game/ui/screens/parts/td_popup.gd`: Codex, Settings, hand editor, Workshop,
  the co-op popups…); the HUD's windows (pause, info, end screen) extend `HudPopup`.

## Conventions
- Scenes as `.tscn` built in code where that is simpler (`_ready()` building the tree is fine; keep `.tscn` for layout-heavy screens).
- Resolution: 1920×1080 reference, `canvas_items` stretch, min 1280×720 (check both; the Unity rule: nothing under 18 px text).
- Keys: never hard-code; read `KeyBinds` actions (`EndRound`, `Skip`, `Pause`, `Ability1..9`, modifiers `Aim`/`QuickCast`/`Hand`, camera).
  Defaults: abilities 1–9 (Shift+N quick cast, Ctrl+N hand piece), End round Enter (also Shift+Space), Space skip/continue,
  P/Esc pause (Esc first cancels aiming/placing), right click cancel/deselect, camera WASD/arrows + Q/E rotate, wheel zoom.
- Time: game speed = `Engine.time_scale`; UI motion uses unscaled time (`Tween.set_ignore_time_scale(true)`... or process with `delta / Engine.time_scale`).
- Player-facing text from the assets' `display_name`/`description`, never ids. Turkish characters must render (fonts include them).
- Web export must keep working (`~/godot/export.sh projects/td --publish`): single-threaded, GL Compatibility, no plugins.
