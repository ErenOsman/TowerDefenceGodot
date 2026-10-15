#!/usr/bin/env python3
"""The content file layout (data/content/*.json), as Unity's MiniJson.Write laid it out: two-space indent, keys in
order, small objects of plain values on one line (<= 120 chars), short lists of plain values on one line (<= 8 items,
<= 100 chars), lists of short lists (tile positions) several to a line, UTF-8 without escapes, one final newline.
Writers of data/content (the wiki's Content Editor, tools, hand edits) use it so diffs stay small; docs/CONTENT.md.

  python3 tools/content_format.py            reformat every data/content/*.json in place
  python3 tools/content_format.py --check    exit 1 and list the files that are not in this layout
  import: sys.path.insert(0, "<project>/tools"); import content_format; content_format.save(path, data)
"""
import json
import os
import sys


def _num(d):
    if isinstance(d, bool):
        return "true" if d else "false"
    if isinstance(d, int):
        return str(d)
    if abs(d - round(d)) < 1e-9 and abs(d) < 1e15:
        return str(int(round(d)))
    return repr(d)


def _str(s):
    out = ['"']
    for c in s:
        if c == '"': out.append('\\"')
        elif c == '\\': out.append('\\\\')
        elif c == '\n': out.append('\\n')
        elif c == '\r': out.append('\\r')
        elif c == '\t': out.append('\\t')
        elif ord(c) < 0x20: out.append('\\u%04x' % ord(c))
        else: out.append(c)
    out.append('"')
    return ''.join(out)


def _plain(v):
    return v is None or isinstance(v, (str, bool, int, float))


def _ulen(s):  # C# string length (UTF-16 code units)
    return len(s.encode('utf-16-le')) // 2


def _inline_len(lst):
    return sum(_ulen(_w(v, 0)) + 2 for v in lst)


def _small(v):
    return _plain(v) or (isinstance(v, list) and len(v) <= 8 and all(_plain(x) for x in v) and _inline_len(v) <= 100)


def _w(v, ind):
    if v is None: return "null"
    if isinstance(v, str): return _str(v)
    if isinstance(v, (bool, int, float)): return _num(v)
    if isinstance(v, dict):
        if not v: return "{}"
        if all(_small(x) for x in v.values()):
            line = "{ " + ", ".join(_str(k) + ": " + _w(x, ind) for k, x in v.items()) + " }"
            if _ulen(line) <= 120: return line
        parts = ["{\n"]
        items = list(v.items())
        for i, (k, x) in enumerate(items):
            parts.append("  " * (ind + 1) + _str(k) + ": " + _w(x, ind + 1) + ("," if i < len(items) - 1 else "") + "\n")
        parts.append("  " * ind + "}")
        return "".join(parts)
    if isinstance(v, list):
        if not v: return "[]"
        if len(v) <= 8 and all(_plain(x) for x in v) and _inline_len(v) <= 100:
            return "[" + ", ".join(_w(x, ind) for x in v) + "]"
        if all(isinstance(x, list) and len(x) <= 4 and all(_plain(y) for y in x) for x in v):
            sb = ["[\n"]; line = ""; first = True
            for item in v:
                part = _w(item, ind + 1)
                if line and _ulen(line) + _ulen(part) + 2 > 100:
                    if not first: sb.append(",\n")
                    sb.append("  " * (ind + 1) + line); first = False; line = ""
                if line: line += ", "
                line += part
            if not first: sb.append(",\n")
            sb.append("  " * (ind + 1) + line + "\n" + "  " * ind + "]")
            return "".join(sb)
        parts = ["[\n"]
        for i, x in enumerate(v):
            parts.append("  " * (ind + 1) + _w(x, ind + 1) + ("," if i < len(v) - 1 else "") + "\n")
        parts.append("  " * ind + "]")
        return "".join(parts)
    return _str(str(v))


def dumps(v):
    return _w(v, 0) + "\n"


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def save(path, v):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(dumps(v))


def main(argv):
    check = "--check" in argv
    folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "content")
    files = [a for a in argv if not a.startswith("--")] or sorted(
        os.path.join(folder, f) for f in os.listdir(folder) if f.endswith(".json"))
    bad = []
    for f in files:
        with open(f, encoding="utf-8") as fh:
            text = fh.read()
        out = dumps(json.loads(text))
        if out != text:
            bad.append(f)
            if not check:
                with open(f, "w", encoding="utf-8", newline="\n") as fh:
                    fh.write(out)
    for f in bad:
        print(("not in the content layout: " if check else "reformatted: ") + os.path.relpath(f))
    return 1 if check and bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
