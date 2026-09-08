extends CanvasLayer
## Reusable transition. Prepare the next illustration in `covered`, then start
## interaction/timers in `finished`. The current page is opaque during the swap.
signal covered
signal finished

var active: bool = false
var sheet: ColorRect
var sheet_material: ShaderMaterial
var motion: Tween

func _ready() -> void:
	layer = 100
	sheet = ColorRect.new()
	sheet.name = "TurningPaper"
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet_material = ShaderMaterial.new()
	sheet_material.shader = preload("res://shaders/page_turn.gdshader")
	sheet.material = sheet_material
	add_child(sheet)
	sheet.hide()

func play(duration: float = 1.55, swap_at: float = 0.48,
		paper_tint: Color = Color("f5f1e5"), curl: float = 0.75,
		shadow: float = 0.30, grain_amount: float = 0.012) -> void:
	if active:
		return
	active = true
	# Every real page turn has exactly one sound, including the story -> Day 1 turn.
	var music_manager: Node = get_parent().get_node_or_null("Systems/MusicManager")
	get_node("/root/PageAudio").play_page(music_manager)
	sheet_material.set_shader_parameter("paper_color", paper_tint)
	sheet_material.set_shader_parameter("curl_strength", clampf(curl, 0.0, 1.0))
	sheet_material.set_shader_parameter("shadow_strength", clampf(shadow, 0.0, 1.0))
	sheet_material.set_shader_parameter("grain_strength", clampf(grain_amount, 0.0, 0.05))
	sheet_material.set_shader_parameter("revealing", false)
	_set_progress(0.0)
	sheet.show()
	var total: float = maxf(duration, 0.4)
	var split: float = clampf(swap_at, 0.3, 0.7)
	var hold: float = minf(0.10, total * 0.08)
	var movement: float = total - hold
	motion = create_tween()
	motion.tween_method(_set_progress, 0.0, 1.0, movement * split).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await motion.finished
	# A rendered opaque frame separates the old and new content, even when
	# a slow frame advances the animation past the logical midpoint.
	await RenderingServer.frame_post_draw
	covered.emit()
	await RenderingServer.frame_post_draw
	motion = create_tween()
	motion.tween_interval(hold)
	await motion.finished
	sheet_material.set_shader_parameter("revealing", true)
	_set_progress(0.0)
	motion = create_tween()
	motion.tween_method(_set_progress, 0.0, 1.0, movement * (1.0 - split)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await motion.finished
	sheet.hide()
	active = false
	finished.emit()

func _set_progress(value: float) -> void:
	sheet_material.set_shader_parameter("progress", value)
