extends Node
signal changed(phase: String)
var phase: String = "DAY"
var elapsed: float = 0.0
var day: int = 1
var result: String = ""
var transitions: Array[String] = []

func enter(next: String) -> void:
	if phase == "GAMEOVER":
		return
	phase = next
	elapsed = 0
	transitions.append(next)
	changed.emit(next)

func finish(outcome: String) -> void:
	if phase == "GAMEOVER":
		return
	result = outcome
	enter("GAMEOVER")
