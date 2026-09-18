extends RefCounted
const SkyRotation = preload("res://scripts/sky_rotation.gd")
const IDS = ["spring", "summer", "autumn", "winter"]
const NAMES = ["春", "夏", "秋", "冬"]
const DIFFICULTY = ["低", "低", "中", "中", "中", "高", "低", "中", "高", "中", "高", "中"]
const GROUND_COUNTS = [0, 4, 7, 13, 18, 25, 21, 29, 37, 35, 46, 40]
const AIR_COUNTS = [0, 0, 0, 3, 5, 8, 5, 9, 12, 12, 18, 14]
const RECRUITS = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,1), Vector2i(3,2), Vector2i(4,3), Vector2i(4,3), Vector2i(5,4), Vector2i(6,5), Vector2i(6,6), Vector2i(7,8), Vector2i(8,9)]

static func texture(name: String) -> Texture2D:
	return load("res://assets/seasons/%s.tres" % name) as Texture2D

static func configure(config: Resource) -> void:
	config.total_days = 12
	config.sunlight_per_day = 6
	config.water_per_day = 6
	config.resource_carry_over = true
	config.resource_carry_limit = 2
	config.max_branches = 96
	config.max_depth = 18
	config.growth_bounds = Rect2(-2000, -3400, 6000, 4300)
	config.companion_max_per_type = 10
	config.actor_spacing = 48.0
	config.hamster_attack_range = Vector2(410, 1700)
	config.companion_speed = 235.0
	config.bird_guard_radius = 510.0
	config.bird_chain_radius = 600.0
	config.bird_attack_interval = 0.9
	config.bird_rest_seconds = 0.35
	config.night_duration = 40.0
	config.pest_entry_distance = 780.0
	config.air_entry_height = 220.0
	config.pest_speeds = Vector2(68, 78)
	config.night_waves.clear()
	config.night_spawn_times.clear()
	for day in range(12):
		var entries: Array[Dictionary] = []
		for kind in range(2):
			var count: int = GROUND_COUNTS[day] if kind == 0 else AIR_COUNTS[day]
			for i in range(count):
				var progress: float = float(i) / maxf(1, count - 1)
				var group: int = mini(2, int(progress * 3.0))
				var local: float = clampf(progress * 3.0 - group, 0, 1)
				var at: float = [0.0, 9.0, 19.0][group] + local * 5.0 + kind * 0.35
				entries.append({"time": at, "kind": kind})
		entries.sort_custom(func(a, b): return a.time < b.time)
		var wave := PackedInt32Array()
		var times := PackedFloat32Array()
		for entry in entries:
			wave.append(entry.kind)
			times.append(entry.time)
		config.night_waves.append(wave)
		config.night_spawn_times.append(times)
	config.season_pouch = texture("pouch")
	config.winter_hamster = texture("winter_hamster")
	config.winter_bird = texture("winter_bird")
	config.seasonal_snow.clear()
	for i in range(5):
		config.seasonal_snow.append(texture("snow_%d" % i))
	apply(config, 1)

static func apply(config: Resource, day: int) -> void:
	var index: int = clampi((day - 1) / 3, 0, 3)
	var d: int = clampi(day - 1, 0, 11)
	config.current_season = index
	config.season_name = NAMES[index]
	config.difficulty_name = DIFFICULTY[d]
	config.recruit_targets = RECRUITS[d]
	config.sunlight_range = Vector2i(6,8)
	config.water_range = Vector2i(6,8)
	config.season_population = [Vector2i(3,1), Vector2i(5,4), Vector2i(7,7), Vector2i(8,10)][index]
	config.pest_active_limits = [Vector2i(5,1), Vector2i(10,4), Vector2i(14,7), Vector2i(18,10)][index]
	config.pest_min_spawn_gaps = [Vector2(1.5,3), Vector2(0.8,1.5), Vector2(0.55,1), Vector2(0.42,0.75)][index]
	config.night_health_factor = 0.85 if DIFFICULTY[d] == "低" else (1.08 if DIFFICULTY[d] == "高" else 1.0)
	config.season_tip = ["嫩芽初醒，先让小树与伙伴一起扎根。", "夏日飞虫开始增多，记得安排小鸟。", "秋风渐起，伙伴已经留下，慢慢扩展防线。", "冬天生长放缓，让满树伙伴守过最后三个夜晚。 "][index]
	var prefix: String = IDS[index]
	config.sky_day = SkyRotation.choose(config, "day")
	config.sky_dusk = SkyRotation.choose(config, "dusk")
	config.sky_night = SkyRotation.choose(config, "night")
	config.ground_texture = texture(prefix + "_ground")
	config.foliage_rear_atlas = texture(prefix + "_rear")
	config.foliage_middle_atlas = texture(prefix + "_middle")
	config.foliage_front_atlas = texture(prefix + "_front")
	config.season_icon = texture(prefix + "_icon")
	config.ground_season_color = [Color("b7ce86"), Color("93b76c"), Color("d9b46f"), Color("e2e8ed")][index]
	config.ground_season_blend = [0.15, 0.20, 0.60, 0.90][index]
