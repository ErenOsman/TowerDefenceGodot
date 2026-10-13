class_name DefaultPresenters
extends IPresenterFactory
## The default presenter for every event type (Presenters.cs DefaultPresenters; Animation & Presentation — Design,
## Presenters). Views with a model play its clips through the rig (Attack / Cast with an impact moment, Hit, Die,
## Spawn, Walk) and fall back to tweens for what they lack; an ability's presentation asset adds its caster
## animation, projectile, VFX, sounds and camera shake.

## Emitted when an EnergyChanged event plays (the HUD's counter ticks): amount, energy after.
signal energy_ticked(amount: int, energy: int)
## Co-op with separate pools: an EnergyChanged event of one player's pool played (its Pool fact = the slot).
## These never fire energy_ticked (a plain level has no Pool fact).
signal pool_energy_ticked(slot: int, amount: int, energy: int)

const DAMAGE := OverlayStyle.FX_DAMAGE
const HEAL := OverlayStyle.FX_HEAL
const STATUS := OverlayStyle.FX_STATUS

## The kit's projectile models by presentation asset (the content names only Shoot's arrow): used when the
## presentation names no projectile and the attack is a Projectile or Lobbed shot.
const PROJECTILE_BY_PRESENTATION := {
	"Shoot Presentation": "Arrow", "Bolt Presentation": "Ballista Bolt", "Bombard Presentation": "Cannon Shell",
	"Spit Presentation": "Spit Glob", "Fireball Presentation": "Fire Orb", "Acid Flask Presentation": "Acid Flask",
	"Spark Presentation": "Wisp Spark", "Volley Presentation": "Arrow", "Pinning Shot Presentation": "Arrow",
}
## The trail each projectile model carries (VFX kit "... Trail" effects).
const TRAILS := {
	"Arrow": "Arrow Trail", "Ballista Bolt": "Arrow Trail", "Cannon Shell": "Cannon Trail", "Fire Orb": "Fire Orb Trail",
	"Acid Flask": "Acid Flask Trail", "Spit Glob": "Spit Trail", "Wisp Spark": "Wisp Spark Trail",
}

var views: EntityViews
var overlay: BattleOverlay
var state: GameState
var sounds: GameSounds
## A status ID → the name players see.
var status_name: Callable
## AbilityDef → AbilityPresentationAsset or null.
var presentation_of: Callable
## Shakes the camera (0–1).
var shake: Callable
## AbilityDef → whether the caster turns toward the aimed tile as it is cast.
var faces_aim: Callable
## Where effects and projectiles are added (the board).
var fx_parent: Node3D
## A model reference (Unity path or res://) → PackedScene or null.
var scene_of: Callable

func _init(p_views: EntityViews = null, p_overlay: BattleOverlay = null, p_state: GameState = null, p_fx_parent: Node3D = null) -> void:
	views = p_views
	overlay = p_overlay
	state = p_state
	fx_parent = p_fx_parent

## The presenter for an event (null when nothing is shown); its sound plays as the event starts.
func create(e: GameEvent, beat: BeatPlayback) -> IPresenter:
	var look: AbilityPresentationAsset = null
	if e.ability != null and e.ability.def != null and presentation_of.is_valid(): look = presentation_of.call(e.ability.def)
	if not _play_own_sound(e, look) and sounds != null: sounds.play(e)
	return _present(e, beat, look)

## The ability's own sounds replace the event defaults: cast on declare (and the attack it starts), hit on its damage.
static func _play_own_sound(e: GameEvent, look: AbilityPresentationAsset) -> bool:
	if look == null: return false
	match e.type:
		GameEventType.AbilityDeclared:
			if look.cast_sound == "": return false
			GameSounds.play_clip(look.cast_sound)
			return true
		GameEventType.AttackStarted:
			return look.cast_sound != ""
		GameEventType.DamageDealt:
			if look.hit_sound == "": return false
			GameSounds.play_clip(look.hit_sound)
			return true
	return false

func _timings() -> PresentationTimings:
	return PresentationTimings.get_timings()

func _view(id: int) -> EntityView:
	return views.get_view(id) if views != null else null

func _present(e: GameEvent, beat: BeatPlayback, look: AbilityPresentationAsset) -> IPresenter:
	match e.type:
		GameEventType.RoundStarted:
			return _banner("Round %d" % int(e.facts.get("Round", 0.0)), _timings().round_banner, "round")
		GameEventType.PhaseStarted:
			return _banner("Enemy phase", _timings().enemy_phase_banner, "phase") if str(e.detail) == "Enemy" else null
		GameEventType.WaveStarted:
			return _banner("%s begins" % str(e.detail), _timings().wave_banner)
		GameEventType.WaveFinished:
			return _banner("%s cleared" % str(e.detail), _timings().wave_banner)
		GameEventType.LevelMessage:
			return _banner(str(e.detail), _timings().message_banner)
		GameEventType.LevelWon:
			return SimplePresenter.new(1.0, func(): if overlay != null: overlay.banner("Victory", 1.0, true))
		GameEventType.LevelLost:
			return SimplePresenter.new(1.0, func(): if overlay != null: overlay.banner("Defeat", 1.0, true))
		GameEventType.EnergyChanged:
			var amount := int(e.facts.get("Amount", 0.0))
			var energy := int(e.facts.get("Energy", 0.0))
			if e.facts.has("Pool"): pool_energy_ticked.emit(int(e.facts["Pool"]), amount, energy)
			else: energy_ticked.emit(amount, energy)
			return null

		GameEventType.EntitySpawned, GameEventType.EntityResurrected:
			var spawned: EntityFrame = beat.frame.get_frame(e.target) if beat.frame != null else null
			if spawned == null or views == null: return null
			var v := views.ensure(spawned)
			if v.rig != null and v.rig.has(EntityRig.SPAWN):
				v.show_alive()
				v.set_team(spawned)
				v.place(e.to)
				v.face(spawned.facing)
				_fx(_timings().spawn_vfx, GridSpace.to_world(e.to, 0.4))
				return AnimatePresenter.new(v, EntityRig.SPAWN)
			return SpawnPresenter.new(views, spawned, e.to, _fx)
		GameEventType.EntityMoved:
			return _move(e)
		GameEventType.FacingChanged:
			var turner := _view(e.target)
			if turner == null: return null
			return SimplePresenter.new(0.1, func():
				var ent: Entity = state.get_entity(e.target) if state != null else null
				if ent != null and is_instance_valid(turner): turner.face(ent.facing))
		GameEventType.AbilityDeclared:
			var caster := _view(e.source)
			if caster == null: return null
			var def: AbilityDef = e.ability.def if e.ability != null else null
			var aim: Aim = e.ability.aim if e.ability != null else null
			var turn: bool = def != null and aim != null and faces_aim.is_valid() and faces_aim.call(def)
			var float_name := func():
				if not is_instance_valid(caster): return
				if turn: caster.face_point(GridSpace.to_world(aim.tile))
				if overlay != null: overlay.float_text(caster.head_position, def.display_name if def != null else str(e.detail), Color.WHITE, _timings().ability_name, 32)
			# abilities without an Attack step animate here; attacks animate at AttackStarted
			var trigger := ""
			if def != null and not _has_attack_step(def) and not def.tags.has(Tags.Movement): trigger = _trigger_for(def, look)
			if trigger == "" or caster.rig == null or not caster.rig.has(trigger):
				return SimplePresenter.new(0.25, float_name)
			return AnimatePresenter.new(caster, trigger, null,
				func():
					float_name.call()
					_fx(VfxKit.effect_name(look.cast_vfx) if look != null else "", _cast_at(caster, def), look),
				func(): _impact_effects(look, caster.world_position))
		GameEventType.AttackStarted:
			return _attack(e, look)
		GameEventType.HitResolved:
			var dodger := _view(e.target)
			if not e.fact("Hit") and dodger != null:
				return SimplePresenter.new(0.4, func(): if overlay != null and is_instance_valid(dodger): overlay.float_text(dodger.head_position, "Miss", Color.WHITE, -1.0, 40))
			return null
		GameEventType.DamageDealt:
			var v := _view(e.target)
			if v == null: return null
			var dmg := int(e.facts.get("FinalDamage", 0.0))
			var absorbed := int(e.facts.get("Absorbed", 0.0))
			var text := "(%d)" % dmg if absorbed > 0 and absorbed == dmg else str(dmg)
			var has_hit_clip := v.rig != null and v.rig.has(EntityRig.HIT)
			return HitPresenter.new(v, DAMAGE, 0.25, not has_hit_clip, func():
				if not is_instance_valid(v): return
				if overlay != null:
					overlay.float_text(v.head_position, text, DAMAGE, -1.0, 48)
					if dmg > 0: overlay.hurt(e.target)
				if not v.is_dead and v.rig != null: v.rig.play(EntityRig.HIT)
				_fx(VfxKit.effect_name(look.hit_vfx) if look != null else "", v.world_position + Vector3.UP * 0.4, look))
		GameEventType.Healed:
			var v := _view(e.target)
			if v == null: return null
			var amount := int(e.facts.get("Amount", 0.0))
			return HitPresenter.new(v, HEAL, 0.25, false, func():
				if overlay != null and is_instance_valid(v): overlay.float_text(v.head_position, "+%d" % amount, HEAL, -1.0, 48)
				if look != null and is_instance_valid(v): _fx(VfxKit.effect_name(look.hit_vfx), v.world_position + Vector3.UP * 0.4, look))
		GameEventType.StatusApplied, GameEventType.StatusRemoved:
			if e.tags.has(Tags.Hidden): return null
			var v := _view(e.target)
			var ent: Entity = state.get_entity(e.target) if state != null else null
			if v == null or (ent != null and ent.life == LifeState.Dead): return null
			var sign := "+" if e.type == GameEventType.StatusApplied else "−"
			var label: String = sign + (status_name.call(str(e.detail)) if status_name.is_valid() else str(e.detail))
			return SimplePresenter.new(0.2, func(): if overlay != null and is_instance_valid(v): overlay.float_text(v.head_position + Vector3.UP * 0.3, label, STATUS, -1.0, 30))
		GameEventType.Collision:
			var bumped := _view(e.target)
			if bumped == null: return null
			_fx(_timings().collision_vfx, bumped.world_position + Vector3.UP * 0.4)
			return HitPresenter.new(bumped, Color.WHITE, 0.15, true)
		GameEventType.EntityDied:
			var dying := _view(e.target)
			if dying == null: return null
			if dying.rig != null and dying.rig.has(EntityRig.DIE):
				return AnimatePresenter.new(dying, EntityRig.DIE, null, Callable(), Callable(), Callable(), func():
					if not is_instance_valid(dying): return
					dying.show_corpse()
					_fx(_timings().death_vfx, dying.world_position + Vector3.UP * 0.4))
			return DeathPresenter.new(dying, _fx)
		GameEventType.EntityRemoved:
			var leaving := _view(e.target)
			return RemovePresenter.new(views, leaving) if leaving != null else null
		GameEventType.TeamChanged:
			var turned := _view(e.target)
			var tf: EntityFrame = beat.frame.get_frame(e.target) if beat.frame != null else null
			if turned == null or tf == null: return null
			return SimplePresenter.new(0.1, func(): if is_instance_valid(turned): turned.set_team(tf))
	return null

## A banner that does not hold the playback: the overlay shows it for its time (after any banner already showing).
func _banner(text: String, seconds: float, kind = null) -> IPresenter:
	return SimplePresenter.new(0.0, func(): if overlay != null: overlay.banner(text, seconds, false, kind))

func _move(e: GameEvent) -> IPresenter:
	var v := _view(e.target)
	if v == null: return null
	match str(e.detail):
		"Jump": return MovePresenter.new(v, e.from, e.to, 0.35, 0.8, true)
		"Teleport": return TeleportPresenter.new(v, e.to)
		"Push", "Pull": return MovePresenter.new(v, e.from, e.to, 0.12, 0.0, false)
	return MovePresenter.new(v, e.from, e.to, 0.18, 0.0, true)

## An attack: the caster's Attack (or Cast) clip when its model has one — the delivery (projectile, beam) starts
## at the clip's impact — else the placeholder lunge or the delivery alone. The impact effects (VFX, sound,
## shake) play when the blow lands or the delivery arrives.
func _attack(e: GameEvent, look: AbilityPresentationAsset) -> IPresenter:
	var caster := _view(e.source)
	var target: EntityView = _view(e.targets[0]) if e.targets != null and e.targets.size() > 0 else null
	if caster == null: return null
	if target == null: return HitPresenter.new(caster, Color.WHITE, 0.15, false)
	var at := target.world_position
	var impact := func(): _impact_effects(look, at)
	var melee := e.tags.has(Tags.Melee)
	var def: AbilityDef = e.ability.def if e.ability != null else null
	var delivery := Callable() if melee else func() -> IPresenter: return WhenReady.new(_delivery(e, caster, target, look), impact)
	var trigger := _trigger_for(def, look) if def != null else EntityRig.ATTACK
	var cast_fx := func(): _fx(VfxKit.effect_name(look.cast_vfx) if look != null else "", _cast_at(caster, def), look)
	if trigger != "" and caster.rig != null and caster.rig.has(trigger):
		return AnimatePresenter.new(caster, trigger, target, cast_fx, impact if melee else Callable(), delivery)
	cast_fx.call()
	if melee: return WhenReady.new(LungePresenter.new(caster, target), impact)
	caster.face_point(target.world_position) # a model without clips still turns to shoot
	return delivery.call()

func _delivery(e: GameEvent, caster: EntityView, target: EntityView, look: AbilityPresentationAsset) -> IPresenter:
	var from := caster.muzzle_position if is_instance_valid(caster) else Vector3.ZERO
	var to := target.world_position if is_instance_valid(target) else from
	var model := _projectile_model(look)
	var scene: PackedScene = scene_of.call("res://art/models/%s.fbx" % model) if model != "" and scene_of.is_valid() else null
	var trail: String = TRAILS.get(model, "")
	var speed := look.projectile_speed if look != null else 0.0
	if e.tags.has(Tags.Projectile): return ProjectilePresenter.new(fx_parent, from, to + Vector3.UP * 0.6, 0.0, scene, speed, trail)
	if e.tags.has(Tags.Lobbed): return ProjectilePresenter.new(fx_parent, from, to + Vector3.UP * 0.4, 1.5, scene, speed, trail)
	var points := []
	if e.targets != null:
		for id in e.targets:
			var v := _view(id)
			if v != null: points.append(v.world_position)
	return BeamPresenter.new(fx_parent, points)

## The projectile model's name in res://art/models for a presentation: its projectile reference's file name
## ("Assets/Art/VFX/Placeholder/Arrow.prefab" → "Arrow") when such a model exists, else the kit's choice for the
## presentation, else "" (the placeholder sphere).
func _projectile_model(look: AbilityPresentationAsset) -> String:
	if look == null: return ""
	if look.projectile != "":
		var n := look.projectile.get_file().get_basename()
		if n.ends_with(" Blender"): n = n.substr(0, n.length() - 8)
		if ResourceLoader.exists("res://art/models/%s.fbx" % n): return n
	var by_name: String = PROJECTILE_BY_PRESENTATION.get(look.name.get_file(), "")
	if by_name != "" and ResourceLoader.exists("res://art/models/%s.fbx" % by_name): return by_name
	return ""

func _impact_effects(look: AbilityPresentationAsset, at: Vector3) -> void:
	if look == null: return
	_fx(VfxKit.effect_name(look.impact_vfx), at + Vector3.UP * 0.4, look)
	if look.impact_sound != "": GameSounds.play_clip(look.impact_sound)
	if look.camera_shake > 0.0 and shake.is_valid(): shake.call(look.camera_shake)

## Spawns a kit effect (nothing for "").
func _fx(effect: String, at: Vector3, look: AbilityPresentationAsset = null) -> void:
	if effect == "" or fx_parent == null or not is_instance_valid(fx_parent): return
	VfxKit.spawn(effect, at, fx_parent, look.vfx_lifetime if look != null else 2.0)

## Where a cast effect starts: the muzzle for shots (Projectile, Lobbed), else the caster's feet.
static func _cast_at(caster: EntityView, ability: AbilityDef) -> Vector3:
	if not is_instance_valid(caster): return Vector3.ZERO
	if ability != null and (ability.tags.has(Tags.Projectile) or ability.tags.has(Tags.Lobbed)): return caster.muzzle_position
	return caster.world_position

static func _has_attack_step(def: AbilityDef) -> bool:
	for st in def.steps:
		if st is AttackStep: return true
	return false

## The caster's trigger for an ability: the presentation asset's choice, else Cast for Spells and Attack for the rest.
static func _trigger_for(ability: AbilityDef, look: AbilityPresentationAsset) -> String:
	var mode := look.caster_animation if look != null else CasterAnimation.Default
	match mode:
		CasterAnimation.Attack: return EntityRig.ATTACK
		CasterAnimation.Cast: return EntityRig.CAST
		CasterAnimation.Custom: return look.custom_trigger
		CasterAnimation.None: return ""
	if ability == null: return EntityRig.ATTACK
	return EntityRig.CAST if ability.tags.has(Tags.Spell) else EntityRig.ATTACK
