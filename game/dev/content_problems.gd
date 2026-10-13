class_name ContentProblems
extends RefCounted
## Validate All for the tools (ContentCheck, Tools > Combat > Validate All): loads the content JSON, runs
## ContentCheck (AssetValidator on every asset, tower IDs, the levels' look, conversions) and returns one row per
## finding with where it lives: {error, message, file, key, line, path}. Loading problems come first.

## Rows for the content in folder (res://data/content by default).
static func run(folder: String = ContentFiles.Folder) -> Array:
	return of_library(ContentLibrary.load(folder), folder)

static func of_library(lib: ContentLibrary, folder: String = ContentFiles.Folder) -> Array:
	var rows := []
	var texts := {}
	for p in lib.problems:
		var file := p.get_slice(":", 0)
		var key := p.get_slice(":", 1).strip_edges() if p.get_slice_count(":") > 2 else ""
		rows.append(_row(true, p, file, key, folder, texts))
	for f in ContentCheck.run(lib.all, ContentCheck.vocabulary_of(lib.rules)):
		var key = lib.key_of(f.asset)
		rows.append(_row(f.error, f.message, lib.file_of(f.asset), key if key is String else "", folder, texts))
	return rows

static func _row(error: bool, message: String, file: String, key: String, folder: String, texts: Dictionary) -> Dictionary:
	var path := folder.path_join(file) if file != "" else ""
	return {"error": error, "message": message, "file": file, "key": key, "path": path, "line": line_of(path, key, texts)}

## The 1-based line where an entry key starts in a content file (0 when not found). texts caches file texts.
static func line_of(path: String, key: String, texts: Dictionary = {}) -> int:
	if path == "" or key == "" or not FileAccess.file_exists(path): return 0
	if not texts.has(path): texts[path] = FileAccess.get_file_as_string(path)
	var text: String = texts[path]
	var at := text.find(JSON.stringify(key) + ":")
	if at < 0: at = text.find(JSON.stringify(key))
	return 0 if at < 0 else text.substr(0, at).count("\n") + 1

## "3 errors, 1 warning".
static func counts(rows: Array) -> String:
	var e := 0
	for r in rows:
		if r.error: e += 1
	var w := rows.size() - e
	return "%d error%s, %d warning%s" % [e, "" if e == 1 else "s", w, "" if w == 1 else "s"]
