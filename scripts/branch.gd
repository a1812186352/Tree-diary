@tool
extends Node2D

@export_range(1, 3) var bud_count: int = 1
@export var is_base: bool = false
@export var sticker_texture: Texture2D
@export var grown_texture: Texture2D
@export var texture_rect: Rect2 = Rect2(-64, -160, 128, 170)
@export var grown: bool = true
var branch_id: String = "base"
var parent_bud_id: String = ""
var placed_day: int = 0
var activated_day: int = 0
var depth: int = 0
var preview: bool = false
var show_hints: bool = false
var paper_material: ShaderMaterial

func _ready() -> void:
	paper_material = ShaderMaterial.new()
	paper_material.shader = preload("res://shaders/branch_paper.gdshader")
	material = paper_material
	paper_material.set_shader_parameter("sticker", not grown)

func _process(_delta: float) -> void:
	if paper_material != null:
		paper_material.set_shader_parameter("sticker", not grown)
	if Engine.is_editor_hint():
		queue_redraw()

func buds() -> Array:
	return $Buds.get_children()

func root_position() -> Vector2:
	return $RootAnchor.global_position

func tip_position() -> Vector2:
	return $Buds/Tip.global_position

func mature(day: int) -> void:
	grown = true
	activated_day = day
	queue_redraw()

func _draw() -> void:
	if not has_node("Buds/Tip"):
		return
	var root: Vector2 = $RootAnchor.position
	var tip: Vector2 = $Buds/Tip.position
	var texture: Texture2D = grown_texture if grown else sticker_texture
	if texture != null:
		draw_texture_rect(texture, texture_rect, false)
	else:
		var wood := Color("c8ad7e") if grown else Color("d3b990")
		var width := 24.0 if is_base else 17.0
		if not grown:
			draw_line(root + Vector2(4, 5), tip + Vector2(4, 5), Color(0.2, 0.17, 0.1, 0.12), width + 14, true)
			draw_line(root, tip, Color("fffaf0"), width + 10, true)
		draw_line(root, tip, wood, width, true)
		draw_line(root + Vector2(3, -8), tip * 0.85 + Vector2(3, 0), Color("e5d5ae"), 3, true)
		for bud in buds():
			if bud.position != tip:
				draw_line(tip + Vector2(0, 16), bud.position, wood, width * 0.55, true)
		for marker in $BirdAnchors.get_children():
			draw_line(root.lerp(tip, 0.6), marker.position, wood, 5, true)
		for side in [-1.0, 1.0]:
			var p: Vector2 = root.lerp(tip, 0.6) + Vector2(side * 15, 0)
			draw_set_transform(p, side * 0.5, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, 15, Color("a5b58c") if grown else Color("bac6a5"))
			draw_set_transform(Vector2.ZERO)
	for bud in buds():
		if bud.get_meta("occupied", false):
			continue
		var p: Vector2 = bud.position
		if texture == null:
			draw_circle(p, 5.0, Color("a2b58a"))
		if (show_hints and grown) or Engine.is_editor_hint():
			draw_arc(p, 12, 0, TAU, 24, Color("a4b89b"), 1.5, true)
			draw_line(p, p + Vector2.UP.rotated(bud.rotation) * 20, Color(0.6, 0.7, 0.56, 0.5), 1, true)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if (sticker_texture == null) != (grown_texture == null):
		warnings.append("请成对设置贴纸图和成长图；未设置时使用灰盒占位。")
	if sticker_texture != null and grown_texture != null and sticker_texture.get_size() != grown_texture.get_size():
		warnings.append("贴纸图和成长图必须使用相同画布尺寸、根部和芽点坐标。")
	return warnings
