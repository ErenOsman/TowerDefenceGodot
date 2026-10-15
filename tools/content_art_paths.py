#!/usr/bin/env python3
"""Rewrites the content's Unity-style art paths to the canonical repo-relative form (docs/Content.md "Art paths").

    python3 tools/content_art_paths.py            rewrite data/content/*.json in place (keeps the layout)
    python3 tools/content_art_paths.py --check    list what would change and any path that does not exist; no writes
    python3 tools/content_art_paths.py <dir>      the same for another content folder (a draft, a candidate dir)

The mapping (kept here as the record of the one-time migration; game/app/art_paths.gd still reads both forms):

    Assets/Art/Icons/<Group>/<Name>.png#<Name>        -> art/icons/<Group>/<Name>.png
    Assets/Art/UI/<path>.png#<name>                   -> art/ui/<path>.png        (KitB sprites; kit name = file name)
    Assets/Art/Models/Map Kit/<Name>.fbx              -> art/tiles/<Name>.fbx
    Assets/Art/Models/<Unit>/<Unit> Blender.prefab    -> art/models/<Unit>.fbx
    Assets/Art/VFX/Kit/<Effect>.prefab                -> vfx/<Effect>             (a VFX kit effect name, not a file)
    Assets/Art/VFX/Placeholder/<Name>.prefab          -> art/models/<Name>.fbx    (the projectile models)
    Assets/Art/Fonts/<Font> SDF.asset                 -> art/fonts/<Font>.ttf
    Assets/**/<clip>.mp3|.wav|.ogg (music)            -> art/music/<clip>.mp3
    Assets/**/<clip> (sounds: castSound/impactSound/hitSound) -> art/sfx/<clip>.ogg

Anything that is not an "Assets/Art/" or "Assets/Audio/" string (content keys, "Assets/Resources/GameCatalog.asset")
is left alone. Standard library only.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import content_format  # noqa: E402

SOUND_FIELDS = {"castSound", "impactSound", "hitSound"}
VFX_SPEC = os.path.join(ROOT, "game/level/vfx/effects.json")


def _base(p):
    return os.path.splitext(os.path.basename(p))[0]


def canonical(path, field=""):
    """The canonical form of one art path; the input unchanged when it is not a Unity art path."""
    p = path.strip()
    if not (p.startswith("Assets/Art/") or p.startswith("Assets/Audio/")):
        return path
    p = p.split("#", 1)[0]
    if field in SOUND_FIELDS:
        return "art/sfx/%s.ogg" % _base(p)
    if field == "music" or p.startswith("Assets/Audio/") or p.lower().endswith((".mp3", ".wav", ".ogg")):
        return "art/music/%s.mp3" % _base(p)
    if p.startswith("Assets/Art/Icons/"):
        return "art/icons/" + p[len("Assets/Art/Icons/"):]
    if p.startswith("Assets/Art/UI/"):
        return "art/ui/" + p[len("Assets/Art/UI/"):]
    if p.startswith("Assets/Art/Models/Map Kit/"):
        return "art/tiles/%s.fbx" % _base(p)
    if p.startswith("Assets/Art/Models/"):
        n = _base(p)
        if n.endswith(" Blender"):
            n = n[: -len(" Blender")]
        return "art/models/%s.fbx" % n
    if p.startswith("Assets/Art/VFX/Kit/"):
        return "vfx/" + _base(p)
    if p.startswith("Assets/Art/VFX/"):
        return "art/models/%s.fbx" % _base(p)
    if p.startswith("Assets/Art/Fonts/"):
        n = _base(p)
        if n.endswith(" SDF"):
            n = n[:-4]
        return "art/fonts/%s.ttf" % n
    return path


def _vfx_names():
    try:
        with open(VFX_SPEC, encoding="utf-8") as f:
            return {e["name"] for e in json.load(f).get("effects", [])}
    except (OSError, ValueError):
        return set()


def exists(path, vfx=None):
    """Whether a canonical path names something real: a file under the project, or a VFX kit effect."""
    if path.startswith("vfx/"):
        return path[4:] in (vfx if vfx is not None else _vfx_names())
    return os.path.isfile(os.path.join(ROOT, path))


def _walk(node, field, changes):
    if isinstance(node, dict):
        for k in list(node.keys()):
            v = node[k]
            if isinstance(v, str):
                n = canonical(v, k)
                if n != v:
                    node[k] = n
                    changes.append((k, v, n))
            else:
                _walk(v, k, changes)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            if isinstance(v, str):
                n = canonical(v, field)
                if n != v:
                    node[i] = n
                    changes.append((field, v, n))
            else:
                _walk(v, field, changes)


def main(argv):
    check = "--check" in argv
    dirs = [a for a in argv if not a.startswith("--")]
    folder = dirs[0] if dirs else os.path.join(ROOT, "data/content")
    vfx = _vfx_names()
    missing = []
    total = 0
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".json"):
            continue
        path = os.path.join(folder, name)
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        changes = []
        _walk(data, "", changes)
        if not changes:
            continue
        total += len(changes)
        per_field = {}
        for k, _, n in changes:
            per_field[k] = per_field.get(k, 0) + 1
            if not exists(n, vfx):
                missing.append("%s %s: %s" % (name, k, n))
        print("%-26s %4d  %s" % (name, len(changes), ", ".join("%s %d" % kv for kv in sorted(per_field.items()))))
        if not check:
            content_format.save(path, data)
    print("%d path(s) %s" % (total, "to rewrite" if check else "rewritten"))
    for m in sorted(set(missing)):
        print("MISSING " + m)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
