# Blacksmith — Design

Written 2026-10-16 by the Godot agent from Eren's decisions of the same day; the points he left open are decided
here and marked **(agents)**. This doc is the source of truth for the **Blacksmith** place. What happens inside it
is specified elsewhere: Modify in Workshop — Design (forms and tokens), Upgrade in Upgrades — Design (levels
and tasks).

The **Blacksmith** is a place like the Guild: reached from the Camp by its own station button, which slides the
screen to the Blacksmith (Camp out to the left, Blacksmith in from the right; back the reverse). It opens when
Chapter 2 is cleared, together with the Guild. It holds **Modify** (the Workshop) and **Upgrade** (tower levels).

## Decisions

| Topic | Decision | Source |
| --- | --- | --- |
| A place | **Blacksmith** (scene `BlacksmithScene`, `SceneFlow.Blacksmith`), like the Guild: a diorama with a ring of stations, a welcome card on the first visit (`profile.blacksmith_seen`) | Eren 2026-10-16 ("modify'ı da guild gibi bir yere yapalım, blacksmith'e") |
| From the Camp | The Camp's **Workshop** station becomes the **Blacksmith** station (same spot, the anvil table prop), label "Blacksmith", sub-line "Modify and upgrade towers". Hidden until Chapter 2's last level is won (no greyed state), like the Guild; the first Camp visit after Chapter 2 points at Guild and Blacksmith once | Eren (after Chapter 2; hidden buttons rule of 2026-10-15) · agents |
| Transition | Pressing it slides the screen like the Guild (`SceneFlow.slide`); "← Camp" slides back | Eren (the slide sketch, 2026-10-15) · agents (same transition) |
| Stations | **Modify** (opens the Workshop picker → Modify view, exactly as the Workshop works today), **Upgrade** (the Upgrade picker → Upgrade view, Upgrades — Design), **Towers** (the hand editor), **Camp** (back). Nothing else for now | Eren (modify and upgrade) · agents (Towers, Camp) |
| Unlock | `GameCatalogAsset.blacksmithUnlock`: Chapter 2's last level, the same as `guildUnlock`, unless changed | agents |
| Art | A smithy diorama from the Blender agent in the Camp/Guild kit style: forge and anvil (Modify), a whetstone or workbench with a tower figure (Upgrade), a tower rack (Towers), the door (Camp); warm interior, embers. Placeholder until it lands: the Workshop's existing anvil table on a plain floor | agents |
| Buttons | Station buttons follow the shared placement rule (on the floor in front of the prop, else beside, else above), the layout from `art/blacksmith/layout.json` | UI/UX rule 2026-10-15 |

## Player flow

```text
Camp ──Blacksmith──▶ Blacksmith ──Modify──▶ Workshop picker → Modify view (Workshop — Design)
                          ├──Upgrade──▶ Upgrade picker → Upgrade view (Upgrades — Design)
                          ├──Towers──▶ Hand editor
                          └──Camp──▶ Camp (slide back)
```

The Workshop's own screens do not change: the Camp's Workshop station simply moves one level down, into the
Blacksmith. Before Chapter 2 nothing of this exists in the Camp.

## Data

- `GameCatalogAsset.blacksmithUnlock` (a level), `PlayerProfile.blacksmith_seen`.
- `art/blacksmith/layout.json` in the Camp/Guild layout schema (slots, centre, decor), editable with the F1 layout
  editor.

## Build plan

1. **Place** (Godot): `SceneFlow.Blacksmith`, the scene built on `TdStationWorld` like the Guild, the Camp's station
   button replacing the Workshop's (hidden before Chapter 2, slide), the welcome card, the tour lines.
2. **Art**: the smithy kit (Blender agent); mockups of the place and its welcome card (UI/UX agent).

## Open questions

- Whether the Blacksmith should also sell something for gold later (a shop station); not now. Gold itself would come
  from missions (Missions & Guild — Design).
