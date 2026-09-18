@tool
extends Resource
@export_group("关卡数值")
@export var day_duration: float = 40.0
@export var max_hearts: int = 3
@export var sunlight_per_day: int = 6
@export var water_per_day: int = 6
@export var resource_carry_over: bool = true
@export var resource_carry_limit: int = 2
# Each list is a finite nightly roster: 0 ground, 1 air.
@export var night_waves: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array([0, 0, 0, 0]), PackedInt32Array([0, 0, 0, 0, 0, 0]), PackedInt32Array([0, 0, 1, 0, 0, 0, 1, 0]), PackedInt32Array([0, 0, 1, 0, 0, 0, 1, 0, 0, 0]), PackedInt32Array([0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0])]
@export var night_spawn_times: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array([0, 4, 8, 12]), PackedFloat32Array([0, 2, 5, 7, 10, 12]), PackedFloat32Array([0, 1.8, 2.5, 5, 6.8, 9, 10, 12]), PackedFloat32Array([0, 1.6, 2.5, 4.5, 5.8, 7.2, 8.5, 10, 11.2, 12.5]), PackedFloat32Array([0, 1.4, 2, 4, 5.2, 6.4, 7, 9, 10.2, 11.4, 12, 13])]
@export_group("夜晚防线与节奏")
@export var hamster_attack_range: Vector2 = Vector2(390, 780)
@export var pine_projectile_speed: float = 650.0
@export var bird_guard_radius: float = 460.0
@export var bird_chain_radius: float = 500.0
@export var bird_max_chain: int = 2
@export var bird_rest_seconds: float = 0.6
@export var pest_active_limits: Vector2i = Vector2i(6, 2)
@export var pest_min_spawn_gaps: Vector2 = Vector2(0.9, 3.5)
@export var night_cleanup_seconds: float = 1.5
@export var feather_replenish_targets: PackedInt32Array = PackedInt32Array([0, 0, 0, 1, 2, 2])
@export_group("隐藏战斗数值（普通、快速、耐打）")
@export var ground_pest_health: Vector3 = Vector3(4, 3, 7)
@export var air_pest_health: Vector3 = Vector3(3, 2, 4)
@export var pest_variant_speed: Vector3 = Vector3(1.0, 1.3, 0.85)
@export var hamster_damage: float = 2.0
@export var bird_ground_damage: float = 2.0
@export var bird_attack_interval: float = 1.4
@export_range(0.5, 2.0, 0.1) var pest_spawn_multiplier: float = 1.0
@export var pest_speeds: Vector2 = Vector2(72, 80)
@export var companion_speed: float = 180.0
@export var companion_max_per_type: int = 3
@export_group("伙伴动作与松子")
@export var hamster_climb_speed: float = 230.0
@export var hamster_walk_speed: float = 135.0
@export var ground_speed_variation: Vector2 = Vector2(0.95, 1.05)
@export var hamster_eat_seconds: float = 0.8
@export var pine_throw_interval: float = 1.0
@export var pine_texture: Texture2D
@export var visit_interval_min: float = 7.0
@export var visit_interval_max: float = 13.0
@export_group("扩展世界入口")
@export var companion_entry_distance: float = 890.0
@export var pest_entry_distance: float = 1060.0
@export var air_entry_height: float = 365.0
@export_group("芽点生长")
@export var costs: PackedInt32Array = PackedInt32Array([1, 2, 3])
@export var snap_radius: float = 80.0
@export var rotation_limit_degrees: float = 180.0
@export var allow_downward: bool = true
@export var max_branches: int = 96
@export var max_depth: int = 18
@export var growth_bounds: Rect2 = Rect2(-1440, -2400, 4800, 3155)
@export var vertical_layer_height: float = 100.0
@export var ground_omen_max_layer: int = 3
@export_range(0, 1) var feather_probability: float = 0.65
@export_range(0, 30, 1) var feather_daily_min: int = 1
@export_range(0, 30, 1) var feather_daily_max: int = 2
@export_range(0, 30, 1) var feather_stock_max: int = 4
@export_group("每日橡果（所有低层合计）")
@export_range(0, 30, 1) var acorn_daily_min: int = 1
@export_range(0, 30, 1) var acorn_daily_max: int = 3
@export_range(0.0, 1.0, 0.01) var acorn_probability: float = 0.3
@export_range(0, 30, 1) var acorn_stock_max: int = 6
@export var acorn_replenish_targets: PackedInt32Array = PackedInt32Array([0, 1, 2, 2, 2, 2])
@export_group("节奏与显示")
@export var sky_duration: float = 1.2
@export var page_duration: float = 1.55
@export var swap_progress: float = 0.48
@export var page_paper_color: Color = Color("f5f1e5")
@export_range(0.0, 1.0) var page_curl_strength: float = 0.75
@export_range(0.0, 1.0) var page_shadow_strength: float = 0.30
@export_range(0.0, 0.05) var page_grain_strength: float = 0.012
@export var arrival_interval: float = 0.25
@export var hit_distance: float = 22.0
@export var actor_spacing: float = 68.0
@export_group("害虫与预兆贴图")
@export var pest_ground_textures: Array[Texture2D] = []
@export var pest_air_textures: Array[Texture2D] = []
@export var acorn_texture: Texture2D
@export var feather_texture: Texture2D
@export var pest_display_size: float = 56.0
@export var omen_display_size: float = 44.0
@export var sky_day: Texture2D
@export var sky_dusk: Texture2D
@export var sky_night: Texture2D
@export_group("菜单系统")
@export var panel_texture: Texture2D
@export var title_banner_texture: Texture2D
@export var icon_pause: Texture2D
@export var icon_play: Texture2D
@export var icon_settings: Texture2D
@export var icon_restart: Texture2D
@export var icon_resume: Texture2D
@export var icon_menu_size: float = 64.0
@export_group("托盘卡片")
@export var tray_textures: Array[Texture2D] = []

@export_group("三层树叶")
@export var foliage_rear_atlas: Texture2D
@export var foliage_middle_atlas: Texture2D
@export var foliage_front_atlas: Texture2D
@export_range(0.0, 1.0) var foliage_rear_opacity: float = 0.78
@export_range(1, 3) var foliage_middle_per_branch: int = 2
@export_range(0.1, 1.0) var foliage_middle_scale: float = 0.52
@export_range(0.0, 1.0) var foliage_front_chance: float = 0.58
@export_range(0.1, 1.0) var foliage_front_scale: float = 0.43
@export_range(0.0, 1.0) var foliage_front_opacity: float = 0.94

@export_group("土地贴图")
@export var ground_texture: Texture2D
@export var hill_texture: Texture2D

@export_group("天空贴图构图")
@export var sky_size: Vector2 = Vector2(3000, 1688)
@export var sky_center: Vector2 = Vector2(960, 400)
@export var sky_pivot: Vector2 = Vector2(960, 1200)
@export var sky_dusk_offset: Vector2 = Vector2(0, -230)

@export_group("固定昼夜时间")
@export var dusk_duration: float = 10.0
@export var night_duration: float = 30.0

@export_group("结局插画")
@export var ending_survival_texture: Texture2D
@export var ending_invasion_texture: Texture2D
@export var ending_survival_title: String = ""
@export_multiline var ending_survival_text: String = "小树长成了大树，\n这颗树真的长出了能容纳生命的地方...."
@export var ending_invasion_title: String = ""
@export_multiline var ending_invasion_text: String = "树木被昆虫们占领了，\n下一次，考虑一下和小动物们合作吧"

@export_group("四季日程")
@export var total_days: int = 12
var current_season: int = -1
var season_name: String = "春"
var difficulty_name: String = "低"
var season_tip: String = ""
var sunlight_range: Vector2i = Vector2i(6, 8)
var water_range: Vector2i = Vector2i(6, 8)
var season_population: Vector2i = Vector2i(3, 1)
var recruit_targets: Vector2i = Vector2i.ZERO
var season_icon: Texture2D
var season_pouch: Texture2D
var seasonal_snow: Array[Texture2D] = []
var winter_hamster: Texture2D
var winter_bird: Texture2D
var ground_season_color: Color = Color.WHITE
var ground_season_blend: float = 0.0
var night_health_factor: float = 1.0
