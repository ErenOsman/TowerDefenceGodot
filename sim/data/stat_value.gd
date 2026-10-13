class_name StatValue
extends RefCounted
## One base stat of an entity. The value is text so decimals stay exact (no float).

var stat: String = ""
var value: String = "0"

static func of(p_stat: String, p_value: String) -> StatValue:
	var s := StatValue.new()
	s.stat = p_stat
	s.value = p_value
	return s
