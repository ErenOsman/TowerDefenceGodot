# Backpack — Design

Written 2026-10-16 by the Godot agent from Eren's decision of the same day ("wallet değil de, backpack yapılabilir,
currency'mizi etc görürüz"); the points he left open are decided here and marked **(agents)**.

The **Backpack** is where the player sees what they carry: **gold**, every **token** kind with its count, and later
anything else that is collected (items, keys). There is no separate "wallet": the word is not used in the game.
Screens that spend something (the Workshop's Modify view, the Upgrade view's Pay task) show the one amount they
need inline; the Backpack is the full list.

## Decisions

| Topic | Decision | Source |
| --- | --- | --- |
| What | A **Backpack** popup listing the player's currencies: gold first, then the tokens (icon, name, count, "Found in: …" from the mission drops as the Workshop derives it); empty kinds are not listed except gold (always shown, "0 gold") | Eren 2026-10-16 · agents (list rules) |
| Where | A small **Backpack** button (bag icon, the gold count beside it) at the top-right of the **Camp**, the **Guild** and the **Blacksmith**; also in the Workshop picker's and the Upgrade picker's header. Hidden before the Camp unlocks (nothing to carry yet) | agents |
| Opens | Over the place, as a TdPopup (Esc closes it); nothing else changes | agents |
| Future | Items and keys get sections under the currencies; the popup grows by sections, not by tabs | agents |
| Data | No new save data: `GameData.gold` and `GameData.tokens` are what it reads. The class `TokenWallet` keeps its name in code; the player never sees the word | agents |

## The popup

```text
┌ Backpack                                              ✕ ┐
│ ◉ 240 gold                                              │
│ ─────────────────────────────────────────────────────── │
│ Tokens                                                  │
│ (icon) Fire Arrow        ×2   Found in: Night Watch     │
│ (icon) Ember Core        ×1   Found in: The Glutton     │
│ (icon) Yew Bow           ×0   Found in: Drum Line       │   ← only when the kind was ever earned
└─────────────────────────────────────────────────────────┘
```

## Build plan

1. `game/ui/screens/backpack.gd/.tscn` (TdPopup) + `parts/td_backpack_button.gd` (the bag + gold count); placed in
   Camp, Guild, Blacksmith and the two pickers' headers.
2. Mockup (UI/UX agent): the button and the popup.
