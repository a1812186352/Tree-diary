extends Resource
## Pages are ordered here so illustrations can be replaced in the Inspector.
@export var pages: Array[Texture2D] = []
@export var page_titles: PackedStringArray = PackedStringArray()
@export_multiline var page_narrations: Array[String] = []
@export var paper_color: Color = Color("f6f1e6")
@export var next_scene: PackedScene
