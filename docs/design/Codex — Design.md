# Codex — Design

Started and built 2026-10-05. Godot pass 2026-10-15. In the game: the main menu's, the Camp's and the pause menu's Codex button (`game/ui/screens/codex.gd`).

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
- **List** on the left: one row per entry (icon, name, the new dot), in the Codex entry's order; locked rows show **???** and a lock icon.
- **Page** on the right: the model preview (or the icon), name, a subtitle (Tower · cost, Enemy, Enemy · Boss, Status · Harmful/Helpful, Tip), and the text:
  - towers and enemies: description; HP, Power, Speed; each ability as its tooltip shows it (range, area, power, cooldown); visible passives;
  - statuses: description (as one stack), how long it lasts, what happens when it is applied again;
  - tips: the text, with keys as the player bound them (`{key:Id}`, `{click:Id}`).
- A locked entry's page says how to discover it.
- Back (or Esc) closes it.

## Data

- The Codex entry `Settings/Codex` in `data/content/Codex.json` (`CodexAsset`, referenced by the catalog's `codex`): ordered lists of towers, enemies and statuses, and the tips (`id`, `title`, `text`, optional `image`). Its order is the Codex's order; it was filled by the Unity project's Fill Codex tool and is now edited as content:
  - towers: the catalog's tower types;
  - enemies: in the order the game meets them (the tutorial, then each chapter's levels), then any other enemy (`Unit/Enemy/…`);
  - statuses: every status (`Status/…`) that is not Hidden;
  - the built-in tips (rounds, placing, cooldowns, walking, quick cast, statuses, taunt, bosses, losing, the camera, keys).
- The save's `codex` (`CodexProgress`, `sim/meta/codex_progress.gd`): `discovered` and `viewed` keys ("Enemies:slime"). The level records enemies and statuses as they appear (after their arrival has played). Opening the Codex catches up with what the save already proves (`codex.gd` `catch_up()`): every tower type owned and the enemies of every level played (saves older than the Codex).

## In the Godot build

| Part | Where |
| --- | --- |
| Progress | `CodexProgress` in `sim/meta/` (tests: `tests/test_codex.gd`) |
| Contents | `CodexAsset` (`sim/data/`), the catalog's `codex`, `data/content/Codex.json` |
| Discovery | `LevelController._discover_for_codex` (`game/level/level_controller.gd`) |
| Panel | `game/ui/screens/codex.gd` + `codex.tscn` (a `TdPopup`, opened from the main menu, the Camp and the pause menu: `open()`, `close()`, `closed`, `open_at(section, id)`), `TdModelPreview` (`game/ui/screens/parts/td_model_preview.gd`: the turning model in its own SubViewport world with its own lights, on unscaled time, drag to turn) |

- The panel builds its tree in code from the kit (`TdMenu`, `TdButton`): tabs with icons, the "5 / 9 discovered" progress with a bar, the list (medallion, name, "• New") and the page on paper with stat tiles and ability / passive rows. Locked rows show a lock and "Not met yet" instead of **???**.
- Tower and enemy pages have page tabs: Overview · Abilities · Forms · Immunities (Immunities disabled; Forms disabled on enemies; docs/GODOT-NOTES.md "Workshop screens").
- The model plays its Idle clip and sways around a three-quarter front view instead of turning all the way round; a drag turns it freely. It moves over the paused game too.

## Adding to it

- **New tower, enemy or status:** add the content entry as usual, then add its key to the Codex entry's `towers`, `enemies` or `statuses` list in `data/content/Codex.json`, in the place it should be listed.
- **A tip:** add it to the Codex entry's `tips` (unique `id`, title, text; an optional image). `{key:EndRound}` shows the player's key for that action, `{click:QuickCast}` "Shift-click" or whatever the quick-cast modifier is (`KeyBinds.fill_keys`).
- **Something new to discover** (e.g. items): add a `CodexSection`, a list on `CodexAsset` (and its field in `ContentSerializer.SCHEMA`), its discovery where it appears, and a case in `codex.gd`.
- Then `tools/game_reference.gd` (or the TD Tools dock's Reference tab): [reference/Codex.md](../reference/Codex.md) lists the entries in order and every tip's full text.

History: the Unity build had the panel as a prefab (`Prefabs/UI/Codex/`, `UI_Codex` with Inspector references for its tabs, list rows and page) placed in the main menu and the GameScene, the model preview as a stage far from the board rendering into a RawImage, and `Tools > Content > Fill Codex` to add missing entries while keeping the order and hand edits.

## Open questions

- Where an enemy appears (which levels) and which abilities apply a status.
- Showing a tower's upgrades, once upgrades exist.
- Unlocking tips one by one as the player meets them.
