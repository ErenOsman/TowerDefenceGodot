class_name TestCase
extends RefCounted
## Base class of every test script in res://tests/test_*.gd. The runner (tests/run.gd) instantiates the
## script, calls setup() before and teardown() after every method whose name starts with "test_", and
## counts the failures the assert_* helpers record. A failed assertion never stops the test method.

var _failures: Array[String] = []
var _current := ""

func setup() -> void: pass
func teardown() -> void: pass

func fail(msg: String) -> void:
	_failures.append("%s: %s" % [_current, msg])

func assert_true(cond: bool, msg := "") -> void:
	if not cond: fail("expected true. " + msg)

func assert_false(cond: bool, msg := "") -> void:
	if cond: fail("expected false. " + msg)

func assert_eq(actual, expected, msg := "") -> void:
	if not _same(actual, expected):
		fail("expected %s, got %s. %s" % [_fmt(expected), _fmt(actual), msg])

func assert_ne(actual, not_expected, msg := "") -> void:
	if _same(actual, not_expected):
		fail("expected something other than %s. %s" % [_fmt(not_expected), msg])

func assert_null(v, msg := "") -> void:
	if v != null: fail("expected null, got %s. %s" % [_fmt(v), msg])

func assert_not_null(v, msg := "") -> void:
	if v == null: fail("expected a value, got null. " + msg)

## Numbers (Num = float): exact after Num.fix, so == is right; still allow a tiny tolerance.
func assert_num(actual, expected, msg := "") -> void:
	if actual == null or absf(float(actual) - float(expected)) > 1e-7:
		fail("expected %s, got %s. %s" % [_fmt(expected), _fmt(actual), msg])

## Arrays compared element by element (order matters).
func assert_seq(actual: Array, expected: Array, msg := "") -> void:
	if actual.size() != expected.size():
		fail("expected %d items %s, got %d items %s. %s" % [expected.size(), _fmt(expected), actual.size(), _fmt(actual), msg])
		return
	for i in actual.size():
		if not _same(actual[i], expected[i]):
			fail("item %d: expected %s, got %s. %s" % [i, _fmt(expected[i]), _fmt(actual[i]), msg])
			return

## Same items in any order.
func assert_set(actual: Array, expected: Array, msg := "") -> void:
	var a := actual.duplicate(); var e := expected.duplicate()
	for x in e:
		var i := a.find(x)
		if i < 0: fail("missing %s in %s. %s" % [_fmt(x), _fmt(actual), msg]); return
		a.remove_at(i)
	if not a.is_empty(): fail("unexpected %s. %s" % [_fmt(a), msg])

func assert_contains(container, item, msg := "") -> void:
	if container == null or not container.has(item):
		fail("expected %s to contain %s. %s" % [_fmt(container), _fmt(item), msg])

func assert_not_contains(container, item, msg := "") -> void:
	if container != null and container.has(item):
		fail("expected %s not to contain %s. %s" % [_fmt(container), _fmt(item), msg])

func _same(a, b) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) <= 1e-7
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _same(a[i], b[i]): return false
		return true
	return a == b

func _fmt(v) -> String:
	if v is String: return '"%s"' % v
	return str(v)
