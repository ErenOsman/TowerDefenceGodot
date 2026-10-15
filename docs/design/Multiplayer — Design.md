# Multiplayer — Design

Status: **co-op designed** (2026-10-07; lobby and room rules updated 2026-10-13) **and built in the Godot build** (Godot pass 2026-10-15): the rules in `sim/level/coop_session.gd` (`CoopSession`, `CoopLevelSession`), the relay client and protocol in `game/net/` (`RelayClient`, `NetProtocol`, `CoopLevels`; the protocol in docs/Co-op Protocol.md), the lobby and room in `game/ui/screens/coop/`; how they differ from this doc is in docs/Implementation Notes.md ("Co-op rules"). The first mode is live co-op, reached from the Camp's Multiplayer station (since 2026-10-14 from the Guild), with the relay on Eren's Oracle server. The rest of this doc keeps the other modes for later.

## What the game already gives us

- **The rules are deterministic and run on commands.** A level is a `LevelSession`: the same seed and the same commands (`place`, `sell`, `cast`, `end_round`) always give the same event log. Two players' games stay in step if both send only their commands, never the game state (*lockstep*). Little data travels, and there is nothing to keep in sync beyond the commands.
- **Turns, not real time.** Latency barely matters: a command can take half a second to arrive without anyone noticing. Nobody needs to be fast.
- **Presentation is separate.** Each player's screen only replays the shared event log (`Director`), so the rules don't change for multiplayer. Only "whose command is this" is new.
- **Content is data.** Levels, towers and enemies are JSON (`data/content/`), and the wiki's forum already exports player-made levels. Sharing and playing other people's levels needs no new format.

## Possible modes

| Mode | What it is | Fits the game because | Hard part |
| --- | --- | --- | --- |
| **Co-op** | Two players defend one map together, each with their own hand. Each places and casts their own towers in the shared player phase | The player phase already lets every tower act freely | Who may control which tower; how energy is shared (one pool, or one each); when the round ends (both press End round?) |
| **Versus (mirror)** | Each player defends their own copy of the same level; the one who lasts longer or loses less base HP wins | Needs almost no new rules: two sessions, the same seed | Little interaction unless something crosses over (below) |
| **Versus (send)** | Like mirror, but killing enemies earns something that sends extra enemies, or troubles, to the opponent | Waves and LevelEvents can already spawn enemies on demand | Balance, and the timing of rounds between two players |
| **Async** | No live connection: play the same level as someone else and compare results, or play levels others made | The forum already shares levels; the results are already recorded per level | A server or service to store and compare results |

## Technical outline (for any live mode)

1. **Lockstep on commands.** Each player sends their commands for the round. Both clients run the same session and compare a checksum of the state after each round, to catch desyncs early.
2. **Host or relay.** For co-op and versus, one player can host, or a small relay server passes commands between them. Nothing runs the rules on the server unless cheating matters (ranked play).
3. **Rounds.** The player phase ends when every player has pressed End round. The enemy and level phases need no input, so they run the same way on both clients.
4. **Content match.** Both players need identical content. Before a match, compare a hash of the `data/content/*.json` used (`ContentHash`). A mismatch blocks the match instead of desyncing later.
5. **Reconnect.** A client that drops can rebuild the game from the seed plus the command list so far, because of determinism.

## Co-op (the first mode)

- **Live**, 1 to 6 players on one map. Commands go through a relay on Eren's Oracle server (lockstep, as in the technical outline). The server only passes commands on; it doesn't run the rules.
- **Reached from the Camp's Multiplayer station** only.
- **Each player brings their own hand.** A co-op level's hand cap is low (e.g. 3), and it applies per player.
- **Each player controls only their own towers.** Neutral and ally starting units (e.g. a Drummer on the map) can be controlled by either player.
- **Energy:** a level setting, `isSharedPool`. When on, one pool that every player spends from; when off, each player has their own pool and income, and the level's start energy and income are split evenly: 1/N each for N players. The energy rule comes from the level data: we (the developers) set it per level, and the room's host cannot change it.
- **Players take turns.** The player phase is split into one turn per player, in order: player 1 places and casts, ends their turn, then player 2, and so on in the room's join order. **Pass** gives your turn away: you are moved to the end of the turn order and act after the others this round. Passing never ends your turn; you can pass as often as you like. **End turn** is final for the round: your turn doesn't come back until the next round. When every player has chosen End turn, the enemy phase starts. When every player has ended their turn, the enemy phase follows as usual.
- **1 to 6 players.** The room's creator picks the player count (1 to 6, default 2).
- **Levels:** the Multiplayer station has its own list of levels in the game catalog, kept like a chapter, and any level in it can be played co-op.
- **Lobby and rooms.** The server keeps a lobby of open rooms. The room's creator picks the level, a room name, the player count and an optional password; a room without a password is open and anyone can join it, otherwise players join with the password. Room names have a length limit (24 characters) and pass a swear filter. The lobby only lists rooms whose game version (the content hash from the technical outline) matches yours; rooms from other versions are never shown.
- **In the room:** every player, the host too, presses Ready. Only the host starts the match, once everyone in the room is Ready; empty slots don't block the start. The host may change the level and the player count (1 to 6) at any time before the match; either change resets everyone's Ready. Lowering the count below the number of players in the room removes the players who joined last (the host is warned and confirms). The host may remove a player. The room has a chat. Each player can change their own hand (up to the cap) until the match starts.
- **No level locks** in the co-op list for now: every level in it can be picked.
- **No progress for now:** co-op gives nothing back to single player (no rewards, no records).

- **A player leaves the room** (before the match): the room stays open and their slot waits for someone new.
- **A player leaves during the match:** the match goes on for the others; nothing breaks. Proposal (to confirm): the leaver's turn is skipped from then on, their towers stay on the board as neutral units that any remaining player may control (like neutral starting units), and their own energy pool is closed. Reconnecting comes later.

## Decisions

| Date | Decision |
| --- | --- |
| 2026-10-14 | In the room, pressing Change hand makes the player Not ready; the new hand is sent to everyone once, when they finish editing (the relay also resets Ready on any hand change) (Eren) |
| 2026-10-14 | Every multiplayer level is a **mission** (Missions & Guild — Design): the lobby is reached from the Guild (not the Camp) and lists missions only; a mission can be played a limited number of times a day, and a player whose plays are used up cannot create or join a room set to it and leaves a room that switches to it; the match start spends a play for everyone. Mission wins drop tokens (the co-op "no progress" rule is replaced by that). `Content/Missions.json` replaces the co-op level list (`sharedPool`, `coopHandCap` move onto the mission) (Eren) |
| 2026-10-13 | The room's player count can be changed after creation; going below the number of players in the room removes the last joined (user) |
| 2026-10-13 | Lobby and rooms (user): 1 to 6 players; open rooms without a password allowed; room-name length limit and swear filter; everyone, the host too, presses Ready and the host starts when all are Ready; changing the level resets Ready; room chat; the lobby hides rooms from other game versions; no level locks for now. Separate energy is split 1/N; the energy rule is level data, set by the developers, not by the host. A player leaving the room or the match breaks nothing: the room waits for someone new, the match goes on. Replaces "two players" and "a player leaving ends the match". UI mockups: http://92.5.94.11/art/ui/screens-b/ (Online co-op) |
| 2026-10-07 | Correction: Pass never ends a turn. End turn is final for the round, and the enemy phase starts when every player has ended their turn. A player leaving ends the match and closes the room (reconnecting later). The multiplayer levels are a chapter-like catalog list |
| 2026-10-07 | (replaced) Pass can be used more than once a round; two passes in a row end the turn. The multiplayer levels are a chapter-like list in the game catalog |
| 2026-10-07 | Co-op details: players take turns within the player phase, and Pass moves you to the end of the order. A level setting splits separate energy pools (full or half each). Two players. The Multiplayer station has its own level list. Lobby with rooms (creator picks level, name, password). Leaving is solved later |
| 2026-10-07 | First mode: live co-op from the Camp's Multiplayer station, relayed through Eren's Oracle server. Each player brings their own hand under a low per-player cap (e.g. 3) and controls only their own towers (neutral and ally units: either player). Energy is shared or separate per level (`isSharedPool`). No progress back to single player for now. Versus waits |
| 2026-10-07 | Draft: what the deterministic, command-driven rules already give (lockstep), four possible modes, a technical outline, 7 questions open |
