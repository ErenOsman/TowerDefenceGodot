# Upgrade screens (2026-10-16) — to merge into Implementation Notes

**Source of truth: `docs/design/Upgrades — Design.md`**; UI/UX mockups `screens-b/upgrade*.html`, `lv-chip.html`,
`end-screen-tasks.html`. Data layer: Implementation Notes § "Upgrades & Blacksmith data".

- `UpgradeScreen` (`game/ui/screens/upgrade.gd/.tscn`, a TdPopup modelled on the Workshop): picker → view slide
  (0.35 s). Open with `open_popup("upgrade")` in the Blacksmith (or `UpgradeScreen.show_over(parent)`).
  - Picker: `TdCollection` with `filter_set = "upgrade"` (search + "Ready to upgrade" toggle; `filter.ready` keeps
    towers whose base **or an unlocked form** can be upgraded, count "5 ready"), `show_cost = false`, `ready_of`
    (green ↑, `TdLvChip.ready_mark`), Lv chips. Card: name, "tower N", Lv chip, "Level 3: 1 of 2 tasks done",
    "✓ Fire Archer is ready to upgrade", stat tiles, Upgrade.
  - View: left "This tower now" (medallion + badge + Lv chip, "Base form" / "Form of Archer", "Level 2 of 5", stats
    of `UpgradeLogic.levelled_type` = the ladder's form at its level, abilities); centre "Level N", task rows (✓ box
    when done, bar + "42 / 60 damage" for counted tasks, "Done" for one-offs), ONE primary "Upgrade to level N"
    (disabled = the kit's one Disabled look, with `TowerLevels.last_reason` under it; lock icon for the form cap);
    right "What level N gives" (green chips) + muted "Then: level N+1"; forms row (base + unlocked forms, "Lv 2 of 5",
    ↑ when that ladder is ready; click = show that ladder). Max level: "Max level", "Archer is at its highest
    level.", what each level gave; right "All levels reached".
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
  - Codex tower page: header medallion = the highest level among your towers of that type/form
    (`UpgradeLogic.best_level`); Overview facts gain "Levels" (`TowerLevels.level_summary` of the shown ladder).
- End screen: `HudEndScreen.task_block(controller.task_advances)` under the drops (mission rewards / token row):
  "Tasks", ≤ 4 rows (`UpgradeLogic.end_rows`: "**Archer** (tower 3): Defeat 10 enemies with it … 8 / 10 kills +3",
  done rows "✓ … Done"), "+N more tasks moved", a gold line per tower made ready. Shown on wins and losses alike
  (combat tasks count on a loss); nothing when no task moved.
- Renders: `tools/upgrade_shot.gd` → `/srv/wiki-art/godot/renders/upgrade/` (13 frames, own save).
- Not done: hand slots in the hand editor's strip carry no Lv chip; no QA tour step; the board plate's name line.
