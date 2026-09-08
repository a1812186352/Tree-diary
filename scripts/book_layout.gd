extends RefCounted
## Shared coordinates on the fixed 1920 x 1080 design canvas.
const PAPER := Color("f6f1e6")
const DESK := Color("ded5c2")
const BOOK := Rect2(56, 48, 1808, 984)
const CONTENT := Rect2(80, 72, 1760, 936)
const IMAGE := Rect2(80, 72, 880, 936)
const TITLE := Rect2(1056, 188, 680, 120)
const BODY := Rect2(1056, 348, 656, 440)
const NEXT := Rect2(1420, 906, 320, 66)
const PAGE_NUMBER := Rect2(1056, 910, 200, 56)

static func contains(point: Vector2) -> bool:
	return CONTENT.has_point(point)
