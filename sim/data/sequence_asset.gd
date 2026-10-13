class_name SequenceAsset
extends ContentAsset
## A sequence of speech-bubble lines (Tutorial, First Run & Sequences — Design): a level's intro, the
## tutorial's steps. Each line says who speaks, what ({player} = the player's name), what the
## bubble points at, and when it continues (a click, after some seconds, or a game event).

## Hidden content number (1, 2, 3… per asset type); players never see it.
var number: int = 0

## Array of SequenceLine.
var lines: Array = []
