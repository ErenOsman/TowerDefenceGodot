# Content — `data/content/` is the source of truth

Since 2026-10-15 (docs/Decisions.md, "Project and tools") the Godot build is the game. Its content lives only in
`data/content/*.json` in this repo. The Unity repo (`~/game`, ErenOsman/TowerDefenceProject) is frozen and read-only;
its `Content/` is no longer synced. The Godot-only overlay (`data/content-godot/`: Workshop forms and tokens,
missions, the short tutorial map, the catalog's Guild fields, the rules' tower energy) was merged into `data/content/`
the same day and deleted. `tools/sync_from_unity.sh` was deleted as well.

The one exception is the golden check: `~/godot/oracle/content/` is a frozen snapshot of the Unity content that the C#
oracle and `tools/golden.gd` play (see docs/GODOT-NOTES.md, "Golden"). Never edit it to follow game changes.

## The files

One file per asset type, `{"type": "<AssetType>", "assets": {"<key>": {entry}, …}}`, entries in file order:

| File | Type | What |
| --- | --- | --- |
| `Abilities.json` | AbilityAsset | abilities (towers', enemies', forms') |
| `Catalog.json` | GameCatalogAsset | the one catalog: chapters and levels, tower types, starting towers, tutorial, camp and Guild unlock, the mission board |
| `Codex.json` | CodexAsset | what the Codex lists |
| `Forms.json` | FormAsset | Workshop tower forms |
| `Levels.json` | LevelAsset | levels (maps, waves, energy, hand) |
| `Missions.json` | MissionAsset | Guild missions |
| `Passives.json` | PassiveAsset | passives |
| `Presentations.json` | AbilityPresentationAsset | ability presentation (projectile, VFX, sounds) |
| `Reactions.json` | ReactionAsset | reactions |
| `Rules.json` | GameRulesAsset | the one rules asset (stats, formulas, relations, tower energy per day) |
| `Sequences.json` | SequenceAsset | dialogue / intro sequences |
| `Statuses.json` | StatusAsset | statuses |
| `Terrains.json` | TerrainAsset | terrain kinds |
| `Tiles.json` | TileAsset | map-kit tiles |
| `Tokens.json` | TokenAsset | Workshop token kinds |
| `Towers.json` | TowerAsset | tower types |
| `Units.json` | EntityAsset | units: towers, form units, enemies, bases, objects |
| `PresentationTimings.json`, `UITheme.json` | (presentation) | not content assets; read by the presentation layer |

The type → file table is `ContentFiles.FILES` (`sim/data/content_files.gd`); the fields of each type, in order, are
`ContentSerializer.SCHEMA` (`sim/data/content_serializer.gd`; `tools/content_check.gd -- --schema` prints it as JSON).
`ContentHash` (the co-op version) hashes every `data/content/*.json`, so any content change makes a new co-op version.

## Keys

An entry's key is `<folder>/<path>/<name>`; the asset's name is the last part. References between entries are keys.
The folder names the type (file names stay plural):

| Type | Key folder | Example |
| --- | --- | --- |
| StatusAsset | `Statuses/` | `Statuses/Burn` |
| ReactionAsset | `Reactions/` | `Reactions/Burn Tick` |
| AbilityAsset | `Abilities/` | `Abilities/Shoot` |
| PassiveAsset | `Passives/` | `Passives/Spiked Counter-attack` |
| EntityAsset | `Units/` (`Units/Towers/`, `Units/Towers/Forms/`, `Units/Enemies/`, `Units/Bases/`, …) | `Units/Enemies/Rabbit` |
| TowerAsset | `Towers/` | `Towers/Archer Tower` |
| LevelAsset | `Levels/` | `Levels/Chapter 1/1 First Steps` |
| TerrainAsset | `Terrains/` | `Terrains/Ground` |
| TileAsset | `Tiles/` | `Tiles/Spawn Burrow` |
| FormAsset | `Forms/` | `Forms/Fire Archer` |
| TokenAsset | `Tokens/` | `Tokens/Ember Core` |
| MissionAsset | `Missions/` | `Missions/Patrol` |
| SequenceAsset | `Sequences/` | `Sequences/Tutorial Steps` |
| AbilityPresentationAsset | `Presentation/` | `Presentation/Shoot` |
| GameRulesAsset, CodexAsset | `Settings/` | `Settings/GameRules`, `Settings/Codex` |
| GameCatalogAsset | `Assets/Resources/GameCatalog.asset` | (the one catalog) |

Art references (sprites, models, sounds) are Unity-style asset paths kept as strings (`Assets/Art/Icons/Units/Archer.png#Archer`);
`game/` maps them to `res://art/…`. Ids (`"id"`) are what saves and rules use: never change a shipped id.

## Layout

Files keep the layout Unity's writer gave them (two-space indent, small objects and short lists on one line, UTF-8,
one final newline), so a change is a small diff. `tools/content_format.py` writes that layout (Python, standard library):
`python3 tools/content_format.py --check` lists files that are off, without `--check` it reformats them; tools that
write content import it (`content_format.save(path, data)`).

## Who writes it

- **By hand / agents**: edit the JSON, keep the layout (`tools/content_format.py`), then `./check.sh`, `./test.sh`
  (`tests/test_content_all.gd` loads, validates and round-trips every entry) and, for play changes, `tools/soak.gd`.
  After changing `Missions.json` regenerate `data/coop.json` (`godot --headless --path . -s tools/coop_json.gd`; the relay
  reads it; `test_missions` fails while they disagree).
- **The wiki's Content Editor** (`/admin` → Content Editor; `~/wiki/server/content_bridge.py`): "Check" writes the edited
  entries as a candidate folder (`<File>.json` files, same shape) and runs `jobs.sh content_check <dir> [level]`
  (`tools/content_check.gd`): the candidates are merged over `data/content` in memory (`ContentLibrary.load_game(dir)`,
  same key → the candidate wins), validated and probed; nothing is written. "Try in Godot" / apply merges the checked
  entries into `data/content/<File>.json` by key (a new key is appended, an existing key is replaced in place; backup
  first), in the layout above, then commits; Remove takes a key out of the file (there is no lower layer to fall back to
  any more). An empty candidate folder checks the content alone. The bridge must not write `~/game`.
- **The TD Tools dock** (editor plugin): Validate tab = Validate All on `data/content`; save actions run on it.

## Checks

- `tests/test_content_all.gd`: every file loads without problems, Validate All, every entry round-trips through the
  serializer.
- `tools/content_check.gd -- <empty dir>`: ok on the content alone.
- `tools/golden.gd`: the sim against the C# oracle logs on the frozen snapshot (not on `data/content`).
