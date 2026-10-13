# Codex — Design

Started and built 2026-10-05. In the game: the main menu's and the pause menu's Codex button.

The **Codex** is the game's reference book: every tower, enemy and status the player has met, and short tips on how to play. It fills up as the player plays, like a collection.

## Decisions

| Topic | Decision |
| --- | --- |
| Name | Codex |
| Sections | Towers, Enemies, Statuses, Tips (one tab each) |
| What shows | Discovered entries only; the rest are listed as **???** (no spoilers, a collection feel). Tips are always shown |
| Discovered when | Towers: owned at least once. Enemies: on the board in a level. Statuses: on any unit in a level (hidden statuses never) |
| New | A discovered entry has a dot until the player opens it |
| Opened from | The main menu and the pause menu (over the paused level) |
| Towers and enemies | A 3D preview of the model, turning slowly (drag to turn it), next to the stats, abilities, passives and description |
| Statuses and tips | The icon or picture next to the text |
| Content numbers | Not shown (players never see the hidden content numbers) |

## Layout

- **Tabs** along the top: Towers, Enemies, Statuses, Tips, and a progress line ("5 / 9 discovered").
- **List** on the left: one row per entry (icon, name, the new dot), in the Codex asset's order; locked rows show **???** and a lock icon.
- **Page** on the right: the model preview (or the icon), name, a subtitle (Tower · cost, Enemy, Enemy · Boss, Status · Harmful/Helpful, Tip), and the text:
  - towers and enemies: description; HP, Power, Speed; each ability as its tooltip shows it (range, area, power, cooldown); visible passives;
  - statuses: description (as one stack), how long it lasts, what happens when it is applied again;
  - tips: the text, with keys as the player bound them (`{key:Id}`, `{click:Id}`).
- A locked entry's page says how to discover it.
- Back (or Esc) closes it.

## Data

- `CodexAsset` (`Data/Settings/Codex`, referenced by the game catalog's `codex`): ordered lists of towers, enemies and statuses, and the tips (id, title, text, optional picture). `Tools > Content > Fill Codex` makes it and adds what is missing, keeping the order and hand edits:
  - towers: the catalog's tower types;
  - enemies: in the order the game meets them (the tutorial, then each chapter's levels), then any other enemy in `Data/Units/Enemies`;
  - statuses: every status in `Data/Statuses` that is not Hidden;
  - the built-in tips (rounds, placing, cooldowns, walking, quick cast, statuses, taunt, bosses, losing, the camera, keys).
- The save's `codex` (`CodexProgress`): `discovered` and `viewed` keys ("Enemies:slime"). The level records enemies and statuses as they appear (after their arrival has played). Opening the Codex catches up with what the save already proves: every tower type owned and the enemies of every level played (saves older than the Codex).

## Build

| Part | Where |
| --- | --- |
| Progress | `Game.Meta.CodexProgress` (tests: `CodexTests`) |
| Contents | `Game.Data.CodexAsset`, `GameCatalogAsset.codex`, `Editor/Game/CodexBuilder` (Fill Codex) |
| Discovery | `LevelController.DiscoverForCodex` |
| Panel | `Scripts/UI/Codex/UI_Codex` (Popup), `CodexModelPreview` (the turning model: its own camera and light on a stage far from the board, rendering into a RawImage, on unscaled time) |
| Prefabs | `Prefabs/UI/Codex/` (the panel and its row), placed in the main menu and the GameScene |

## The panel in the scene

`Prefabs/UI/Codex/Codex` (`UI_Codex`, a Popup panel registered as `Codex` in the MainMenuScene and the GameScene; `GameHudBuilder` places it after Settings). Its references (`ElementRequirements`):

| Reference | What it is |
| --- | --- |
| `TowersTab` `EnemiesTab` `StatusesTab` `TipsTab` (+ `…TabBg`) | The section tabs; the Bg images take the active / inactive colour |
| `Progress` | "5 / 9 discovered" (Tips: the count) |
| `EntryScroll` / `EntryList` | The list on the left; one `CodexEntryRow` per entry (Button on the root; `Icon`, `Label`, `New` dot, `Highlight` on the selected row) |
| `Picture` | Holds `Preview` (RawImage + `CodexModelPreview`) and `Icon` on top of each other; hidden when the page has no picture, so the text moves up |
| `Title`, `Subtitle`, `BodyScroll` / `Body` | The page; Body is rich text (coloured ability headers, rows) |
| `BackButton` | Closes it (Esc too) |

Inspector: `rules` (the Game Rules asset, for stat names), `entryRowPrefab`, tab colours, `lockedName` ("???") and `lockedIcon` (`Art/Icons/questionmark`, a placeholder).

The model preview's stage stands at (10000, 0, 10000): its own camera (clipped to the stage, transparent background) and a point light; the model turns at 25°/s on unscaled time, so it also turns over the paused game. Game scripts on the model are switched off; its Animator plays its default state.

## Adding to it

- **New tower, enemy or status:** make the asset as usual, then `Tools > Content > Fill Codex`; reorder the lists in `Data/Settings/Codex` by hand if needed (Fill Codex keeps the order).
- **A tip:** add it to the Codex asset's `tips` (unique `id`, title, text; an optional picture). `{key:EndRound}` shows the player's key for that action, `{click:QuickCast}` "Shift-click" or whatever the quick-cast modifier is. Built-in tips are added by Fill Codex only when their id is missing, so edited ones are kept.
- **Something new to discover** (e.g. items): add a `CodexSection`, a list on `CodexAsset`, its discovery where it appears, and a case in `UI_Codex`.
- Then `Tools > Docs > Export Game Reference`: [Reference/Codex.md](../Reference/Codex.md) lists the entries in order and every tip's full text.

## Open questions

- Where an enemy appears (which levels) and which abilities apply a status.
- Showing a tower's upgrades, once upgrades exist.
- Unlocking tips one by one as the player meets them.
