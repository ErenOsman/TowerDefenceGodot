class_name PlayerProfile
extends RefCounted
## The player's profile in the save: their name, the tutorial's state and the level intros already
## seen. A save without a created profile is a first launch (the Welcome screen creates it); a save
## from before profiles existed is adopted as already past the tutorial.

const MaxNameLength := 16
const DefaultName := "Commander"

## False until the Welcome screen (or an older save) creates the profile.
var created: bool = false
var player_name: String = ""
var tutorial: int = TutorialState.NotStarted
## The Camp's first visit (its welcome) has happened (Camp & Chapters — Design).
var camp_seen: bool = false
## The Guild's first visit (its welcome card) has happened (Missions & Guild — Design). Godot-first.
var guild_seen: bool = false
## The Camp's second mini tour (the Guild and Workshop buttons, shown once after Chapter 2) has happened. Godot-first.
var guild_tour_seen: bool = false
## Level ids whose intro sequence has played, and meet_key(entity id) for entrance lines heard.
var seen_intros: Array = []

## No profile yet: the game shows the Welcome screen.
var is_first_run: bool:
	get: return not created

## The tutorial has been neither finished nor skipped.
var tutorial_pending: bool:
	get: return created and tutorial == TutorialState.NotStarted

## A name as the profile keeps it: trimmed, at most MaxNameLength characters, DefaultName when empty.
static func clean_name(raw: String) -> String:
	var n := raw.strip_edges()
	if n.length() > MaxNameLength: n = n.substr(0, MaxNameLength).strip_edges(false, true)
	return DefaultName if n.length() == 0 else n

## Creates the profile for a new player (the tutorial still ahead).
func create(n: String) -> void:
	created = true
	player_name = clean_name(n)
	tutorial = TutorialState.NotStarted

## Adopts a save made before profiles existed: created, a default name, the tutorial counted as
## skipped, so existing players never see the Welcome screen. Returns whether it changed anything.
func adopt_existing_save() -> bool:
	if created: return false
	created = true
	if player_name == "": player_name = DefaultName
	tutorial = TutorialState.Skipped
	return true

## The seen_intros key of a unit's entrance lines (kept apart from level ids).
static func meet_key(entity_id: String) -> String:
	return "meet:" + entity_id

func has_seen_intro(level_id: String) -> bool:
	return seen_intros.has(level_id)

## Records that a level's intro played; returns false when it already had.
func mark_intro_seen(level_id: String) -> bool:
	if level_id == "" or has_seen_intro(level_id): return false
	seen_intros.append(level_id)
	return true
