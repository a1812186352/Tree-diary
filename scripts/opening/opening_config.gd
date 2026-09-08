extends Resource
## Settings for the book cover and video; edit config/opening.tres in Godot.
@export_group("封面与视频")
@export var cover_texture: Texture2D
@export var video_stream: VideoStream
@export var video_duration: float = 5.042
@export var paper_color: Color = Color("f6f1e6")
@export_range(0.0, 1.0) var video_volume: float = 1.0
@export_group("开始阅读按钮")
@export var button_text: String = "开始阅读  ›"
@export var button_position_uv: Vector2 = Vector2(0.76, 0.493)
@export var button_size_uv: Vector2 = Vector2(0.195, 0.078)
@export_group("角落纸签")
@export var chapter_text: String = "序  章"
@export var skip_text: String = "跳过开篇  ›"
@export var chapter_rect_uv: Rect2 = Rect2(0.02, 0.022, 0.205, 0.098)
@export var skip_rect_uv: Rect2 = Rect2(0.775, 0.89, 0.225, 0.11)
@export_group("后续故事")
## Empty until the story pages exist: the opening stays on warm paper.
@export_file("*.tscn") var next_scene: String = ""
