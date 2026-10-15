class_name ArtPaths
extends RefCounted
## Maps the content's art paths to this project's res:// files (pure string rules; GameApp loads and caches the
## resources). "" when a path has no Godot counterpart. The content's canonical form is repo-relative
## (docs/Content.md "Art paths": "art/icons/Abilities/Shoot.png", "art/models/Archer.fbx", "vfx/Hit Spark") and
## passes through as "res://" + path. The old Unity form is still read (the oracle's content copy, old drafts):
##   Assets/Art/Icons/Abilities/Shoot.png#Shoot          → res://art/icons/Abilities/Shoot.png
##   Assets/Art/UI/KitB/buttons/btn_x.png#btn_x          → res://art/ui/KitB/buttons/btn_x.png
##   Assets/Art/Models/Archer/Archer Blender.prefab      → res://art/models/Archer.fbx
##   Assets/Art/Models/Map Kit/Ground A.fbx              → res://art/tiles/Ground A.fbx
##   Assets/Art/Fonts/Nunito-Bold SDF.asset              → res://art/fonts/Nunito-Bold.ttf
##   Assets/…/battle.mp3 (any audio clip)                → res://art/music/battle.mp3

## A canonical repo-relative art path ("art/…") as a res:// path, else "".
static func _canon(p: String, folders: Array) -> String:
	if not p.begins_with("art/"): return ""
	for f in folders:
		if p.begins_with("art/%s/" % f): return "res://" + p
	return ""

## Any art path in either form → its res:// file (icons, UI sprites, models, tiles, fonts, music, sfx); "" for
## none and for VFX kit names ("vfx/…": VfxKit.effect_name resolves those).
static func resolve(path: String) -> String:
	var p := strip(path)
	if p == "" or p.begins_with("vfx/"): return ""
	if p.begins_with("res://"): return p
	if p.begins_with("art/"): return "res://" + p
	if p.begins_with("Assets/Art/Icons/"): return icon(p)
	if p.begins_with("Assets/Art/UI/"): return kit(p)
	if p.begins_with("Assets/Art/Models/"): return model(p)
	if p.begins_with("Assets/Art/VFX/Placeholder/"): return "res://art/models/%s.fbx" % p.get_file().get_basename()
	if p.begins_with("Assets/Art/Fonts/"): return font(p)
	if p.begins_with("Assets/Audio/") or p.get_extension().to_lower() in ["mp3", "wav", "ogg"]: return music(p)
	return ""

## The path without a sprite suffix ("…/X.png#X" → "…/X.png") and surrounding spaces.
static func strip(unity_path: String) -> String:
	var p := unity_path.strip_edges()
	var hash := p.find("#")
	return p.substr(0, hash) if hash >= 0 else p

## The icon PNG for an "Assets/Art/Icons/…" reference.
static func icon(unity_path: String) -> String:
	var p := strip(unity_path)
	if p.begins_with("art/"): return _canon(p, ["icons"])
	if p.begins_with("Assets/Art/Icons/"): return "res://art/icons/" + p.substr("Assets/Art/Icons/".length())
	if p.begins_with("res://"): return p
	return ""

## A KitB sprite ("Assets/Art/UI/KitB/<group>/<name>.png"), or any other "Assets/Art/UI/…" sprite under res://art/ui/.
static func kit(unity_path: String) -> String:
	var p := strip(unity_path)
	if p.begins_with("art/"): return _canon(p, ["ui"])
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
	if p.begins_with("art/"): return _canon(p, ["models", "tiles", "camp", "guild"])
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
	if p.begins_with("art/fonts/"): return "res://" + p
	var file := p.get_file().get_basename()
	if file.ends_with(" SDF"): file = file.substr(0, file.length() - 4)
	return "res://art/fonts/%s.ttf" % file if file != "" else ""

## A music clip: a bare name ("battle"), "art/music/battle.mp3" or any Unity audio path ("Assets/Audio/Music/battle.mp3").
static func music(name_or_path: String) -> String:
	var p := strip(name_or_path)
	if p == "": return ""
	if p.begins_with("res://"): return p
	if p.begins_with("art/music/"): return "res://" + p
	return "res://art/music/%s.mp3" % p.get_file().get_basename()
