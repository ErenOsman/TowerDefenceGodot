class_name ArtPaths
extends RefCounted
## Maps the content's Unity asset paths to this project's res:// files (pure string rules; GameApp loads
## and caches the resources). "" when a path has no Godot counterpart.
##   Assets/Art/Icons/Abilities/Shoot.png#Shoot          → res://art/icons/Abilities/Shoot.png
##   Assets/Art/UI/KitB/buttons/btn_x.png#btn_x          → res://art/ui/KitB/buttons/btn_x.png
##   Assets/Art/Models/Archer/Archer Blender.prefab      → res://art/models/Archer.fbx
##   Assets/Art/Models/Map Kit/Ground A.fbx              → res://art/tiles/Ground A.fbx
##   Assets/Art/Fonts/Nunito-Bold SDF.asset              → res://art/fonts/Nunito-Bold.ttf
##   Assets/…/battle.mp3 (any audio clip)                → res://art/music/battle.mp3

## The path without a sprite suffix ("…/X.png#X" → "…/X.png") and surrounding spaces.
static func strip(unity_path: String) -> String:
	var p := unity_path.strip_edges()
	var hash := p.find("#")
	return p.substr(0, hash) if hash >= 0 else p

## The icon PNG for an "Assets/Art/Icons/…" reference.
static func icon(unity_path: String) -> String:
	var p := strip(unity_path)
	if p.begins_with("Assets/Art/Icons/"): return "res://art/icons/" + p.substr("Assets/Art/Icons/".length())
	if p.begins_with("res://"): return p
	return ""

## A KitB sprite ("Assets/Art/UI/KitB/<group>/<name>.png"), or any other "Assets/Art/UI/…" sprite under res://art/ui/.
static func kit(unity_path: String) -> String:
	var p := strip(unity_path)
	if p.begins_with("Assets/Art/UI/"): return "res://art/ui/" + p.substr("Assets/Art/UI/".length())
	if p.begins_with("res://"): return p
	return ""

## Any 2D sprite reference (icons or UI sprites).
static func sprite(unity_path: String) -> String:
	var p := icon(unity_path)
	return p if p != "" else kit(unity_path)

## A unit/projectile/prop view ("Assets/Art/Models/<Unit>/<Unit> Blender.prefab") or map kit piece.
static func model(view_path: String) -> String:
	var p := strip(view_path)
	if p.begins_with("res://"): return p
	if not p.begins_with("Assets/Art/Models/"): return ""
	var rest := p.substr("Assets/Art/Models/".length())
	var file := rest.get_file().get_basename()
	if rest.begins_with("Map Kit/"): return "res://art/tiles/%s.fbx" % file
	if file.ends_with(" Blender"): file = file.substr(0, file.length() - " Blender".length())
	return "res://art/models/%s.fbx" % file

## Where a Camp prop model would be (res://art/camp/<name>.fbx).
static func camp(name: String) -> String:
	return "res://art/camp/%s.fbx" % name

## A unit's bust render.
static func portrait(unit_name: String) -> String:
	return "res://art/portraits/%s.png" % unit_name

## A TextMeshPro font asset → the TTF it was made from.
static func font(unity_path: String) -> String:
	var p := strip(unity_path)
	if p.begins_with("res://"): return p
	var file := p.get_file().get_basename()
	if file.ends_with(" SDF"): file = file.substr(0, file.length() - 4)
	return "res://art/fonts/%s.ttf" % file if file != "" else ""

## A music clip: a bare name ("battle") or any Unity audio path ("Assets/Audio/Music/battle.mp3").
static func music(name_or_path: String) -> String:
	var p := strip(name_or_path)
	if p == "": return ""
	if p.begins_with("res://"): return p
	return "res://art/music/%s.mp3" % p.get_file().get_basename()
