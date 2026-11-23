extends SceneTree
## Создаёт data/*_default.tres (для каждого набора из core/params.gd → REGISTRY) и стартовые пресеты.
## Запуск:  godot --headless --path . --script tools/generate_data.gd
## Существующие файлы не перезаписываются (чтобы не потерять твои настройки).
## Перезаписать всё:  ... --script tools/generate_data.gd -- --force

const Registry := preload("res://core/params.gd")

var force := false


func _make(key: String) -> Resource:
	return (load(Registry.REGISTRY[key]["script"]) as Script).new()


func _initialize() -> void:
	force = "--force" in OS.get_cmdline_user_args()

	for key in Registry.REGISTRY:
		_save(_make(key), {}, Registry.REGISTRY[key]["file"])

	var mp := "res://data/presets/movement/"
	_save(_make("movement"), {}, mp + "01_standard.tres")
	_save(_make("movement"), {
		"run_speed": 360.0, "ground_accel": 4500.0, "ground_decel": 5000.0, "turn_mult": 1.5,
		"air_accel": 3200.0, "air_decel": 1600.0, "jump_height": 120.0, "time_to_apex": 0.34,
		"fall_mult": 1.6, "cut_mult": 4.0, "apex_mult": 0.5,
	}, mp + "02_tight_celeste.tres")
	_save(_make("movement"), {
		"run_speed": 380.0, "ground_accel": 700.0, "ground_decel": 900.0, "turn_mult": 2.5,
		"air_accel": 600.0, "air_decel": 150.0, "jump_height": 150.0, "time_to_apex": 0.42,
		"fall_mult": 1.3, "cut_mult": 2.5, "ice_friction": 0.1,
	}, mp + "03_inertia_mario.tres")
	_save(_make("movement"), {
		"run_speed": 300.0, "ground_accel": 1500.0, "ground_decel": 1500.0, "air_accel": 1000.0,
		"air_decel": 300.0, "jump_height": 220.0, "time_to_apex": 0.65, "fall_mult": 0.9,
		"cut_mult": 1.5, "max_fall": 450.0, "apex_mult": 0.4,
	}, mp + "04_floaty.tres")
	_save(_make("movement"), {
		"run_speed": 260.0, "ground_accel": 1200.0, "ground_decel": 1800.0, "air_accel": 800.0,
		"air_decel": 500.0, "jump_height": 100.0, "time_to_apex": 0.28, "fall_mult": 2.2,
		"cut_mult": 4.0, "max_fall": 1100.0, "apex_mult": 0.8,
	}, mp + "05_heavy.tres")

	var ap := "res://data/presets/attack/"
	_save(_make("attack"), {}, ap + "01_standard.tres")
	_save(_make("attack"), {
		"windup": 0.04, "active": 0.06, "recovery": 0.1, "damage": 6.0, "reach_x": 48.0,
		"knockback_x": 180.0, "knockback_y": 60.0, "hitstop": 0.04, "hit_shake": 2.0,
		"self_recoil": 20.0, "lunge_speed": 90.0, "move_mult": 0.6,
	}, ap + "02_quick.tres")
	_save(_make("attack"), {
		"windup": 0.25, "active": 0.1, "recovery": 0.35, "damage": 30.0, "reach_x": 78.0,
		"reach_y": 60.0, "knockback_x": 520.0, "knockback_y": 220.0, "hitstop": 0.13,
		"hit_shake": 9.0, "self_recoil": 120.0, "lunge_speed": 60.0, "move_mult": 0.0,
	}, ap + "03_heavy.tres")

	var ip := "res://data/presets/ink/"
	_save(_make("ink"), {}, ip + "01_standard.tres")
	_save(_make("ink"), {
		"length": 140.0, "cost": 15.0, "thickness": 16.0, "lifetime": 8.0, "max_strokes": 5,
		"regen_rate": 25.0,
	}, ip + "02_short_thick.tres")
	_save(_make("ink"), {
		"length": 340.0, "cost": 40.0, "thickness": 8.0, "lifetime": 3.0, "max_strokes": 2,
		"draw_time": 0.2, "damage": 18.0,
	}, ip + "03_long_thin.tres")
	_save(_make("ink"), {
		"charge_enabled": true, "charge_time": 0.9, "charge_length_min": 0.4, "charge_length_max": 2.0,
		"charge_damage_min": 0.5, "charge_damage_max": 3.0, "charge_knock_min": 0.5, "charge_knock_max": 2.2,
		"charge_cost_mode": 0, "charge_cost_max": 2.4,
	}, ip + "04_charged.tres")
	_save(_make("ink"), {
		"charge_enabled": true, "charge_time": 1.2, "charge_length_min": 0.4, "charge_length_max": 2.2,
		"charge_damage_min": 0.5, "charge_damage_max": 3.0, "charge_cost_mode": 1, "charge_drain_rate": 45.0,
		"regen_while_charging": false, "auto_release": true,
	}, ip + "05_charged_drain.tres")

	var wp := "res://data/presets/wave/"
	_save(_make("wave"), {}, wp + "01_standard.tres")
	_save(_make("wave"), {
		"reach": 420.0, "height": 130.0, "curve_power": 2.0, "wall_extra": 0.0,
		"thickness": 12.0, "sweep_time": 0.25, "ink_cost": 35.0,
	}, wp + "02_low_wide.tres")
	_save(_make("wave"), {
		"reach": 170.0, "height": 300.0, "curve_power": 3.2, "wall_extra": 120.0,
		"thickness": 20.0, "sweep_time": 0.12, "ink_cost": 40.0, "knockback_y": 700.0,
	}, wp + "03_tall_barrier.tres")
	_save(_make("wave"), {
		"charge_time": 1.2, "charge_curve": 1.6, "charge_reach_min": 0.4, "charge_reach_max": 2.0,
		"charge_height_min": 0.3, "charge_height_max": 2.2, "charge_wall_min": 0.3, "charge_wall_max": 2.2,
		"charge_damage_min": 0.4, "charge_damage_max": 3.0, "charge_cost_max": 2.5, "auto_release": true,
	}, wp + "04_big_charge.tres")
	_save(_make("wave"), {"charge_enabled": false}, wp + "05_instant_no_charge.tres")
	_save(_make("wave"), {
		"aim_mode": 1, "base_angle": 30.0, "curve_power": 1.6, "wall_extra": 0.0, "wall_to_ground": false,
	}, wp + "06_fixed_30deg.tres")
	_save(_make("wave"), {
		"aim_mode": 1, "base_angle": 0.0, "curve_invert": true, "snap_to_ground": false,
		"origin_y": 10.0, "height": 120.0, "reach": 220.0, "wall_extra": 0.0, "wall_to_ground": false,
	}, wp + "07_canopy.tres")
	_save(_make("wave"), {
		"charge_cost_mode": 1, "charge_drain_rate": 50.0, "charge_time": 1.0, "charge_knock_max": 1.6,
	}, wp + "08_charge_drain.tres")

	var bp := "res://data/presets/brush/"
	_save(_make("brush"), {}, bp + "01_standard.tres")
	_save(_make("brush"), {"strands": 1, "wobble": 0.0, "width_var": 0.0, "taper": 0.0, "ragged": 0.0,
		"color_var": 0.0, "underlay": false}, bp + "02_clean_line.tres")
	_save(_make("brush"), {"strands": 10, "wobble": 6.0, "wobble_freq": 1.6, "width_var": 0.6,
		"taper": 0.8, "ragged": 0.3, "color_var": 0.25}, bp + "03_dry_brush.tres")

	var dp := "res://data/presets/dummy/"
	_save(_make("dummy"), {}, dp + "01_standard.tres")
	_save(_make("dummy"), {"max_hp": 300.0, "kb_resist": 0.7, "hit_interrupts": false,
		"body_width": 64.0, "body_height": 80.0, "charge_speed": 640.0}, dp + "02_heavy.tres")

	var pp := "res://data/presets/paintable/"
	_save(_make("paintable"), {}, pp + "01_standard.tres")
	_save(_make("paintable"), {"hold_speed": 420.0, "hold_start_mult": 0.6, "hold_ink_per_px": 0.05,
		"auto_close_gap": 56.0, "sample_step": 10.0}, pp + "02_быстро_и_щедро.tres")
	_save(_make("paintable"), {"auto_close_gap": 6.0, "sample_step": 5.0, "hold_speed": 180.0}, pp + "03_точно.tres")
	_save(_make("paintable"), {"hold_ink_per_px": 0.4, "hold_speed": 150.0, "hold_start_mult": 0.15,
		"fade_progress": 4.0}, pp + "04_дорого.tres")

	var cp := "res://data/presets/camera/"
	_save(_make("camera"), {}, cp + "01_standard.tres")
	_save(_make("camera"), {"follow_facing": true, "offset_x": 160.0, "look_speed": 3.0}, cp + "02_look_ahead.tres")
	_save(_make("camera"), {"zoom": 0.6, "offset_x": 0.0, "offset_y": 120.0}, cp + "03_wide.tres")
	quit()


func _save(res: Resource, overrides: Dictionary, path: String) -> void:
	if FileAccess.file_exists(path) and not force:
		return
	for k in overrides:
		if not k in res:
			push_error("%s: нет параметра %s" % [path, k])
		res.set(k, overrides[k])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(res, path)
	print("%s -> %s" % [path, "OK" if err == OK else "ERROR %d" % err])
