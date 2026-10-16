# Upgrade screens (2026-10-16) — to merge into Implementation Notes

**Source of truth: `docs/design/Upgrades — Design.md`**; UI/UX mockups `screens-b/upgrade*.html`, `lv-chip.html`,
`end-screen-tasks.html`. Data layer: Implementation Notes § "Upgrades & Blacksmith data".

- `UpgradeScreen` (`game/ui/screens/upgrade.gd/.tscn`, a TdPopup modelled on the Workshop): picker → view slide
  (0.35 s). Open with `open_popup("upgrade")` in the Blacksmith (or `UpgradeScreen.show_over(parent)`).
  - Picker: `TdCollection` with `filter_set = "upgrade"` (search + "Ready to upgrade" toggle; `filter.ready` keeps
    towers that can be upgraded in their CURRENT form, count "5 ready"), `show_cost = false`, `ready_of`
    (green ↑, `TdLvChip.ready_mark`), Lv chips. Card: name, "tower N", Lv chip, "Level 3: 1 of 2 tasks done",
    "✓ Archer is ready to upgrade" (current form), stat tiles, Upgrade.
  - "N ready" / ready mark: `TowerLevels.is_ready` / `ready_count` now count each tower once, in its current form
    only (Eren 2026-10-16; sim/meta/tower_levels.gd + test_upgrades updated).
  - View (Eren 2026-10-16, replaces the first build's 3-column + forms row): works on the tower's CURRENT form only
    (`TowerLevels.current_ladder`; wearing Fire Archer = the Fire Archer ladder). Left "Now" card (medallion + badge
    + Lv chip, name, "Form of Archer" for a form only, no "Base form", no "Level N of M"; stats; abilities); centre
    "Level N", task rows (✓ box, bar + "42 / 60 damage" for counted tasks, "Done" for one-offs) and ONE "Upgrade to
    level N" — simply disabled while tasks are missing (no line: the bars say it); only the form cap gets a line,
    "Raise Archer to level 3 first" with a lock (`UpgradeLogic.action().note`); right "After upgrade": the same card
    at level + 1 (`UpgradeLogic.after_type` = `TowerLevels.apply` on a copy) with changed stat tiles outlined green
    and a "+5" badge on their corner (`UpgradeLogic.stat_diffs`). Max level: centre "Highest level" / "Archer is at
    its highest level.", right card empty.
  - Confirm: TdConfirm "Upgrade Archer to level 3?" / "It gives **+5 Max HP**. The next level's tasks start
    counting." → `GameApp.upgrade_tower` (saves) → gold beat "Archer reached level 3!" for 4 s over the next level.
  - Esc / right click: confirm → view → picker → close; Enter: picker Upgrade / view Upgrade / confirm.
- Texts and rules: `UpgradeLogic` (`parts/upgrade_logic.gd`, tests `tests/test_upgrade_ui.gd`).
- Lv chip `TdLvChip` (`parts/td_lv_chip.gd`): cream pill, Plinth 16, "Lv N"; `attach(portrait, level, d)` at the
  portrait's bottom-left; `make(level, size)` inline; `TdLvChip.shown()` = `GameApp.blacksmith_unlocked()`. Never
  takes the pointer (tiles call `hit_rect_only` again: hitboxes unchanged). Placed on:
  - collection tiles (hand editor, Workshop picker, Upgrade picker): `HandLogic.entries` gained `level` (the current
    form's level); `TdCollection` shows it when `TdLvChip.shown()` or `level_of` is set; `TdTowerTile.set_level`
    (a tired badge moves up a little when a chip is there);
  - tray pieces (miniature lower-left, placed medallion bottom-left): `HudHandPiece.set_level` from
    `TowerDef.type.level`;
  - HUD inspector: in the name row (`HudInspector._lv`), towers only;
  - board: the FULL plate (hovered / selected tower) gets the chip on the backing's top-right corner
    (`PlateLayer.level_of` ← `LevelController._plate_level`; the director's frames carry no `tower_id`, so it asks
    the session by entity id). The board plate still has no name line (the mockup's "Fire Archer Lv 3" plate).
  - Workshop Modify tree: every unlocked node (and the base) shows that ladder's Lv chip; the node's ✓ moves up to
    the medallion's left side when the chip is there.
  - Codex tower page: header medallion = the highest level among your towers of that type/form
    (`UpgradeLogic.best_level`); Overview facts gain "Levels" (`TowerLevels.level_summary` of the shown ladder).
- End screen: `HudEndScreen.task_block(controller.task_advances)` under the drops (mission rewards / token row):
  "Tasks", ≤ 4 rows (`UpgradeLogic.end_rows`: "**Archer** (tower 3): Defeat 10 enemies with it … 8 / 10 kills +3",
  done rows "✓ … Done"), "+N more tasks moved", a gold line per tower made ready. Shown on wins and losses alike
  (combat tasks count on a loss); nothing when no task moved.
- Renders: `tools/upgrade_shot.gd` → `/srv/wiki-art/godot/renders/upgrade/` (13 frames, own save).
- Not done: hand slots in the hand editor's strip carry no Lv chip; no QA tour step; the board plate's name line.
- `tools/upgrade_shot.gd -- <dir> view,view_ready,form_blocked,max` saves only those frames (numbering kept).
