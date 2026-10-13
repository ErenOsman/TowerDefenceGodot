extends SceneTree
## Renders the VFX kit's effects (CPUParticles3D approximations) in a grid, a moment after they start, to check
## they show: ~/godot/run.sh projects/td -s tools/vfx_shot.gd -- <out.png> [seconds]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://vfx.png"
	var wait := float(args[1]) if args.size() > 1 else 0.15
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.36, 0.45, 0.32)
	world.add_child(env)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(3.3, 4.0, 6.0) if not args.has("all") else Vector3(4.5, 7.5, 7.5)
	cam.look_at(Vector3(3.3, 0, 1.0) if not args.has("all") else Vector3(4.5, 0, 0.5))
	Engine.time_scale = 0.25
	cam.current = true
	var names: Array = ["Hit Spark", "Hit Flash", "Smash Dust", "Cannon Blast", "Fire Burst", "Holy Pillar",
		"Spawn Pop", "Death Poof", "Heal Rise", "Burn Loop", "Shield Loop", "Acid Splash"] if not args.has("all") else VfxKit.names()
	var i := 0
	for n in names:
		var cols := 10 if args.has("all") else 4
		var p := Vector3((i % cols) * (1.0 if cols == 10 else 2.2), 0.4, -(i / cols) * 1.6 + 2.5)
		var fx := VfxKit.build(n)
		world.add_child(fx)
		fx.position = p
		var label := Label3D.new()
		label.text = n
		label.font_size = 28
		label.pixel_size = 0.004
		label.position = p + Vector3(0, -0.35, 0.45)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
		i += 1
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 * Engine.time_scale < wait:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
