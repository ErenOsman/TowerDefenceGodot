# Handoff — 2026-10-03 (updated after phase 5)

> **Historical snapshot of the Unity project, out of date.** Paths, plans and "next steps" here are from 2026-10-03; the Unity build stopped on 2026-10-15 and the Godot build is the game. For where things stand now, start at the Godot repo's `README.md` and `docs/GODOT-NOTES.md`; the Unity changelog is `docs/archive/Changelog (Unity, to 2026-10-15).md`. Godot pass 2026-10-15: this header only.

Where the work stands, for the next session. Read this, then `CLAUDE.md`'s files, then `git log --oneline | head -20`.

## The project in one paragraph

A turn-based grid tower defense (Unity 6.3 LTS, 6000.3.25f1), built on the TemplateProject framework. Every action is an ability. The game rules are an engine-free simulation in `Assets/Scripts/Game/` (Formulas, Combat, Level, Meta, Presentation, Data asmdefs); the scene layer is `Assets/Scripts/Gameplay/`. Design docs: `Assets/Docs/Design/` (Game Overview first) and the claude.ai doc **Animation & Presentation — Design** (https://claude.ai/artifact/XXaVRu1PHLkjzNdrLsvcx3). Code-vs-design differences: `Assets/Docs/Combat — Implementation Notes.md`. File map: `Assets/.agents/MAPPING.md`.

## Done

- Simulation: formulas, conditions, effect queue, entities, statuses (Hidden/Permanent/PerSource, cleanse), Ray and Single patterns, movement (Steps/PathAhead, pointer routes), level session (player → enemy → level phase, waves, energy, hand, place/sell), owned towers with GUID IDs in `GameData.towers`.
- Editor tools: Level Playtester (plays a level without a scene), Persistent Data Viewer (towers and hand), Validate All, Create Example Assets, Set Up Game Scene (all under `Tools > Combat`).
- Presentation phases 1–3 of the Animation & Presentation design:
  1. Events grouped into actions and beats.
  2. `Director` + view frames (engine-free, tested).
  3. GameScene with placeholder visuals and a temporary IMGUI control panel — **played through via Unity MCP on 2026-10-03**: placing, End Round, enemy walk, archer shot, damage number, death all work; camera fits any window; background camera; banners centred.
- Unity upgraded 2020.3 → 6.3 LTS; Unity MCP connected (`.mcp.json`).
  4. HUD and controls (2026-10-03): `UI_LevelHud` (round/phase, energy, waves, hint, Skip, End round, Pause — speed/Instant/Follow moved to Settings only), `UI_HandBar`, `UI_AbilityBar` (stats, abilities, Sell), `UI_EndScreen` (Retry, Level select → `SceneID.LevelSelect` = main menu for now), tooltips; `BoardCamera`; `followAction` / `instantPlayback` settings (toggles in the Settings Gameplay page); `GameSounds` sound set; `id` / `displayName` / `description` / `icon` on assets. Built by `Tools > Combat > Set Up Game Scene` (`GameHudBuilder`). **Played via MCP** (commands sent through the session and controller API, buttons via SimulateClick): placing, aiming highlights, ability bar, a won and a lost level with the end screen, Retry, Level select, the Follow setting from Settings into the game.

  5. Hooks for real art (2026-10-03): `EntityAsset.view` model prefabs, `EntityAnimatorBridge` (the Animator contract), `AnimatePresenter` (clips with Impact timing), `AbilityPresentationAsset` (caster trigger, projectile, VFX, sounds, camera shake), status icons on the HP plates and status loop VFX. `Tools > Combat > Create Example Model` builds a contract-following slime and Shoot/Ram presentations. **Checked via MCP:** the base's damage beat started when the slime's Attack clip was at normalizedTime 0.45 (Impact event at 0.44); Hit and Die clips played; the corpse kept the Die pose; the arrow projectile and hit spark played; a status icon with stacks and a loop VFX appeared.

  6. Level UI from the UntitledGame prefabs (2026-10-03): `Prefabs/UI/Level/` copied with their GUIDs, new scripts with the old class names and script GUIDs (so components reattach), prefabs restructured to Root → Content with named references, Speed button removed, missing pieces added (round/phase text, hint line, plate name, status stack count). The overlay draws plates, floating text and status icons from the prefabs. Upgrade prefabs kept as placeholders (button hidden). **Checked via MCP:** tower bar, enemy bar, Enemy Info popup, hand cards, plates, a won level with the end screen; no console errors.

  7. Fixes (2026-10-03): hover range no longer sticks after a right-click; spawns face along their path or a set direction (`SpawnFacing`); Face step modes TowardAim / Direction / AlongPath (needs `facingEnabled`); the level UI's buttons, hand cards and ability rows are `UI_Button`s with selected / placed / disabled looks; first states snap and End Turn follows the shown phase, so nothing blinks while things play.

  8. Entity plates are `UI_EntityStatus` (2026-10-03): `Prefabs/UI/Level/Other/EntityStatus` (name, `UI_HealthBar` with ghost fill and colour gradient, `UI_IconBar` of statuses with stack labels) replaces EnemyHealthBar / TempStatusIcon. The overlay only tells a plate about changes (HP, name, statuses). **Checked via MCP:** HP 13/20 bar, a status with 2 stacks shown above the name.

  11. Passives in the UI (2026-10-03): `PassiveAsset` has displayName / description / icon / `hidden`; the view frame carries visible passives with on/off (`PassiveView`). Right bars list them under the abilities as purple, non-clickable rows (tooltip, dimmed while off); info popups have a Passives section. Example: the Archer's **Counter-attack** (adjacent attacker takes 5, once per turn, while at half HP or more); Fire Tile Rules are hidden. Note: reactions are gathered when the hit is written, so the hit that drops it below half is still answered. **Checked via MCP:** an adjacent 12-damage hit was answered (slime 10 → 5), the passive then showed dimmed in the right bar and Info, tooltip text right; 97 engine-free tests pass.

  9. Plates and right bars (2026-10-03): over each entity a plate with the HP bar and status icons, no name; the HP bar shows only once damaged unless the new **Always Show Health** setting (`SettingsData.alwaysShowHealth`, default off). The right bars show the selected entity's `UI_EntityStatus` through an optional `Status` element. `EntityStatusBinder` drives both. Prefabs: a `Status` (EntityStatus instance) under each right bar's header, Settings Gameplay row `AlwaysShowHealthRow`. **Checked via MCP:** with the setting off, the full-HP base shows no plate, the damaged archer shows its bar with the status icon right above it, and the right bar shows the archer's bar and status.

  10. Level select hooked into the level (2026-10-03, with the level-select session): the GameScene takes the level and the saved hand from level select (else its Inspector level and test hand), saves the result once when the level ends (quit when left through the pause menu), Retry keeps the launched level, the end screen has Next level, and the pause menu's Main Menu reads "Level select" in a level. **Checked via MCP:** Boot → Main menu → Play → level select → Play reaches the level with the saved hand; a forced win saved attempts/wins/base HP/rounds; Next level hidden (one level in the catalog). Note: Player Settings' Product Name is still TemplateProject, so this project shares `gamedata.json` with the TemplateProject.

## Not verified yet (needs a person at the keyboard)

- Camera input (WASD, edges, middle-drag, wheel, Q/E) and Follow's glide: MCP cannot send key or mouse input.
- Clicking tiles to place and aim (the same code as phase 3, now behind the HUD), and tooltips on hover.
- `GameSounds`: no audio clips in the project yet, so nothing has been heard.

## Next

- The Animation & Presentation build plan is complete. Next is real content: models and clips per entity (follow the contract in `EntityAnimatorBridge`), icons, sounds, more levels.
- Not covered by tests: the Unity-side presenters (`AnimatePresenter`, overlay icons) live in Assembly-CSharp, which Edit Mode test asmdefs cannot reference; they were checked live only.
- Level UI layout: the old scene overrode much of the Level prefab's layout; the prefab now has a simple layout (top 60, bottom 120, right bars 300 wide between them). Restyle in the prefabs.
- Pause: the user's `Prefabs/UI/Pause/Pause` prefab is wired (references, Popup, restores the game speed on resume) and placed in the GameScene as panel `Pause`. Settings is a prefab now (`Prefabs/UI/Settings/Settings`), used by MainMenuScene and, centred over the pause menu, by the GameScene; changing game speed there keeps the game paused and applies on Continue.
- Small gaps: the hand comes from the LevelController's test hand, not the saved hand; HUD layout is placeholder (restyle through the HudButton prefab and `GameHudBuilder`).

## Working with Unity

- Unity MCP tools (enabled in Project Settings → AI → Unity MCP): Console, RunCommand (C#: `internal class CommandScript : IRunCommand`), editor/scene/GameObject/menu tools. RunCommand refuses `System.Reflection` and file deletion; use public members (`LevelController.Session`, `.Director`).
- Screenshots of the Game view: RunCommand `ScreenCapture.CaptureScreenshot("Temp/claude_game.png")`, read the PNG a moment later. `Unity_Camera_Capture` failed in Play Mode.
- After a recompile or leaving Play Mode the relay may report "Unity not detected" for ~30 s.
- Engine-free tests also run outside Unity (csc + NUnit runner, 80 tests passing at handoff; a matching script compiles Assembly-CSharp and -Editor — it needs `-define:UNITY_EDITOR`, `-langversion:8` and an error filter on `error CS`, or it passes silently); Edit Mode tests in Unity: Test Runner, or a test tool if enabled.

## Conventions to keep

- Replies in English (the user may write Turkish); no praise; honest assessments.
- Commit after each finished piece (`Co-Authored-By` line at the end of messages); never leave work uncommitted between phases.
- Keep `MAPPING.md`, `CONTEXT.md` and the Implementation Notes up to date (Rules 3 and 6).
- Unity 6 gotcha: files importing both `UnityEngine` and `Game.Combat` need `using EntityId = Game.Combat.EntityId;`.
