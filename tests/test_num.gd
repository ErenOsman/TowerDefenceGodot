extends TestCase
## Smoke test of the Num helpers and the runner itself.

func test_decimal_exactness() -> void:
	assert_eq(Num.add(0.1, 0.2), 0.3)
	assert_true(Num.add(0.1, 0.2) == 0.3)
	assert_eq(Num.mul(1.15, 100.0), 115.0)

func test_mod_and_div() -> void:
	assert_eq(Num.mod(-1.0, 3.0), 2.0)
	assert_eq(Num.mod(7.0, 0.0), 0.0)
	assert_eq(Num.div(1.0, 0.0), 0.0)
	assert_eq(Num.div(1.0, 4.0), 0.25)

func test_round_and_text() -> void:
	assert_eq(Num.round_of(2.5), 3.0)
	assert_eq(Num.round_of(-2.5), -3.0)
	assert_eq(Num.to_str(211.2), "211.2")
	assert_eq(Num.to_str(120.0), "120")
	assert_eq(Num.to_str(0.05), "0.05")
	assert_eq(Num.parse("1.15"), 1.15)
