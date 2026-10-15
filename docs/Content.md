# Content — `data/content/` is the source of truth

Since 2026-10-15 (docs/Decisions.md, "Project and tools") the Godot build is the game. Its content lives only in
`data/content/*.json` in this repo. The Unity repo (`~/game`, ErenOsman/TowerDefenceProject) is frozen and read-only;
its `Content/` is no longer synced. The Godot-only overlay (`data/content-godot/`: Workshop forms and tokens,
missions, the short tutorial map, the catalog's Guild fields, the rules' tower energy) was merged into `data/content/`
the same day and deleted. `tools/sync_from_unity.sh` was deleted as well.

The one exception is the golden check: `~/godot/oracle/content/` is a frozen snapshot of the Unity content that the C#
oracle and `tools/golden.gd` play (see docs/Implementation Notes.md, "Golden"). Never edit it to follow game changes.

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
The key folder names the type and is **singular**; the file names stay plural (Decisions 2026-10-15). Sub-folders
that group entries are singular too (`Unit/Enemy/`, `Ability/Example/`); free-form ones stay as they are
(`Level/Chapter 1/`, `Unit/Other/`). The table is `ContentFiles.KEY_FOLDERS` (+ `PLURAL_SUBFOLDERS`, the sub-folder
names that must not come back); `tests/test_content_keys.gd` enforces it and that every reference resolves, and the
content check refuses a candidate key outside its folder.

| Type | File | Key folder | Example | Unity key (frozen, before 2026-10-15) |
| --- | --- | --- | --- | --- |
| StatusAsset | `Statuses.json` | `Status/` | `Status/Burn` | `Statuses/Burn` |
| ReactionAsset | `Reactions.json` | `Reaction/` | `Reaction/Burn Tick` | `Reactions/Burn Tick` |
| AbilityAsset | `Abilities.json` | `Ability/` | `Ability/Shoot`, `Ability/Example/Walk` | `Abilities/Shoot`, `Abilities/Examples/Walk` |
| PassiveAsset | `Passives.json` | `Passive/` | `Passive/Spiked Counter-attack` | `Passives/…` |
| EntityAsset | `Units.json` | `Unit/` (`Unit/Tower/`, `Unit/Tower/Form/`, `Unit/Enemy/`, `Unit/Base/`, `Unit/Other/`, `Unit/Other/Example/`) | `Unit/Enemy/Rabbit` | `Units/Enemies/Rabbit` |
| TowerAsset | `Towers.json` | `Tower/` | `Tower/Archer Tower` | `Towers/Archer Tower` |
| LevelAsset | `Levels.json` | `Level/` (`Level/Chapter 1/`, `Level/Tutorial/`, `Level/Other/`) | `Level/Chapter 1/1 First Steps` | `Levels/Chapter 1/1 First Steps` |
| TerrainAsset | `Terrains.json` | `Terrain/` | `Terrain/Ground` | `Terrains/Ground` |
| TileAsset | `Tiles.json` | `Tile/` | `Tile/Spawn Burrow` | `Tiles/Spawn Burrow` |
| FormAsset | `Forms.json` | `Form/` | `Form/Fire Archer` | (Godot overlay `Forms/…`) |
| TokenAsset | `Tokens.json` | `Token/` | `Token/Ember Core` | (Godot overlay `Tokens/…`) |
| MissionAsset | `Missions.json` | `Mission/` | `Mission/Patrol` | (Godot overlay `Missions/…`) |
| SequenceAsset | `Sequences.json` | `Sequence/` | `Sequence/Tutorial Steps` | `Sequences/Tutorial Steps` |
| AbilityPresentationAsset | `Presentations.json` | `Presentation/` (unchanged) | `Presentation/Shoot`, `Presentation/Example/…` | `Presentation/Shoot`, `Presentation/Examples/…` |
| GameRulesAsset, CodexAsset | `Rules.json`, `Codex.json` | `Settings/` (unchanged) | `Settings/GameRules`, `Settings/Codex` | same |
| GameCatalogAsset | `Catalog.json` | `Assets/Resources/GameCatalog.asset` (unchanged) | the one catalog | same |

Ids (`"id"`) are what saves, rules and the co-op protocol use, never keys, so the rename touched no save.

Art references (sprites, models, VFX, fonts, sounds) are strings in the canonical form below ("Art paths"). Never
change a shipped id.

## Art paths

Art fields (`"art"` in the schema: `icon`, `miniature`, `view`, `badge`, `projectile`, `castVfx`/`impactVfx`/`hitVfx`,
`loopVfx`, `spawnVfx`/`deathVfx`/`collisionVfx`, `*Sound`, `music`, `image`, and UITheme's sprite and font fields) hold a
**repo-relative path without `res://`**, so the content stays engine-neutral and readable; `null` for none.

| What | Canonical form | Example |
|---|---|---|
| unit / prop / projectile model | `art/models/<Name>.fbx` | `art/models/Archer.fbx`, `art/models/Arrow.fbx` |
| map-kit tile | `art/tiles/<Name>.fbx` | `art/tiles/Ground A.fbx` |
| icon (abilities, passives, statuses, units, miniatures) | `art/icons/<Group>/<Name>.png` (no `#Sub` suffix) | `art/icons/Units/Miniatures/Archer.png` |
| UI kit sprite (UITheme, form badges, token icons) | `art/ui/<path>.png`; the kit name is the file name | `art/ui/KitB/buttons/btn_primary_normal.png` |
| VFX kit effect | `vfx/<Effect name>` (a name in `game/level/vfx/effects.json`, not a file) | `vfx/Hit Spark` |
| font | `art/fonts/<file>` | `art/fonts/Nunito-Bold.ttf` |
| music | `art/music/<file>` | `art/music/battle.mp3` |
| sound | `art/sfx/<file>` | (none in the content yet) |

Camp/Guild props stay names (`Campfire` → `art/camp/Campfire.fbx`, layout.json) and portraits are found by unit name
(`art/portraits/<Name>.png`); neither is a content field. VFX are `vfx/<name>` because `VfxKit.effect_name` already
takes the last path part, so the kit needs no lookup table and the string says what it is.

`game/app/art_paths.gd` (ArtPaths) maps an art path to `res://`: the canonical form is `"res://" + path`. It still
reads the old Unity form (`Assets/Art/Icons/Units/Archer.png#Archer`, `Assets/Art/Models/Archer/Archer Blender.prefab`,
`Assets/Art/VFX/Kit/Hit Spark.prefab`, `Assets/Art/Fonts/Nunito-Bold SDF.asset`…) because the oracle's content copy
(`~/godot/oracle/content`, used by `tools/golden.gd`) keeps Unity paths; `tests/test_app_art.gd` asserts both forms
resolve to the same file. The one-time rewrite (2026-10-15) is `tools/content_art_paths.py` (it documents the mapping;
`--check` lists what it would change and paths that do not exist; run it on an old draft folder to migrate it).
The content check (`tools/content_check.gd`) warns (not an error) when a candidate's art path names no file / effect.
The Unity port maps these strings to its own assets (Addressables / a path table); they are not Unity asset paths.

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
