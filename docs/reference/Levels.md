<!-- Generated from the game content (Tools > Docs > Export Game Reference, or Tools/Offline/offline.sh docs). Do not edit by hand: change the content and export again. -->

# Levels

Map legend: `.` ground, `+` build tile, `#` wall, `~` chasm, `B` base, `1` `2`… the roads (by number), `S` where a road starts. Rows are numbered on the left (0 is the bottom row), columns underneath.

## Tutorial

### First Defence

Slimes are coming down the road. Place your Archer near the base and stop them.

<sub>Source: `Assets/Data/Levels/Tutorial/Tutorial.asset` (`Content/Levels.json` → `Levels/Tutorial/Tutorial`)</sub>

- Energy: **100** at the start, **+0** each round
- Hand: its own: Archer · map 12×5 · 1 road · 2 waves
- Unlocks: the first launch (not listed in level select)
- First clear gives: Archer (skipping the tutorial gives it too)
- Intro: 12 lines (`Tutorial Steps`), the first time it is played
- ID `tutorial`

```text
 4 . . . . . . . . . + + +
 3 . . . . . . . . . + + +
 2 S 1 1 1 1 1 1 1 1 1 1 B
 1 . . . . . . . . . + + +
 0 . . . . . . . . . + + +
                       1 1
   0 1 2 3 4 5 6 7 8 9 0 1
```

**Wave 1: One Slime** (starts round 1)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Slime | 1 |

**Wave 2: A Slime and a Runner** (starts after wave 1 is cleared)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Slime | 1 |
| 2 | Runner | 1 |

## Chapter 1

### 1. First Steps

Slimes walk one road to your base, and a Big Slime takes several arrows. Place archers beside it.

<sub>Source: `Assets/Data/Levels/Chapter 1/1 First Steps.asset` (`Content/Levels.json` → `Levels/Chapter 1/1 First Steps`)</sub>

- Energy: **200** at the start, **+20** each round
- Hand: up to **4** towers · map 10×5 · 1 road · 3 waves
- Unlocks: open from the start
- First clear gives: Guardian
- ID `chapter1-1`

```text
 4 . . . . . . . + + +
 3 . . . # . . . + + +
 2 S 1 1 1 1 1 1 1 1 B
 1 . . . . . . # + + +
 0 . . . . . . . + + +
   0 1 2 3 4 5 6 7 8 9
```

**Wave 1: The first slimes** (starts round 1)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Slime | 1 |
| 2 | Slime | 1 |

**Wave 2: A big one** (starts round 4)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Slime | 1 |
| 2 | Big Slime | 1 |

**Wave 3: All together** (starts round 7)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Big Slime | 1 |
| 2 | Slime | 1 |
| 3 | Big Slime | 1 |

### 2. Spitters

Slime Archers stop where they can spit at your towers. Keep your towers healthy.

<sub>Source: `Assets/Data/Levels/Chapter 1/2 Spitters.asset` (`Content/Levels.json` → `Levels/Chapter 1/2 Spitters`)</sub>

- Energy: **200** at the start, **+20** each round
- Hand: up to **4** towers · map 11×6 · 1 road · 3 waves
- Unlocks: win First Steps
- First clear gives: Mage
- ID `chapter1-2`

```text
 5 . . . # . . . . + + +
 4 . . . . . 1 1 1 1 1 B
 3 . . # . . 1 . . + + +
 2 . . . . . 1 . . # + +
 1 S 1 1 1 1 1 . . . . .
 0 . . . . . . . . . . .
                       1
   0 1 2 3 4 5 6 7 8 9 0
```

**Wave 1: Spitters** (starts round 1)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Big Slime | 1 |
| 2 | Slime Archer | 1 |
| 3 | Runner | 1 |

**Wave 2: More spitters** (starts round 5)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Slime Archer | 1 |
| 2 | Big Slime | 1 |
| 3 | Slime Archer | 1 |
| 4 | Runner | 1 |

**Wave 3: Cover fire** (starts round 10)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Runner | 1 |
| 2 | Slime Archer | 1 |
| 3 | Big Slime | 1 |
| 4 | Slime Archer | 1 |
| 5 | Runner | 1 |

### 3. Two Roads

Two roads meet at the base, and Shield Slimes soak up your first shots.

<sub>Source: `Assets/Data/Levels/Chapter 1/3 Two Roads.asset` (`Content/Levels.json` → `Levels/Chapter 1/3 Two Roads`)</sub>

- Energy: **200** at the start, **+25** each round
- Hand: up to **4** towers · map 12×5 · 2 roads · 3 waves
- Unlocks: win Spitters
- First clear gives: Priest
- ID `chapter1-3`

```text
 4 S 1 1 1 1 1 1 1 1 1 1 1
 3 . . . . . . . . . + + 1
 2 . . . . # . . . # + + B
 1 . . . . . . . . . + + 2
 0 S 2 2 2 2 2 2 2 2 2 2 2
                       1 1
   0 1 2 3 4 5 6 7 8 9 0 1
```

**Wave 1: Both roads** (starts round 1)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Slime | 1 |
| 2 | Slime | 2 |
| 3 | Shield Slime | 1 |

**Wave 2: Shields** (starts round 5)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Shield Slime | 2 |
| 2 | Runner | 1 |
| 3 | Slime Archer | 2 |
| 4 | Slime | 1 |

**Wave 3: Pincer** (starts round 10)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Slime Archer | 1 |
| 2 | Shield Slime | 2 |
| 3 | Runner | 1 |
| 4 | Shield Slime | 2 |
| 5 | Slime Archer | 1 |

### 4. The Slime King

Brutes smash the towers ahead of them, and then the Slime King arrives.

<sub>Source: `Assets/Data/Levels/Chapter 1/4 The Slime King.asset` (`Content/Levels.json` → `Levels/Chapter 1/4 The Slime King`)</sub>

- Energy: **200** at the start, **+25** each round
- Hand: up to **4** towers · map 12×6 · 1 road · 3 waves
- Unlocks: win Two Roads
- First clear gives: Wisp
- ID `chapter1-4`

```text
 5 . . . . . . . . . . . .
 4 S 1 1 1 1 1 1 1 1 1 . #
 3 . . . . . . . . . 1 + +
 2 . . . # . . # . . 1 + +
 1 . . . . . . . . . 1 1 B
 0 . . . . . . . . . + + +
                       1 1
   0 1 2 3 4 5 6 7 8 9 0 1
```

**Wave 1: Vanguard** (starts round 1)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Slime | 1 |
| 2 | Runner | 1 |
| 3 | Slime Archer | 1 |
| 4 | Shield Slime | 1 |

**Wave 2: Brutes** (starts round 6)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Brute | 1 |
| 2 | Shield Slime | 1 |
| 3 | Slime Archer | 1 |
| 4 | Brute | 1 |

**Wave 3: The Slime King** (starts round 11)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Shield Slime | 1 |
| 2 | Slime King | 1 |
| 3 | Brute | 1 |

## Chapter 2

### 1. Rock Garden

Two rows of rocks cut the field. Rabbits hop over them; Rockjaws eat their way through.

<sub>Source: `Assets/Data/Levels/Chapter 2/1 Rock Garden.asset` (`Content/Levels.json` → `Levels/Chapter 2/1 Rock Garden`)</sub>

- Energy: **400** at the start, **+40** each round
- Hand: up to **5** towers · map 14×7 · 1 road · 3 waves
- Unlocks: win The Slime King
- First clear gives: Ballista
- Starting units: Rock (neutral) at (6, 0), Rock (neutral) at (7, 0), Rock (neutral) at (6, 1), Rock (neutral) at (7, 1), Rock (neutral) at (6, 2), Rock (neutral) at (7, 2), Rock (neutral) at (6, 3), Rock (neutral) at (7, 3), Rock (neutral) at (6, 4), Rock (neutral) at (7, 4), Rock (neutral) at (6, 5), Rock (neutral) at (7, 5), Rock (neutral) at (6, 6), Rock (neutral) at (7, 6)
- ID `chapter2-1`

```text
 6 . . . . . . . . . . . . . .
 5 . . . . . . . . . . . + + +
 4 . . . . . . . . . . . + + +
 3 S 1 1 1 1 1 1 1 1 1 1 1 1 B
 2 . . . . . . . . . . . + + +
 1 . . . . . . . . . . . + + +
 0 . . . . . . . . . . . . . .
                       1 1 1 1
   0 1 2 3 4 5 6 7 8 9 0 1 2 3
```

**Wave 1: Hoppers** (starts round 1)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Rabbit | 1 |
| 2 | Rabbit | 1 |
| 3 | Rabbit | 1 |
| 4 | Rabbit | 1 |

**Wave 2: Rockjaw** (starts round 6)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Rockjaw | 1 |
| 2 | Rabbit | 1 |
| 3 | Slime | 1 |
| 4 | Rabbit | 1 |

**Wave 3: Jaws and Hops** (starts round 11)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Rockjaw | 1 |
| 2 | Jackalope | 1 |
| 3 | Rockjaw | 1 |
| 4 | Rabbit | 1 |
| 5 | Jackalope | 1 |

### 2. Three at the Gate

Three Brutes are already halfway down the road when you arrive.

<sub>Source: `Assets/Data/Levels/Chapter 2/2 Three at the Gate.asset` (`Content/Levels.json` → `Levels/Chapter 2/2 Three at the Gate`)</sub>

- Energy: **450** at the start, **+40** each round
- Hand: up to **5** towers · map 14×7 · 1 road · 3 waves
- Unlocks: win Rock Garden
- First clear gives: Alchemist
- Starting units: Brute (enemy) at (7, 3), Brute (enemy) at (6, 3), Brute (enemy) at (5, 3)
- ID `chapter2-2`

```text
 6 . . . . . . . . . . . . . .
 5 . . . . . . . . . . . + + +
 4 . . . . . . . . . . . + + +
 3 S 1 1 1 1 1 1 1 1 1 1 1 1 B
 2 . . . . . . . . . . . + + +
 1 . . . . . . . . . . . + + +
 0 . . . . . . . . . . . . . .
                       1 1 1 1
   0 1 2 3 4 5 6 7 8 9 0 1 2 3
```

**Wave 1: Stragglers** (starts round 1)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Slime | 1 |
| 2 | Runner | 1 |
| 3 | Slime Archer | 1 |
| 4 | Runner | 1 |

**Wave 2: Healers** (starts round 6)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Slime Shaman | 1 |
| 2 | Brute | 1 |
| 3 | Rabbit | 1 |
| 4 | Slime Shaman | 1 |

**Wave 3: Ironhide** (starts round 11)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Ironhide | 1 |
| 2 | Rabbit | 1 |
| 3 | Jackalope | 1 |

### 3. The Drummer

A drummer stands on your side: towers near the drum hit harder. Mind the chasm below.

<sub>Source: `Assets/Data/Levels/Chapter 2/3 The Drummer.asset` (`Content/Levels.json` → `Levels/Chapter 2/3 The Drummer`)</sub>

- Energy: **450** at the start, **+40** each round
- Hand: up to **5** towers · map 14×8 · 2 roads · 3 waves
- Unlocks: win Three at the Gate
- First clear gives: Drummer
- Starting units: Drummer (ally) at (10, 6)
- ID `chapter2-3`

```text
 7 . . . . . . . . . . + + + +
 6 . . . . . . . . . . + + + +
 5 . . 1 1 1 1 1 1 1 1 1 1 1 1
 4 . . 1 . . . # # . . + + + 1
 3 . . 1 . . . # # . . + + + 1
 2 S 1 1 . . . # # . . + + + B
 1 ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ 2
 0 S 2 2 2 2 2 2 2 2 2 2 2 2 2
                       1 1 1 1
   0 1 2 3 4 5 6 7 8 9 0 1 2 3
```

**Wave 1: Spitters** (starts round 1)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Slime Archer | 1 |
| 2 | Slime | 1 |
| 3 | Slime Archer | 1 |
| 4 | Slime Shaman | 1 |

**Wave 2: Brutes** (starts round 6)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Brute | 1 |
| 2 | Shield Slime | 1 |
| 3 | Ironhide | 1 |

**Wave 3: From the Chasm** (starts round 10)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Bat | 2 |
| 2 | Bat | 2 |
| 3 | Slime | 1 |
| 4 | Bat | 2 |
| 5 | Jackalope | 1 |
| 6 | Bat | 2 |

### 4. The Glutton

Three roads, one base. The strongest slimes come first, and then something that eats them.

<sub>Source: `Assets/Data/Levels/Chapter 2/4 The Glutton.asset` (`Content/Levels.json` → `Levels/Chapter 2/4 The Glutton`)</sub>

- Energy: **550** at the start, **+45** each round
- Hand: up to **5** towers · map 15×9 · 3 roads · 2 waves
- Unlocks: win The Drummer
- First clear gives: Cannon
- ID `chapter2-4`

```text
 8 S 2 2 2 2 2 2 2 2 2 2 2 2 2 2
 7 . . . . . . . . . . . . . . 2
 6 . . . . . . . . . . . . + + 2
 5 . . . . . . . . . . . . + + 2
 4 S 1 1 1 1 1 1 1 1 1 1 1 1 1 B
 3 . . . . . . . . . . . . + + 3
 2 . . . . . . . . . . . . + + 3
 1 . . . . . . . . . . . . . . 3
 0 S 3 3 3 3 3 3 3 3 3 3 3 3 3 3
                       1 1 1 1 1
   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4
```

**Wave 1: Vanguard** (starts round 1)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Ironhide | 1 |
| 2 | Big Slime | 2 |
| 3 | Slime Shaman | 3 |
| 4 | Brute | 2 |
| 5 | Ironhide | 3 |
| 6 | Shield Slime | 1 |
| 7 | Brute | 2 |
| 8 | Jackalope | 3 |

**Wave 2: The Glutton** (starts round 10)

| Wave round | What comes | Road |
|---|---|---|
| 1 | Slime Glutton | 1 |
