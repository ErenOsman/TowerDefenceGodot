extends TestCase
## Port of AbilityTextTests.cs. AbilityText: the numbers info panels show (range, area, power, speed), evaluated for a caster.

var vocab: Vocabulary

func setup() -> void:
	vocab = CombatVocabulary.create()

static func _archer() -> EntityDef:
	var d := EntityDef.new()
	d.name = "Archer"
	return d.stat("MaxHp", 20).stat("Speed", 2)

static func _shoot() -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Shoot"
	a.cooldown = 1
	a.targeting = PatternDef.diamond("2")
	var atk := AttackStep.new()
	atk.area = PatternDef.ray()
	atk.power = Formula.new("10")
	a.steps = [atk]
	return a

static func _walk() -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Walk"
	a.targeting = PatternDef.steps("Self.Speed")
	a.steps = [WalkStep.new()]
	return a

func test_abilities_read_range_area_power_and_cooldown() -> void:
	var me := DefStats.new(_archer())
	assert_eq(AbilityText.summary(_shoot(), me, vocab), "Range 2 · Hits the first in line · Damage 10 · Cooldown 1") # cooldown 1 = every turn
	assert_eq(AbilityText.summary(_walk(), me, vocab), "Moves up to 2 tiles", "Self.Speed evaluated for the caster")

	var fireball := AbilityDef.new()
	fireball.name = "Fireball"
	fireball.targeting = PatternDef.diamond("6", "2")
	var atk := AttackStep.new()
	atk.area = PatternDef.circle("1")
	atk.power = Formula.new("100")
	atk.hits = Formula.new("2")
	fireball.steps = [atk]
	assert_eq(AbilityText.summary(fireball, me, vocab), "Range 2–6 · Area: Circle 1 · Damage 100 ×2")

func test_entities_read_their_strongest_attack_and_speed() -> void:
	var archer := _archer()
	archer.abilities.append(_walk())
	archer.abilities.append(_shoot())
	var me := DefStats.new(archer)
	assert_num(AbilityText.best_power(archer.abilities, me, vocab), 10)
	assert_num(AbilityText.speed(me, vocab), 2)

	var wall := EntityDef.new()
	wall.name = "Wall"
	wall.stat("MaxHp", 50)
	assert_null(AbilityText.best_power(wall.abilities, DefStats.new(wall), vocab), "no attacks")
	assert_null(AbilityText.speed(DefStats.new(wall), vocab), "no speed")

func test_a_formula_that_needs_a_target_shows_as_text() -> void:
	var smite := AbilityDef.new()
	smite.name = "Smite"
	smite.targeting = PatternDef.diamond("1")
	var atk := AttackStep.new()
	atk.power = Formula.new("Target.MaxHp * 0.5")
	smite.steps = [atk]
	assert_eq(AbilityText.power(smite, DefStats.new(_archer()), vocab), "Target.MaxHp * 0.5")
