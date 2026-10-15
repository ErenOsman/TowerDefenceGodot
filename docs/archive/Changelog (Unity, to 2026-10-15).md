# Changelog

What changed in the game and its tools, day by day, newest first. Written for people: what a player, designer or developer would notice, not every commit. Git has the full history; the [decision log](Decisions.md) has the reasons.

When you finish a change worth noticing, add a line under today's date (create the heading if needed), in the matching group: **Added**, **Changed**, **Fixed** or **Removed**.

## 2026-10-11

### Added
- Drag with Mouse (Settings > Gameplay, on by default): hold the left button on the board and move to drag the map. A press that moves past a few pixels is a drag, not a click, so board clicks now act when the button comes up. The camera tip in the Codex says so.
- The Loading scene's background is the Spitters board blurred and dimmed on dark wood (`Art/UI/Backgrounds/Spitters Blurred.png`, by the Blender agent), filling the screen without stretching.
- Main menu and Welcome from Eren's mockups: the Spitters board render (`Art/UI/Backgrounds/Spitters.png`, Chapter 1 level 2, transparent, by the Blender agent) on the right of the main menu with an Archer, Guardian and Mage in front, and darkened behind the Welcome plaque with an Archer and a Guardian beside it; both logo slots read "Tower Defence" (Tools > UI > Restyle Menus).
- Tools > Build > Windows (dev build) and Windows (release): a development build into Builds/Windows/Test, or the next version into Builds/Windows/<version> with its zip and the version label set to it.

### Fixed
- On the right bar card, a status chip's time pill no longer runs into the HP bar: the status row sits lower (8 px of air over the pills), and the space under it is 9 px smaller (the stack pills hang into the card's spacing).
- The info popup's ability rows no longer draw a slot frame around the icon either (InfoAbilityRow had its own copy of the frame).
- Status rows in the info popup show the board's status chip, with its time and stack pills (the stack number was white text on paper).
- Dragging the map no longer sticks when the button is let go outside the window: a drag ends whenever its button is up or the window loses focus.
- Game Speed in Settings reads 1.00 on every machine (a Turkish locale showed 1,00).
- Attack preview lines draw over the models (they ran at mid-model height from centre to centre, so models hid them and a short target showed the end on its head) and run from the caster's tile edge to the target's.
- The ability button's "ready next turn" pulse showed a square: the glow in `cd_badge_soon.png` reached the image's edge; it now fades out before it.
- The Codex's "discovered" bar uses the board HP bar's thin frame and fill (sliced) and shows the share by its width; the stretched Filled mask looked broken.
- The main menu's version label shows the running build's version (it kept the one the menu was built with: 0.1 in the 0.6 build).
- The loading bar's bright edge no longer stays as a line at the end of a full bar.
- Ability rows in the info popup and the Codex no longer draw a slot frame around the icon (the icon art has its own tile).
- A Codex model opened from an info popup no longer looks stretched: the preview camera takes the frame's shape and a still re-renders when the frame changes size.
- Closing the Codex no longer drops the model before the panel fades out: the preview keeps its picture until the panel is gone (reopening shows the selected entry's model).
- Follow the action no longer pulls the camera back after the enemy phase: board-wide actions (every tower's turn start or end, phase banners, income, round end) are not followed.
- A dark line showed between a tooltip and its tail (the paper's transparent margin and rim): the tail now tucks into the box over that edge.
- Bats now appear in The Drummer's last wave (2-3, "From the Chasm"). Their path runs over the chasm, and a spawn looked for a tile a walker could stand on, so every bat fizzled with "no free tile". Spawns and resurrections now let flyers appear over a chasm.
- The Loading scene hung at 100%: it asked for the level while the load that opened it was still finishing, and that request was refused. It now waits for that load first.
- Ability rows on the right bar all read "Shoot": a button row's own "Name" text was skipped for the button's label (`ElementList.SetText`).
- A long name on the right bar ("Slime Archer") ran under the Info button: the button moves down, beside the "Tower" / "Enemy" line, and the name keeps its size.
- The hint line under the action bar jumped up while the bar faded out (it read as flicker): it now stays at one height at the bottom, 10 px above the screen's edge, with or without the bar.
- In a build the UI ran on a blank default theme (white Credits window, default fonts, dark menu buttons, disabled Camp buttons looking enabled): the theme was only found by the editor's asset search. A build now loads it through `Resources/UIThemeLink` (`UIThemeLink`).
- A unit's death could throw MissingReferenceException: the death effect read the unit's view after it had been removed.
- Status pills sat too far in, over the glyph: each now straddles its corner (time top-left, stacks bottom-right).
- When a level opened, the right bar and the action bar showed and then animated away: they now start hidden.
- After leaving a level through the pause menu, the next level's animations ran almost frozen (only Skip moved them on): the pause menu kept time at 0 while the scene changed, and the loader only lifted it to 0.01. The pause menu now stays on screen while leaving but stops holding time at 0, and every scene change restores the game speed setting (`SceneController.RestoreGameSpeed`).
- Floating texts ("-10", ability names, "Ready!", status names) drifted sideways toward the screen's edges: they rise straight up from the unit on screen now, as does the tutorial bubble's point over a tile. The preview "-10" over a unit sat high above a plate without statuses and was small: it sits right over the HP bar and is bigger (30).
- Board UI drew 1.23× too big at the default zoom once the camera centred on the whole width (the board is framed larger): the default tile size is now measured for each board when the level starts. Floating numbers measure the zoom on the ground like the plates (they were up to 11% bigger).
- The tutorial's last line couldn't be read: the end screen opened over it as soon as the level was won. The end screen now waits until the running dialogue is finished.
- A tutorial bubble pointing at a HUD element (End turn) ran off the screen's edge: it stays inside the screen again; only bubbles on units and tiles follow them off screen.
- The "-10" and "Kills" markers and the floating numbers didn't scale with the zoom. All UI over the board now follows one rule (`WorldUi`, written in UI Design Rules): it scales with the zoom where it stands, text never below its size.
- HP bars sat higher the further right a unit was on screen: their lift used the leaning length of the up direction on screen instead of its height. The tutorial bubble had the same error.

### Changed
- Scrolling with the mouse wheel stops the glide a drag left behind, in every scroll view (Codex, info panels, Settings, hand editor, level lists).
- Info window status rows no longer repeat the stack count under the name ("Status · ×3"): the chip's pill shows it. Tooltips keep it (the board's compact chips have no pills).
- The Priest's Mend no longer heals the base (towers only); its and the Priest's descriptions say so.
- Status chips sit still under the pointer everywhere (no hover bob, glow, shine or punch), on the right bar as on the board; only their tooltip answers (`UI_IconPro.SetPointerEffects`).
- HP bars sit a fixed 12 px (scaled with the zoom) over the body's highest point on screen (outline points kept once per model, projected each frame), on every row, board size and zoom: no more floating over towers or touching heads on big boards' bottom rows. The body is a model's invisible `Hitbox` child when it has one (hats, orbs and staffs then don't count), else the model. The per-tower plate offsets are back to 0.
- The Loading scene has its own panel script, `UI_Loading`; the Boot scene's `UI_BootLoading` is back to the plain boot screen (no title, tip, live bar or fade).
- The loading screen is a real one: the bar's first 80% reads the level, the rest fills while the level builds its board, models and HUD under the screen (it holds the screen until it has drawn once); then "Complete!" and the fade. Before, the level set itself up after the bar was full, during the fade.
- The Loading scene is quicker: it shows at least 0.3 s (was 1.5) and waits 0.1 s after the bar fills (was 0.5); the level then sets itself up under the fading screen.
- Tower and base HP bars sit a little lower: the automatic gap (0.55 tile) now starts at the head, below the thin tip a model ends in (feather, plume, hat point), through a plate offset on Archer, Drummer, Priest, Wisp, Guardian, Alchemist and the Base.
- Settings rows: names stay on one line, and a toggle sits at the right, where the sliders and dropdowns end.
- The Camp tour is spoken by the Princess (her name and portrait in the bubble), like the tutorial.
- The top bar's wave pips turn green once a wave is cleared (all its enemies spawned and dead); a running wave stays lit, a coming one off.
- The loading screen fades out over the next scene instead of cutting to it: it stays on top through the switch and fades once the level (or the menu) has set itself up.
- A dialogue line that waits for the game ("Goes on when the level is won") hides when clicked, so it stops covering the board; the sequence still goes on when the game gets there, and the next line shows again. Its hint reads "Click to hide. Goes on when …".
- Settings opens in the middle of the screen in the main menu too (it sat right of centre).
- The main menu and Welcome use the blurred Spitters board as a full-screen background (like the Loading scene) instead of the sharp render; the miniatures stay in front.
- The Boot screen's old "G" logo reads "Tower Defence" until there is a logo (the menu builder's Boot step).
- A Loading scene before every level (SceneID.Loading, index 6): "Tower Defence" over the bar (until there is a logo), a random tip from the Codex under it, and a livelier bar (a light sweeping along the fill, a breathing bright edge); the level loads behind it. The Boot scene's loading panel stays plain. Built by the menu builder's `Loading()` step.
- Main menu: Play is blue like Continue (the menu builder; rebuild the main menu to apply).
- HP bars sit a little higher over their units: 0.55 of a tile above the head (was 0.35, which the tilted camera made look like it touched the head).
- Every slime walks with Path Walk (the Slime Archer, Slime Glutton and Slime King had Brute Walk); the Slime Archer's description follows.
- Damage numbers over the board get a thicker dark outline and a soft drop shadow (`WorldText`): the first outline came out under a pixel.
- The Codex and Info model previews are dimmer, the key light most (×0.55; fill ×0.85, ambient ×0.9): it washed out the models' fronts.
- Damage numbers (floating and the preview "-10") have a dark outline, so they read over the board.
- The Drummer level: the Drummer starts facing down; only the base's column and the three beside it can be built on (the Drummer's tile included).
- A previewed attack shows the HP bar of everyone it hits, also when their HP doesn't drop (a shield takes it, or it does no damage).
- Compact plates' status chips sit 6 px lower, closer to the HP bar (they have no pills to clear).
- Hand tray: a tower not placed yet shows Blender's miniature render (new `EntityAsset.miniature`, set for the 9 towers and both bases; `Art/Icons/Units/Miniatures/`). Without one, its model is rendered as before. Fixed: a placed piece showed the old portrait ring under its medallion.
- Why an ability can't be cast ("On cooldown (1)") shows only in the line under the action bar: no longer in the ability's tooltip or a popup beside the button. A refused click also writes it there.
- Hovering an enemy's ability in the right bar no longer writes its coming turn under the action bar (the board already shows it).
- A selected unit with no abilities shows no action bar (it was an empty name box with "0 ready").
- A level starts with the board centred on the whole screen width, not beside the right bar, and the banners in the middle of the screen are centred on it too (they sat left of centre). The open right bar may cover the board's right edge.
- A placed tower and the bases face down the board, toward the camera (they faced up, their backs to the player).

## 2026-10-10

### Added
- Model pack 2026-10-10a: the eight slimes and the Skeleton remade; new Princess, Lich, Skeleton Fire Mage, Skeleton King, Skeleton Mage and Skeleton Spearman models (staged in `Art/Blender/` for Tools > Art > Import Blender Models). New slime portraits and the Princess portrait (`Art/Icons/Units/`), passive icons re-rendered.
- Status chips show their numbers as badges (NEWS 26–28): time left in a clock dial at the bottom-left, stacks (or a shield's points) at the bottom-right, centred on the chip's bottom edge; the glyph is never covered (`StatusChip`).
- Board plates: thin 152 × 8 HP bar, 32 px status chips 8 px apart, at most 4 (5+ show 3 chips and "+N"; hovering the plate lists every status in the tooltip boxes). Inspector card chips 40 px. The Princess portrait shows in the dialogue box.
- VFX kit (Fable agent, NEWS 29): its particle sprites are in `Art/VFX/Kit/Sprites/`, its README in `Docs/Notes/`. Cast effects of shots (Projectile, Lobbed) start at the muzzle; spawn, death and collision effects play from `PresentationTimings` (`spawnVfx`, `deathVfx`, `collisionVfx`). The kit's numbers are a data file (`Art/VFX/Kit/vfx-kit.json`, converted from its tables); the project's own tool builds and wires them (Tools > Art > VFX Kit, `VfxKitImport`), instead of the kit's scripts.
- Status loop effects scale with the unit's height (at least 0.6) and sit so their ground rings stay on the ground; Rooted's dirt motes no longer fall through the floor (the kit builds them around the middle of a unit about 0.8 tall), so ground rings stay on the ground and Burn's flames reach a slime's head as a tower's; the arrow's trail streaks follow the flight (they had no direction, so only faint dots showed).

### Fixed
- Board plates scale with the zoom again (the NEWS 31 change had dropped it): the full plate of the hovered or selected unit stayed small, so it looked narrower than the compact plates around it. Both forms scale with the board now; the full one never below its designed size. HP bars are 10 thick (was 8).
- The tutorial's pointing bubble and light ring went wrong near the screen edges and when zoomed in: the bubble now points just over the unit's HP bar (its real height, straight up on screen) and the ring goes round its feet, as wide as 1.2 tiles look at that zoom.
- The icon bar's "+N" counted one too few (5 statuses showed "+1" with 2 hidden); status badges of chips hidden behind "+N" stayed on screen.
- HP bars slid sideways off units near the screen edges (perspective leaned the point over the head outward). Plates and markers now sit on the model's centre as seen on screen and rise straight up from it. Each unit can set its own height with the new `plateOffset` (tiles above the model's centre; 0 = automatic).
- HP bars and the markers over units trailed the board by a frame while the camera moved (a parallax-like swim): the overlay is now placed after the camera moves. Tooltips pinned to a plate and the status boxes follow it the same frame, and an open status stack moves with its plate during a pan.
- Status tooltips over the board (one box per status) showed a tail pointing down at nothing: the boxes copy the tooltip's look and kept its last tail. They have no tail now.
- Status tooltips over the board open right of the plate's status icons and HP bar (whichever is wider), with their top level with the icons; before, they lined up with the HP bar below the icons, so they hung low and far from the icon hovered.
- The "Kills" tag and the "-N" over a unit sit lower when its plate shows no status icons (just over the HP bar), instead of leaving a gap where the icons would be.

### Changed
- Hand tray: a tower not placed yet shows its real model standing on the plinth (rendered once, like the Codex's preview but still), instead of its portrait in a ring; placed, the medallion as before. The full plate's backing hugs just the bar when the unit has no statuses, and the right bar's Status section closes up to the HP bar.
- Hand tray: hovering a piece lifts only its miniature (or a placed tower's medallion) 16 px, not the name plate; a selected tower's piece lifts it 8 px (UI Design Rules, the hand tray).
- A tutorial line that waits for the player to act (select the Archer, walk, cast…) no longer dims the board; only lines read and clicked on dim it.
- The tutorial's pointing bubble follows its target off screen like an HP bar, instead of sticking to the screen edge (`UI_TextBubble.KeepInside`, on by default).
- A tutorial line pointing at a unit or tile that is off screen glides the camera to it first, so the bubble can point at it (it stuck to the screen edge before).
- Haste can stack without a small cap again (99); the limit of two belongs to Quicken, which can't be cast at 2 Haste (`castGate: Self.Stacks(haste) < 2`). Other sources of Haste may give more.
- Ability descriptions no longer end with their cooldown ("Every other turn."); status descriptions say only what the status does, without durations (Haste: "Moves farther: {stacks} more Speed.", Shield: "Blocks the next {stacks} damage before HP.").
- Board plates per NEWS 31: compact by default (as wide as the unit's tile on screen minus 8, following the zoom; 28 px status chips without badges, 6 px apart, 3 slots, then 2 + "+N"), full for the hovered or selected unit (164 px bar, 32 px chips with pills, 12 px apart, 4 slots, a dark backing, drawn on top, the other plates dimmed to half). Statuses take the slots in order: shields and defensive buffs, control, damage over time, the rest; newest first.
- Status chip badges per NEWS 29–31: time left is a cream pill at the top-left corner, stacks a dark pill at the bottom-right; both grow equally to both sides for 2–3 digits, 4+ digits read "1.2k"; chips keep a fixed gap. `UI_IconBar` gained `Configure` (size, gap, per row at runtime), `SetOrder` and per-icon overhangs (`IconOverhang`, generic; unused by the chips now).
- The board has a frame: the map kit's board edge pieces (side and corner, the slab's grass lip and soil layers) go round every map on its outer tiles, facing out. New Tile kind `Border`; `TileLook.Frame`.
- Credits restyled: a wood window with a title and a close button, holding a paper card ("Game by" Eren Osman, "Music by" Emre Osman, the Nunito licence). A second secret: the E of "EMRE" wins the first 8 levels (`DevShortcuts.WinFirstLevels`); the E of "EREN" still completes Chapter 1.
- Status and passive icons redrawn to the chip-shape rule (UI Design Rules): passives are double-rim squares, statuses circles, buffs double-rim circles. The 12 status and 7 passive icons were replaced from the UI/UX agent's kit, keeping their import settings.
- Previews calculate instead of rolling (`TurnForecast` runs the resolver in its preview mode): an uncertain hit lands, anything else left to chance (a crit, a chance reaction such as a 30% counter) doesn't happen, `rand()` gives its lowest. Your ability's preview fires no reactions (counters, on-death bursts), only what the cast does to its targets. The hovered enemy's "-N" now comes from the same dry run (its turn alone, `TurnForecast.Turn`), so armour, statuses and shields count; before, it showed the attack's power.
- Board decals from the kit: range, area, a walk's reach (decal_move), route dots (decal_move_step), the destination ring turned along the last step (decal_move_dest), free and blocked build tiles while placing (decal_place, decal_place_blocked), and green targets on your own side for heals and buffs (decal_heal_valid). A walk no longer pulses its reachable tiles as targets.

## 2026-10-09

### Fixed
- Tutorial pointing: the bubble sat on top of the button it pointed at, and the light ring floated above units. The bubble now points at a button's top edge (a unit's head) and the ring goes round the button's middle (a unit's feet).
- Codex and Info models looked dark in the main menu: the preview lit them with one weak point light plus the scene's own ambient light. It now has its own key and fill lights that reach only the preview layer, so a model looks the same in every scene.
- A thin vertical line on the board (the background showing through the gaps between tiles along the column facing away from the camera): a dark slab now lies under the whole board.
- A reused passive row could keep the aura hover of the passive it showed before (it cleared the old EventTrigger, not the HoverRelay).
- "Releasing render texture that is set as Camera.targetTexture!": the Codex model preview now unhooks its camera before releasing its texture.
- An empty old speech bubble (Skip, "Click to continue") sat in the middle of the board: with the dialogue box in the scene, the old bubble is now hidden.

### Changed
- Attack previews by delivery (UI Design Rules, step 2): hovering or aiming an attack, hovering an enemy, or End turn's preview draws the line to where it really lands: a chevron for Melee, a dashed line for a Projectile, a dotted arc with an impact ring for Lobbed, a faint link with a rune under the target for a Spell, in the player's or the enemy's colours (kit atk_* sprites, theme attackSprites).
- HP previews (UI Design Rules, step 3): the ability hovered or aimed, and End turn's enemy-phase preview, are played ahead on a copy of the state (`TurnForecast.Cast` / `Phase`), so the numbers are exact: "-N" or "+N" over each unit, the HP it would leave striped on its bar (blinking red stripes for a loss, green for a heal; theme stripesDamage / stripesHeal), and a "Kills" tag (tag_kills) when lethal.
- Board previews use the kit's decals (UI Design Rules, Board previews, step 1): range, valid targets (pulsing), area, free build tiles, walk routes, and the enemy's path, stop and targets, from theme decals; any missing one falls back to the target decal tinted, then to the old flat colours. Range, area, build and walk decals were requested from the UI/UX agent.
- A road over a chasm shows the chasm, not a road piece (no bridges).
- Levels can have a look of their own (Tiles — Design, step 5, data side): a new content type Tile (the map kit's 29 pieces, `Content/Tiles.json`), `visual` and `props` layers (Tile ids, `-N/E/S/W` to turn a piece), and an automatic look from terrain, build and road that the layers override. Validate All checks the layers. The board builds each tile from its kit piece (placeholder blocks where none fits), and the Level Editor has Visual and Props tools (pick a Tile, R turns it, right-click clears).
- The inspector card's stat tiles show their stat icons like the Info window (one shared list in the theme, `UITheme.statIcons`); ability tags stay without icons.
- New setting Camera Follows Selection (Settings > Gameplay, on by default): the camera glides to the unit you select, by clicking it on the board, its tray piece or its key.
- Codex and Info ability rows follow the approved ability-rows mockup: a bigger icon with the pips, "Ready" and "2 turn CD" under it; the name and type, the whole description, then the numbers as small tags ("10 Damage", "2 Range") that wrap.
- Ability text and tags (wiki NEWS 20–22, your approved ability-rows mockup): abilities show their formulas' results as tags named by what they are (Damage or Heal, Range or Move, Area, Hits, Jumps, Duration when it scales, Pushback; `AbilityText.Tags`, tested); cooldowns read "1 turn CD", "2 turn CD", "CD until reset" with the state "Ready" / "In 1 turn"; descriptions show every number bold and status names in the status colour, in full. The action bar tooltip, the Codex and the Info rows all use them; rows with a "Tags" container show one tag element per result.
- The card lists abilities and passives as rows (picture, name, "Ready" in green or "1 turn", passives "Always on"); six fit above Sell, more scroll. The hand tray starts at the bottom-left.
- New bottom row (wiki NEWS 19, approved): the tray sits bottom-left; the action bar sits bottom-centre of the board area, slides right of the tray when they would touch, and moves up a row above the tray when they don't fit; the hint line sits under the bar, refusals in red; a key pressed on an ability that isn't ready writes why under the bar ("Tower Walk is ready in 1 turn."); the camera frames the board above whatever the bottom row takes.
- The hint line sits on a thin wood strip (hidden while there is no hint). Info windows list abilities with a bigger icon and their state ("Ready", "In 1 turn", "Always on") with the cooldown pips under it.
- Your hand and tooltip review (wiki NEWS 18): the hint sits 16 px above the action bar (or the tray), centred on the board; tooltips and the status stack draw above everything; a hand card's tooltip opens straight above its card (above the action bar when it shows), centred, never to a side; Info ability rows show the numbers as one tag line ("Range 2 · Damage 10") and how soon each is ready ("Ready", "In 1 turn") under the icon.
- Every Apply Status step now sets its status's duration itself (12 abilities and reactions got their status's current duration, so nothing plays differently); the status's own duration stays the fallback for an empty step.
- Ability buttons show the ability's full-face picture under a state frame (ready, hover, pressed, aiming, cooldown, held, blocked). Tray pieces on the board show the medallion, the wood name plate and an HP bar under it (no "on board" tag, no arrow). The card shows HP as a "Health 20 / 20" line over a thick bar and centres its ability icons. The Tower and Enemy Info windows are smaller (960×640) and scroll as one page.
- Your review of the build (wiki NEWS 15–16): no markers on the board any more (no intent chips, threat tags or cooldown dots, also none in the tray). Hovering an enemy shows its whole coming turn (route, stop tile, attack area, "-5" over whom it would hit); hovering one of its abilities shows only that ability. A soft glow under each unit you command that can still act. Selected tray piece by colour only (no arrow). The card lists abilities for towers too, read-only. Ability buttons use the kit's full-face pictures (theme abilityFaces). A held number key shows its ability button pressed, and a key on an ability that can't be cast now shakes the button and shows why, like a click.
- The inspector card has one list too (NEWS 14): an enemy's abilities, then the passives at the end as icon buttons without ring or badge (dimmed while off, aura shown on hover); a tower's card lists only its passives there, and there is no separate Passives heading.
- Tower and Enemy Info become siblings of the Codex page (wiki NEWS 13–14): subtitle ("Tower · on the board", "Enemy · boss"), an HP row, stat tiles, abilities as Codex rows with their live state ("Every 2nd turn · Ready in 1 turn") followed by the passives in the same list ("Always on"), statuses with what they do now, stacks and "2 turns left · applied by Mage" ("No statuses" when none), and an enemy's next turn. Stat tiles everywhere (Codex, Info, the card) show Max HP first and a bonus badge ("+2", "+60") over the base value. Every new part is optional, so the older window keeps working until it is rebuilt.
- The selected tower is selected in the tray too (wiki NEWS 12): its piece shows the cobalt Selected plate, a brighter medallion ring lifted 8 px and an arrow to the board; placed but unselected pieces are wood; clicking a placed piece selects its tower and glides the camera there; hovering a piece lights its tower's ring on the board. The board's selection mark is a cobalt ring (decal_select_ring) instead of the yellow tile.
- Tutorial pointing (wiki NEWS 11): a line that points at a unit, tile or HUD element shows as a speech bubble beside its target, following it, with the board dimmed and a light ring on the target (optional Dim and Ring); story lines keep the dialogue box. Switching between them fades in over 0.25 s.
- The dialogue box shows the step ("Tutorial · 2/12") and how a line goes on ("Click or press Space", or "Goes on when you place a tower"): optional Step and Hint on UI_DialogueBox.
- Kit restyle after Eren saw it in the game (wiki NEWS 10): blue means active (no cobalt band under panels, pills, cards, tabs, rows, wood buttons, the tray or the name plate; cobalt only on the one primary button per screen, selected / hover / focus, End turn, tower rings); controls are flat outside menus (174 sprites redrawn; deep menu_* sprites for the main menu and Welcome); buttons, icon buttons, ability buttons and End turn no longer lift, sink or grow (UITheme feedback profiles), only their sprites change. KitBImport has the new borders (127 sprites).
- HUD closer to the cooldown-pass mockup (screens-b/hud.html): hovering or aiming an ability shows "-10" over each unit it would hit (where its instinct would aim it, or the hovered aim); enemy walk chips show only the number (the arrow is the chip's sprite); the HP pill shows its maximum ("8 / 10", optional HealthMax).

## 2026-10-08

### Changed
- Unit portraits from the kit (NEWS 9): every unit and tower uses its colour bust as its icon (Art/Icons/Units, 28 units and 9 towers; the hand tray, the inspector card, the Codex). Ready-made medallions (64/128/256) and the Codex's "not discovered" silhouettes are in Art/UI/KitB/units.
- Guardian: Range 2 (Taunt reaches Self.Range, still 2 tiles); Bash keeps a fixed reach of 1 (adjacent), so the Codex and info popups show Range 2.
- Codex in the kit layout (header tabs, progress bar, close button, wood rows, paper page with stat tiles and ability rows with cooldown pips).
- Second style B kit drop (kit-b-ui-2026-10-08.zip): 287 more sprites (tabs, list rows, slider, toggle, dropdown, scrollbar, key slots, close button, dialogue name plate, speaker frame, loading bar, Codex stage, chapter header, icons at 64 and 128 px) and 7 passive icons, now used by every passive. KitBImport takes its 9-slice borders from the kit's slices.json and also imports Art/Icons/Passives. Unit portraits were requested from the wiki agent.
- The inspector card always shows HP and lists abilities only for enemies and neutrals; an enemy's card says what it does next ("Next: Smash on Archer", from the enemy phase forecast). HUD bars with a PanelTransition fade and scale in and out (the card, the action bar); the energy pill shows "+20" / "-100" for a moment when energy changes.
- The Princess speaks the tutorial and the Slime King's entrance (new speaker `Princess`); the 14 lines are rewritten for her and for the new HUD (the tray, the card on the right, the ability bar). Sequences show in a visual-novel dialogue box (`UI_DialogueBox`: name plate, letter reveal, Skip, the speaker's portrait) with a bobbing arrow over what a line points at. The victory screen shows base HP left and towers lost; the pause menu in a level reads "Quit to level select" (or camp) and "Quit game", in the tutorial "Exit tutorial".
- Board feedback (hud-menu-spec §6.5–6.6): "Ready!" pops over your units with a ready ability when your turn starts; one pip per ability over each unit you command (ready, waiting, held); while your turn waits, every enemy shows its intent (its attack, a walk, or nothing) and whoever it would hurt shows the HP it would lose or "Dies" (the whole enemy phase is played ahead on a copy, `TurnForecast.Phase`). Hovering End turn shows the enemy phase on the board (walks, stops, areas, targets) and its tooltip lists what is still usable, what is ready next turn and what the enemy turn would cost ("End turn anyway?").
- Tooltips become paper (ink text and role colours for paper) with a tail pointing at what they belong to when they open above or below it. The main menu and pause menu accept kit buttons; Settings and Codex tabs use the kit's tab sprites when the theme has them.
- Every ability and status now uses its style B kit icon (35 abilities, 11 statuses; Content/Abilities.json and Statuses.json).
- UI restyle step 6: fixes from the component review. Right clicks no longer press status icons; an icon removed during its spawn no longer throws; a collapsed icon bar hides icons by their Content; an HP bar whose fill stays the same no longer flashes heal-green; HP labels never autosize below 18; icon-less status words on plates are larger; hovering list rows no longer swallows scrolling (HoverRelay instead of EventTrigger). The plan's deletions (UI_Card, the icon bar's overflow and hover expand, UI_IconPro's hover effects) were not done: they are template features kept for later use.
- UI restyle step 5: the board overlay is split into plates, floating numbers and banners. Floating numbers are pooled, pop in with an overshoot and stack upwards when several land on one unit; banners use the kit's display type and sweep in and out; plates never shrink below their designed size; the overlay scales like the HUD. The code-built placeholder plates are gone. Panels can fade and scale in and out (PanelTransition), also while the game is paused.
- UI restyle step 4 (code): the battle HUD of style B. An inspector card on the right replaces the tower and enemy bars; an action bar above the hand holds the selected tower's ability buttons with cooldown clock rings and corner badges (tooltip above the bar); the hand becomes a tray of pieces (miniature, cost coin and key; placed: medallion, HP and one pip per ability); the top bar shows Round, a phase tag and wave pips, HP turns red at 30 %, End turn reads "Enemy turn" during the enemy turn. A tower you can't afford can no longer be picked (a click shakes it and says how much energy is missing); the Shift tint on ability rows is gone (the hint still says whether a quick cast works). The board is framed in the area left by the top bar (96), the tray (168) and the card (372).
- UI restyle step 3: tooltips and the status tooltip stack are placed by one routine that keeps them off the previewed tiles (range, aim, area) and inside the screen, trying the other sides when needed; only one shows at a time, an open tooltip updates when its content changes, one hover's exit no longer hides another's tooltip, and both wait 0.4 s.
- UI restyle step 2: buttons press on pointer down and click on release, a disabled button still explains itself (hover shows the reason, a click shakes it), End turn breathes and glows when nothing else is left to do, and a button can take a kit style (sprite per state) from the theme. Hover bob, glow pulse, shine sweep and click punch are gone.
- UI restyle step 1: a `UITheme` (colour tokens, type scale, motion, control styles and kit sprites of style B) that tooltips, entity texts and floating numbers now take their colours from; tower names and neutral text use the kit's light accent instead of teal.
- Screen-size fixes (Docs/Notes/UI/screen-size-fixes.md #2, #3): the board camera fits and centres the board in the area the HUD leaves free (top 60, bottom 120, right bar 300 at the reference, counted even while the bar is closed) and fits the board's real outline (not a circle around it), so the board is bigger, and ability tooltips open under the right bar's ability list instead of over the previewed tiles.
- Screen-size fixes, the rest (#1, #4–#6): bigger HUD text (minimum 18 at the reference; hand cards 104×112), a "Wave" text label, the main menu and boot scenes scale like the others (match 0.5), the main menu and pause windows fit their buttons, the greeting sits on a dark strip, a 44×44 "i" button, Skip's tooltip says why it is greyed out, the hand editor says "Towers you win appear here" when you own no other towers, and the hint and banners are centred over the board's free area. Settings keeps its fixed size until the redesign.

### Added
- Style B UI kit imported (sprites at PPU 200, 47 status and ability icons, Plinth and Nunito TextMeshPro fonts); not used by the UI yet. Model pack 08e: Base and Fortress without faces, a remade Archer with a Muzzle on its bow, and fixes for clipping and inside-out faces.
- Docs: UI Design Rules (style B "Painted Diorama"), Style & Art Direction ("Painted Miniatures") and the UI kit notes (`Docs/Notes/UI/`), from the server's UI/UX and art agents.

### Fixed
- Hit flashes no longer repaint a multi-material model (the new models) in one colour: each material keeps its own colour.
- Projectiles start from the model's "Muzzle" point when it has one, else about two thirds of the way up the model (was a fixed low point).

### Changed
- New art: every unit (9 towers, 14 enemies, Base, Fortress, Rock) uses its "Painted Miniatures" model, made in Blender by the wiki's agent, with Idle, Walk, Attack, Cast, Hit, Die and Spawn animations. The old placeholder models stay in each unit's folder.

## 2026-10-07

### Added
- Multiplayer — Design (draft): what the game already gives multiplayer, possible modes and the questions to decide first.

## 2026-10-05

### Added
- Enemy turn preview: selecting an enemy and hovering one of its abilities shows its coming turn as the board stands now, played on a copy of the game: its route (white dots), where it stops (orange) and the tiles its attack hits from there (red), with a hint line ("Next turn, as things stand: moves 1 tile, then Smash on Archer"). The enemies that act before it take their turns in the copy first, so a unit ahead that walks on frees the road. It is recomputed after every move of yours.
- Tiles change during a battle (Tiles — Design, step 3). A Change Terrain ability step fills a chasm, drops a bridge or raises a wall on the aimed tile or an area, optionally only on some terrains and switching building on or off. A level event does the same on a schedule. A unit that can no longer stand there falls and dies (tagged Fell), or is pushed out of a new wall. Abilities can check `Self.OnTerrain(chasm)`, and passives can react to a tile changing. The board does not show the change yet (step 4).
- The map as layers (Tiles — Design, step 2): a level's map is three text layers, one character per tile. `terrain` has a character per terrain, named in its terrain keys. `build` has `+` where towers may be placed. `road` draws the road with box characters (`─ ┘ ┬ ┼…`). Paths stay tile lists in walking order and may now loop over themselves. Ground, Wall and Chasm are Terrain assets. The Level Editor paints terrain and build tiles and draws paths, and the road follows the paths. Every level was converted; maps and waves are unchanged.
- Content JSON is more compact: small entries (a tile, a stat) take one line, and path tiles sit several to a line. `bash Tools/Offline/offline.sh format` writes hand-edited files the same way.
- Terrain (Tiles — Design, step 1): a tile's ground is now data the battle can change. Walls, chasms and ground are built in, and `Create > Game > Terrain` makes new ones (who stands on it, whether it blocks shots and sight, tags, what happens to units caught on it). Levels name a terrain on every tile.
- Tiles — Design (draft): terrain as content, roads written as a start and moves (corners, entering from the map edge, loops), tiles that change during a battle (a chasm filled, a bridge falling).
- Logic without Unity: `bash Tools/Offline/offline.sh test` builds every Game assembly and runs all Edit Mode tests, asset tests included (156); `check` runs Validate All on `Content/*.json`; `docs` writes `Docs/Reference/` from the JSON. The content layer loads straight from the JSON (`ContentLibrary`) and the editor shares the same code (Validate All, Export Game Reference, the JSON format).
- "Where it lives" at the top of every content asset's Inspector: the asset file, its Content JSON entry (and whether it matches), its reference page, the tower ↔ unit link and Find uses (which assets refer to it). Reference pages end each tower, enemy, status and level with a Source line (asset path and JSON entry).
- Content JSON: every content asset is also an entry in `Content/<Type>.json` (Units, Abilities, Statuses, Levels…), the source of truth for content. `Tools > Content > Content JSON` shows what differs between the files and the assets and imports or exports only the ticked entries; `ContentImport.txt` queues imports from outside the editor; the Balance Sheet keeps the JSON in step.
- Balance Sheet (`Tools > Combat > Balance Sheet`): every unit's stats and tower cost, every ability's cooldown / range / damage / heal, every status's duration / stacking / shield, editable in one table; `Balance.txt` lets agents queue number changes for the open editor. The chapter builders no longer overwrite numbers on existing assets.
- Placeholder Drummer model: a red-coated drummer with a cap, a strapped drum and two sticks (was a bare drum).
- Secret: in the Credits, clicking the E of "Eren" completes Chapter 1 (every level won, its rewards given, the tutorial finished), so the Camp and Chapter 2 can be tried without replaying.
- Chapter 2 filled out: pricier reward towers (Ballista 160, Alchemist 150 with stacking Acid, War Drum 140 — the ally from 2-3, now with Rally, Cannon 220), stronger enemies (Ironhide, Slime Shaman, Jackalope), fuller waves and a hand of 5 in every level.
- Chapter 2 (`Tools > Combat > Create Chapter 2`): Rock Garden (rocks, hopping Rabbits that speed up, rock-eating Rockjaws), Three at the Gate (three Brutes already on the road), The War Drum (a War Drum ally, Bats over a chasm road), The Glutton (three roads; a boss that eats every other enemy on arrival for +20 max HP each). Chapter 1 level 4 now rewards the Wisp, a tower that zaps and teleports. See Docs/Design/Chapter 2 — Design.md.
- Engine for Chapter 2: Flying units stand over chasms and may walk a road drawn across one (Validate All refuses non-flyers on such a road); a road walk can hop over units in its way (`jumpsOverUnits`, with a Jump step: rabbits over rocks); abilities can require a free tile the caster could stand on (`needsFreeTile`: teleports); Rock and Flying tags.
- Camp first visit: after the welcome card, a speech bubble walks through the stations (Chapters, Towers, Codex, Workshop, Multiplayer), each highlighted with one line; click for the next, Skip ends it.
- The Camp scene: stations for Chapters, Towers (the hand editor), Codex and Main menu (Workshop and Multiplayer marked "Coming later"), a welcome card on the first visit, the chapter picker (a card per chapter with its wins) and a chapter's level select as a panel over the Camp. `Tools > Combat > Set Up Camp Scene` builds it. The main menu has a Continue button first in its list.
- Camp & Chapters, phase 1: chapters are Main or Side (a side chapter opens with its own levels; a main one when the previous main chapter is won); winning Chapter 1's last level opens the Camp (`GameCatalogAsset.campUnlock`), after which Play, the end screen and the pause menu lead there (level select until the Camp scene exists); the main menu gets an optional Continue button for the next story level (not shown before the first level is won); the tutorial's pause menu hides the Codex.
- Starting units in levels (`LevelAsset.startingUnits`): an ally the player commands like a base (a helping tower), a neutral obstacle both sides can break (a rock; a new third team), or an enemy already on a road (part of the first wave). Validate All checks their tiles (an obstacle on a road is fine); the reference lists them; the Level Editor places them (Unit tool: pick the entity and side, click a tile).
- Duration stat and an Apply Status `turns` formula (e.g. `Self.Duration`): an ability can make a status last as long as its caster's Duration. Shown only on units that have it; no unit does yet (Burn keeps its own 2 turns).
- Codex, in the main menu and the pause menu: towers, enemies, statuses and tips, shown once discovered (??? before, a dot while new); documented in Codex — Design and a generated Codex reference page (entry order and the full tips); towers and enemies with a turning 3D model, stats, abilities and passives; statuses with how long they last and how they stack; 11 tips that name keys as bound. The level records enemies and statuses as they appear; `Tools > Combat > Fill Codex` fills it.
- Hidden content numbers: every ability, entity, tower, status, passive, reaction, item, level, sequence and ability presentation has a number (1, 2, 3… per type), given when it is made and never reused; read-only in the Inspector, never shown to players. `Tools > Combat > Number Content` numbers older assets.
- Key rebinding: Settings > Controls lists every action with two keys, each a key with none, Shift, Ctrl, Alt or Ctrl+Shift (End round: Enter or Shift+Space); click a slot and press the keys, Esc cancels, Backspace clears, Reset to defaults; a key given to two actions shows in red on both. The ability keys 1–9 aim, quick cast or pick a hand card depending on the modifier held, each chosen from a dropdown (none / Shift / Ctrl by default). Tooltips, hints and the tutorial name the keys as bound.
- Persistent Data Viewer: **Delete Save** button, to start over as a new player (Welcome screen, tutorial).
- Speech bubbles in levels: the base speaks the level's intro and the tutorial's steps in a bubble that points at it (or at an enemy, a tower, a tile or a button) and follows the camera. The text appears letter by letter: click once to show it all, again to go on; Skip ends the conversation. The tutorial is now playable from the Welcome screen.
- Welcome screen on the first launch: type a name (up to 16 letters, "Commander" when left empty), then Start plays the tutorial or Skip tutorial goes to the main menu. The main menu greets you by name; the tutorial's end screen leads back to the main menu. `Tools > Combat > Set Up Welcome Scene` builds it.
- Sequences (`Create > Game > Sequence`): speech-bubble lines that continue on a click, after some seconds or when the player does something; a level's intro plays the first time it is played; the tutorial's seven steps are one. The bubble itself is still to come.
- First launch groundwork: a player profile in the save (name, tutorial state), the boot screen routes a first launch to the Welcome scene, the tutorial level (`Tools > Combat > Create Tutorial`: one Archer, a Slime, then two), finishing or skipping it gives a second Archer; a new save starts with one Archer.
- Circle areas and ranges take decimal radii (1.5: the 3×3 block plus the four tiles two steps away); whole numbers are unchanged.
- `Tools > Docs > Export Game Reference`: Markdown pages of every tower, enemy, status and level (maps drawn as text, waves, rewards), generated from the assets into `Docs/Reference/`.
- Docs index (`Docs/README.md`), glossary and decision log.
- The Instinct, Animation & Presentation and Level Select design docs now live in the repo (`Docs/Design/`).

### Changed
- Apply Status has one optional Duration formula (e.g. `2` or `Self.Duration`; empty = the status's own duration, `-1` permanent) instead of a Duration number plus a Turns formula.
- One Shield status instead of Slime Shield and Stone Skin: its stacks are its shield points (Shield Slimes arrive with 10 and refill to 10; Rockjaws gain 100 per rock), and damage it absorbs removes stacks.
- Optional formulas (Apply Status Turns, Remove Status Stacks, Reset Cooldown Turns, a status's Shield Pool) no longer show "is empty" in the Inspector.
- Remove Status can take off some stacks: a `stacks` formula (e.g. `1`) instead of the whole status; StatusRemoved events say how many stacks are left.
- Tools menu: the builders (Create Chapter 1 / 2, Tutorial, Example Assets / Model, Game Catalog, Set Up … Scene, Rebuild … Prefabs) moved to `Tools > Deprecated`; Fill Codex, Number Content and Apply Balance File to `Tools > Content`. `Tools > Combat` keeps Level Editor, Level Playtester, Balance Sheet and Validate All.
- Rabbits start at Speed 1 (Quicken takes them to 3 at most); rocks have 20 HP.
- 2-3 The Drummer redrawn: the base sits just above the chasm on the right, the ground road climbs to the top and comes round the right side down to it, a wall block stands in the middle, and the flyers' road runs along the bottom of the chasm.
- Rabbits and Jackalopes speed up with **Quicken**, an ability they cast on themselves (cooldown 2: every other turn, Haste +1 Speed, at most +2), instead of a passive with a hidden counter. Units also count their turns now (`Self.TurnsTaken` in formulas).
- 2-4 The Glutton: the top and bottom roads run along the map's edges and come round the right side to the base, so enemies no longer jam in the narrow middle.
- The War Drum is now the Drummer (a person with a drum): names, ids (`drummer` for the unit and the tower), asset names (moved, GUIDs kept) and 2-3 "The Drummer"; it has the first Drummer's kit: War Beat aura, Rally, Tower Walk, Duration 2, HP 25.
- Balance: Chapter 2 levels use a sturdier base, the Fortress (40 HP); Rabbits' Haste stops at +2 Speed; Ballista hits for 25, Cannon for 30; the Wisp hits for 10 at range 3 (Blink reaches 5). Enemy hits stay one-shots for towers and Rockjaws' Stone Skin keeps stacking, by design.
- Chapter 2 tougher: Rock 80 HP, Rabbit 30, Jackalope 55, Rockjaw 70, Bat 30, Slime Shaman 40, Ironhide 130, Slime Glutton 200, with more Power; the new towers cost 200 or more (Wisp 200, War Drum 200, Alchemist 220, Ballista 240, Cannon 280) and Chapter 2's levels give more energy (400–550 to start, +40–45 a round).
- Killing the last enemy wins the level at once (when every wave has spawned everything), instead of at the next End round. Waves are cleared the same way, so a wave that starts after another one now starts at the End round right after the last kill.
- Info panels in a level: the tower and enemy bars and the info popups list the unit's stats as rows (Power, Potency, Speed, Range, Radius; a boosted one shows base → now in green or red); the popup's abilities show Damage / Range / Area rows and the cooldown like their tooltips, a turning model of the unit, and a Codex button that opens its Codex page.
- Mage: Potency 2. Firebolt now hits everyone in its area, your own towers and base too (quick cast still aims for the most enemies, then the fewest allies), and sets them burning: the new Burn status deals the caster's Potency as fire damage at the start of each of their turns, for 2 turns (a new Firebolt starts it over).
- Power and Potency are unit stats and carry the numbers: the Archer has Power 10 and Shoot hits for `Self.Power`; the Priest has Power 5 (Smite) and Potency 10 (Mend); the Slime King Power 5 (Crush 5, Slam twice that). Same damage as before. The attack value in formulas is now `ActionPower` (was `Power`), shown to players as Damage; tooltips, bars and the Codex show Power and Potency where a unit has them; Damage appears only on abilities. `Str` is gone.
- Range and Radius are unit stats: abilities read `Self.Range` (Taunt and Mend `Self.Range + 1`) and area attacks `Self.Radius`, so they can be boosted; tooltips, the tower and enemy bars and the Codex show them only on units that have them. Same numbers as before.
- The base speaks when an enemy with entrance lines appears for the first time (`EntityAsset.entrance`, pointing at it): the Slime King gets two lines (its health and Slam; keep towers apart, do not let it reach the base).
- Tutorial: after the first Slime falls, a new line asks to keep clicking End Turn; the "Slime and a Runner" line waits until both have spawned (new sequence event "wave arrived"). 12 lines.
- Tutorial lines are mouse-first: click End Turn, click Tower Walk or Shoot on the panel, Shift-click Shoot for a quick cast; keys are only mentioned in brackets.
- Tutorial line 3 now matches the tower panel: name and health at the top, then abilities; 1 and 2 for the first and second ability; the bracketed number is the cooldown (keys are not shown on the rows).
- Tutorial: a 12-tile road; the base teaches walking toward the Slime and shooting once it is in range; wave 2 is a Slime and a Runner; Retry only after a loss. Closing the game during the tutorial counts as skipping it (the second Archer is still given). Sequences gain the events "tower moved" and "enemy in range".
- The speech bubble draws behind the HUD's bars and panels; the end screen hides Retry after winning the tutorial.
- GameScene lighting: a light from straight above plus soft grey ambient, instead of the old angled light (fully flat lighting was tried first).
- Folder structure settled (`Docs/Design/Folder Structure — Design.md`): content icons all in `Art/Icons`, scratch scenes in `Scenes/Test` and out of the build, `Audio/Music`, `Editor/Inspectors`, empty template folders removed.
- Create Example Model keeps existing placeholder models, materials and clips (hand tweaks survive) and never replaces real art; `Rebuild Example Models (overwrite)` redoes them.
- Art: each unit has its own folder under `Art/Models/` with its model, animations and own materials; `Art/Animations/` is gone.
- The walk the Brute, Slime Archer and Slime King share now describes itself correctly; Smash says it hits "an adjacent tower or the base".
- Project layout: game data sorted by kind (`Assets/Data/Towers`, `Units/{Towers,Enemies,Bases,Other}`, `Abilities`, `Passives`, `Reactions`, `Statuses`, `Levels/Chapter 1`…; demo content in each kind's `Examples/`), placeholder art under `Assets/Art/*/Placeholder`, ability icons in `Assets/Art/Icons`, docs moved to `Docs/` at the repo root. `Tools > Project > Sort Data and Art` re-sorts; the builders find assets anywhere under Data.

### Removed
- The UI style system (UI Style Manager, `UIStyleConfiguration`, `UIStyleTag`, `Resources/UIStyleSettings`): unused in this project, and its settings asset had lost its script. The template keeps it.

### Fixed
- Ranges for self-cast abilities and auras: hovering Rally shows the 2 tiles around the Drummer it reaches (not just its own tile), and hovering a passive with an aura (War Beat) shows the tiles it covers.
- The asset test that wins the Example Level no longer ends a round after the level is already won.
- End Turn is greyed out while an action plays; a selected tower's abilities look unusable until playback catches up (after End Turn they showed the old cooldown, e.g. Shoot (1), while looking ready).
- Tests: three duplicates removed (the formula-only Shield Breaker sum, a poison tick test covered by the status tests, a test of .NET GUIDs), the Codex tests merged into one, and the Fireball asset test updated for Power (Enraged no longer gives Str).
- Codex: the page on the right scrolls with the wheel and by dragging (its scroll area had nothing to catch the pointer).
- A speech bubble no longer outlives the level: once it is won or lost and the last action has played, the sequence ends (no extra line after the last kill, nothing over the end screen).
- Closing the game on the Welcome screen no longer skips it next time: only saves from before player profiles count as past the tutorial.
- Ranged attackers without animations (the Archer) turn toward their target before shooting, like everyone else.
- Switching scenes quickly no longer leaves the previous scene's music playing underneath (an interrupted crossfade now fades the old track out).

## 2026-10-04

### Added
- Build tiles (`+` in level maps, a Build tool in the Level Editor): when a level has any, towers are placed only there. Chapter 1: the 5×5 square around the base, off the roads.
- Face Target On Cast option on abilities: the caster turns toward the aimed tile.
- Hold Shift + 1–9: shows the ability's range and quick-cast target; letting go casts it, right-click cancels. Holding 1–9 alone previews the range.
- Shift while aiming shows where the ability's instinct would cast it.
- Hovering an enemy's ability shows its range; an enemy walk also shows, in red, the reach a unit ahead blocks.
- HP numbers ("12/30") on the tower and enemy bars' health bars.
- Presentation Timings asset: banner, floating-text and health-bar durations as data.
- Music: menu, battle, and a random map track in level select.
- Taunt, shield, attack and move icons.
- Ability and passive tooltips open left of the right bar; hand card tooltips above the bottom bar.

### Changed
- Input uses the Input System package only (`InputHelper`); the old Input Manager is off.
- Enemy cooldowns count down at the start of your turn, so you can see what they can do next.
- Cooldown 1 means usable every turn (cooldowns are at least 1); tooltips show "Cooldown: 1 turn".
- Clicking units and right-clicking work while an action plays; commands still wait.
- Hand towers are picked with Ctrl+1–9 only; plain 1–9 aims abilities.
- Health bars show on hover, selection, after a hit and while dying (Always Show Health shows them all); plates scale with zoom; status icons on plates are centred and hoverable.
- Banners no longer block play; a newer round or phase banner replaces an older one.
- Follow the action centres every action.
- Archer's Shoot hits the enemy it chose instead of the first one in line.
- Corpses are hidden by default.
- Balance: Shield Slime 20 HP; Runner and Slime Archer 15 HP; Spitters uses Big Slimes; Bash cooldown 1; Two Roads' last wave has a Shield Slime.
- Selecting a unit shows its statuses without the pop-in animation.

### Fixed
- Right-click no longer presses buttons (no punch on cards or ability rows).
- Clicking a tower after it took damage shows its HP at once instead of animating from an old value.
- One-hit kills show their health bar draining.
- The boot loading bar no longer jumps from 0 to 100.
- A static model without an Animator no longer throws on spawn.
- UIPanelCreator uses the EntityId API (no obsolete warning).

## 2026-10-03

### Added
- Chapter 1: four levels (First Steps, Spitters, Two Roads, The Slime King), each with 3 waves and a first-clear tower reward (Guardian, Mage, Priest, Archer); `Tools > Combat > Create Chapter 1` builds and rebuilds it.
- Towers Guardian (Taunt, Bash, Counter-attack), Mage (Firebolt), Priest (Mend, Smite); enemies Runner, Big Slime, Slime Archer, Shield Slime, Brute and the Slime King boss.
- Instinct: how an ability aims when nobody clicks (enemy turns, quick cast, Pick steps, bounces), with presets and custom preferences; shift-click quick cast; Taunted (soft) and Redirected (hard).
- Bases act like towers and can have abilities; cooldowns can start running or wait for a reset; Reset Cooldown and Add Cooldown steps; the Boss tag.
- Level select: chapters, unlocks, progress records, level preview with minimap, hand strip and hand popup, Next level on the end screen.
- Level Editor window: paint maps, draw roads, place bases, edit waves, validate, playtest.
- Passives in the UI; status tooltips with `{stacks}` / `{turns}` filled in; styled tooltips with stat rows and a footer.
- Ids, display names, descriptions and icons on every game asset.
- HUD, camera controls, settings, sounds, end screen; hooks for real art (models, Animator contract, ability presentations).
- Shift + Space ends the round; the end screen names the tower a first clear gave.

### Changed
- Upgraded to Unity 6.3 LTS.
- Hand cards and right bars redesigned; level UI built from prefabs.
- Archer costs 100.

### Fixed
- Inspector slowdown from formula and step drawers.

## 2026-10-02

### Added
- The project: a turn-based tower defense on the TemplateProject framework, with an engine-free simulation.
- The event log grouped into actions and beats; the Director and view frames; a playable level with placeholder presentation.
