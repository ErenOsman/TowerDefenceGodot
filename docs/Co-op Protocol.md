# Co-op Protocol — the co-op relay protocol (v1)

Design: `docs/design/Multiplayer — Design.md` (co-op section, decisions of 2026-10-13). The relay only passes messages;
it never runs the rules. Both clients run the same `CoopSession` (lockstep on commands) and compare a checksum each round.

Transport: WebSocket, JSON text frames, one object per frame, field `t` = message type. Relay URL:
`ws://92.5.94.11/ws/relay` (nginx → 127.0.0.1:8090), later `wss://` when the wiki gets HTTPS.
`version` = the content hash: SHA-256 (hex, first 16 chars) over the sorted `data/content/*.json` bytes (Abilities, Catalog,
Codex, Forms, Levels, Missions, Passives, PresentationTimings, Presentations, Reactions, Rules, Sequences, Statuses,
Terrains, Tiles, Tokens, Towers, UITheme, Units), plus the protocol version string "coop-1". Rooms of other versions are
never listed.

## Client → relay
| t | fields | notes |
|---|---|---|
| `hello` | `version`, `name` (player name, ≤ 16), `client` ("godot-td/0.7") | first message; else the relay closes |
| `list` | – | asks for the lobby (also pushed on changes while in the lobby) |
| `create` | `name` (room name ≤ 24, swear-filtered), `level` (level id), `count` (1–6, default 2), `password` (optional), `hand` (tower type ids, ≤ cap), `mission` (optional mission id; the relay ignores it) | creator becomes host, joins slot 0. Every co-op level is a mission (Missions & Guild — Design): rooms carry the mission's **level** id and clients map it back (`CoopLevels.mission_for_level`); the client checks its plays left before `create`/`join`, leaves a room switched to a mission it used up, and spends the play at `match_start` (the relay knows no saves) |
| `join` | `room` (room id), `password` (optional), `hand` | errors: `not_found`, `full`, `wrong_password`, `version`, `started` |
| `leave` | – | room stays open; host leaves → the next joined player becomes host |
| `ready` | `value` (bool) | |
| `set_level` | `level` | host only; resets everyone's Ready |
| `set_count` | `count` | host only; lowering below the players present removes the last joined (client confirms first); resets Ready |
| `kick` | `player` | host only |
| `chat` | `text` (≤ 200) | |
| `set_hand` | `hand` | until the match starts; resets the sender's Ready (the client also sends `ready false` when the player opens Change hand, and sends `set_hand` once when the editor closes, not on every edit) |
| `start` | – | host only, all present players Ready (empty slots don't block) |
| `cmd` | `round`, `seq`, `cmd` (opaque object; see CoopSession.Command) | relay stamps `player` and broadcasts to the room incl. the sender (so every client applies commands in relay order) |
| `checksum` | `round`, `hash` | the relay compares all players' hashes for that round; mismatch → `desync` to all |
| `pong` | – | answer to `ping` |

## Relay → client
| t | fields |
|---|---|
| `welcome` | `player` (player id string), `version_ok` (bool) |
| `rooms` | `rooms`: [{`id`, `name`, `level`, `count`, `players` (n), `locked` (has password), `started`}] |
| `room` | the full room state: `id`, `name`, `level`, `count`, `host`, `locked`, `started`, `players`: [{`id`, `name`, `ready`, `hand`, `slot`}] (slot = join order) |
| `error` | `code` (`not_found`, `full`, `wrong_password`, `version`, `started`, `not_host`, `bad_name`, `bad_request`), `text` |
| `chat` | `from` (player id), `name`, `text` |
| `kicked` | – (you were removed) |
| `match_start` | `seed` (int), `level`, `shared_pool` (bool, from the level's energy rule), `players`: [{`id`, `name`, `hand`, `slot`}] (turn order = slot order) |
| `cmd` | `player`, `round`, `seq`, `cmd` |
| `desync` | `round`, `hashes` {player: hash} |
| `player_left` | `player` (during a match: the client applies the leaver rule from the design) |
| `ping` | – (every 20 s; a client that misses 3 pongs is dropped) |

## CoopSession.Command (opaque to the relay)
`{"k": "place", "tower": <tower id>, "x": int, "y": int}` · `{"k": "sell", "tower": id}` ·
`{"k": "cast", "unit": entity id, "ability": ability id, "x": int, "y": int, "path": [[x,y]…] (walks)}` ·
`{"k": "pass"}` · `{"k": "end_turn"}`. Tower ids in co-op are `"<player id>:<tower type id>#<n>"` so hands never collide.

**Hand entries and Workshop forms.** `hand` stays a list of strings: a tower type id (`"archer"`), or
`"<type id>@<form id>"` (`"archer@archer-fire"`) for a tower in a Workshop form. The relay never reads them (it only
checks strings ≤ 64); clients parse them (`CoopSession.parse_hand_entry` / `build_hand`) and build the form's entity,
name and cost. The tower id keeps naming only the type (`"p1:archer#1"`). Forms are content, so they are covered by
the content hash (`ContentHash` hashes every `data/content/*.json`); an unknown form id falls back to the default form.
**Tower levels** (Upgrades — Design): a tower above level 1 in its current form adds `":L<n>"` (`"archer@archer-fire:L3"`,
`"guardian:L2"`; `CoopSession.hand_entry(type, form, level)`, sent by `CoopLevels.my_hand_types`); every client builds it
at that level (`TowerLevels.apply` with the form's ladder, or the base's; capped at the max level; a bad suffix reads
level 1). Level 1 adds nothing, so older clients still read the entry. Tasks count on each client for its own towers:
`CoopLevels.task_entries(me)` maps `"<me>:<type>#n"` back to the owned towers `on_match_start` took.
Each player's commands carry a per-player `seq` (1, 2, 3…); a client applies a command only when it is the acting player's
turn in the session (the session rejects others; a rejected command from the relay is a desync).

## Checksum
After every `end_turn` that ends the round (enemy + level phase run), each client sends `checksum` for that round:
FNV-1a 64 over the session's canonical state string (`CoopSession.state_digest()`: entities sorted by id with position,
hp, shield, statuses (def name, stacks, turns), cooldowns; energy pools; round; turn order; RNG state).

## Relay notes
Clarifications from the relay implementation (`/home/ubuntu/relay/relay.js`, 2026-10-13). Live at `ws://92.5.94.11/ws/relay`.

- **Ids.** Player ids: 8 chars `[a-z0-9]` (never contain `:`, so `"<player id>:<tower type id>#<n>"` is safe). Room ids:
  6 chars `[A-Z2-9]` without `0 O 1 I` (safe to read aloud). Ids are per connection: reconnecting gives a new player id.
- **hello.** Must be the first frame, within 10 s, or the relay closes with code `4001`. `name` is trimmed (whitespace
  collapsed), 1–16 chars, else `error bad_name` and the client may send `hello` again. `version_ok` is true when
  `version` is 16 lowercase hex chars (and, if the relay is configured with an allow-list, is on it); on `false` the relay
  closes with code `4002` right after `welcome`. On success the relay sends `rooms` straight after `welcome`.
- **Lobby.** A client that said hello and is not in a room is "in the lobby" and gets `rooms` pushed on every change for
  its version (rooms created/closed, player counts, level, count, started). Started rooms stay listed with `started: true`.
  After `leave`, `kicked` (and removal by `set_count`) the relay sends a fresh `rooms`.
- **Slots.** `slot` = index in join order among the players present, so slots are renumbered (0…n-1) when someone leaves;
  a new joiner always takes the last slot. Host = slot 0; when the host leaves, the next joined player (new slot 0) becomes host.
- **Room names.** Trimmed, whitespace collapsed, 1–24 chars, then the swear filter (`/home/ubuntu/relay/badwords.txt`);
  otherwise `error bad_name`. Player names are not swear-filtered.
- **Validation.** `count` 1–6 (default 2); `level` and hand entries are strings ≤ 64; `hand` ≤ 16 entries (the relay
  does not know the level's cap; the client enforces it); `password` ≤ 64, empty = none; `chat` text is trimmed, 1–200.
  Bad input → `error bad_request`. Being in a room already and sending `create`/`join` → `bad_request` (leave first).
- **Errors on host actions.** Non-host → `not_host`; `set_level`/`set_count`/`start` after the match started → `started`;
  `start` with someone not Ready → `bad_request` ("not everyone is ready"). `ready`/`set_hand` after start → `started`.
  `kick` works before and during a match (during a match it acts like that player leaving: `player_left`).
- **set_count lowering.** The last joined players are removed until players ≤ count; each gets `kicked`, then `rooms`.
  `set_count` also resets Ready (raising too).
- **match_start.** `seed` is a random int in [0, 2^31-1). `shared_pool` comes from `data/coop.json` read at start:
  either `{ "<level id>": true }`, `{ "<level id>": { "shared_pool": true } }`, or the same under a `"levels"` key; missing
  file or level = `false`. After `match_start` the relay also sends the `room` state with `started: true`. A started room
  never goes back to the lobby state (v1 has no "match over" message); it closes when the last player leaves.
- **cmd.** Needs integer `round`, integer `seq`, object `cmd`, else `bad_request`. Commands from a player who is not in a
  started room are dropped silently. The relay does not check turn order or `seq`.
- **checksum.** `hash` is a string (≤ 64) or a number; compared as strings. A round is checked once every player present
  has sent theirs; a player leaving re-checks pending rounds without them. Equal → nothing is sent. `desync.hashes` holds
  only the players present. At most 64 rounds are kept pending per room.
- **Ping.** `{"t":"ping"}` every 20 s to every client that said hello; any `pong` resets the counter. A client is dropped
  (socket terminated) at the first ping tick after 3 unanswered pings, i.e. 60–80 s of silence. Clients should answer
  each ping at once; nginx closes idle sockets after 3600 s, which pings prevent.
- **Leaving.** Socket close = `leave`. In a started room the others get `player_left`, then `room`. Empty rooms are deleted.
- **Limits.** Frames ≤ 64 KiB (bigger closes the socket, code 1009); about 30 messages/s per client (burst 60), more
  closes with code `4008`; 500 connections max. Text frames only; binary frames → `bad_request`.
- **Close codes.** `4001` no hello first / hello timeout, `4002` version not accepted, `4008` flooding.
