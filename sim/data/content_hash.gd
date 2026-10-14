class_name ContentHash
extends RefCounted
## The co-op game version (docs/COOP-PROTOCOL.md, `version`): SHA-256 over the content JSON files' bytes,
## concatenated in ordinal file-name order, followed by the protocol version string; the first 16 hex digits.
## Two clients may only meet in a room when their hashes match (Multiplayer — Design, content match).
## Godot-only (no C# counterpart). Uses HashingContext (engine hashing, no Node/Resource).

const Protocol := "coop-1"

## The hash of the content folder (every *.json in it, sorted by name) and of the Godot-only overlay folder
## (ContentFiles.OverlayFolder: Workshop forms, tokens and drops), whose files sort as "content-godot/<name>" after
## the content's, so both clients must have the same overlay too. A missing or empty overlay adds nothing.
static func compute(folder: String = ContentFiles.Folder, overlay: String = ContentFiles.OverlayFolder) -> String:
	var files := _files_of(folder, "")
	if overlay != "" and DirAccess.dir_exists_absolute(overlay):
		files.append_array(_files_of(overlay, overlay.get_file() + "/"))
	return of_files(files)

static func _files_of(folder: String, prefix: String) -> Array:
	var names := []
	for f in DirAccess.get_files_at(folder):
		if f.ends_with(".json"): names.append(f)
	names.sort() # ordinal
	var files := []
	for f in names: files.append([prefix + f, FileAccess.get_file_as_bytes(folder.path_join(f))])
	return files

## The hash of files given as [file name, PackedByteArray] pairs (sorted by name here).
static func of_files(files: Array) -> String:
	var sorted := files.duplicate()
	sorted.sort_custom(func(a, b): return a[0] < b[0])
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for f in sorted:
		var bytes: PackedByteArray = f[1]
		if bytes.size() > 0: ctx.update(bytes)
	ctx.update(Protocol.to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 16)
