extends RefCounted

const POOLS = {
	"day": [
		preload("res://assets/backgrounds/clear_day_01.png"),
		preload("res://assets/backgrounds/clear_day_02.png"),
		preload("res://assets/backgrounds/clear_day_03.png"),
	],
	"dusk": [
		preload("res://assets/backgrounds/clear_dusk_01.png"),
		preload("res://assets/backgrounds/clear_dusk_02.png"),
		preload("res://assets/backgrounds/clear_dusk_03.png"),
	],
	"night": [
		preload("res://assets/backgrounds/clear_night_01.png"),
		preload("res://assets/backgrounds/clear_night_02.png"),
		preload("res://assets/backgrounds/clear_night_03.png"),
	],
}

static func choose(config: Resource, phase: String) -> Texture2D:
	var key: String = "sky_bag_" + phase
	var bag: Array = config.get_meta(key, [])
	var last: int = int(config.get_meta(key + "_last", -1))
	if bag.is_empty():
		bag = range(POOLS[phase].size())
		bag.shuffle()
		if bag.size() > 1 and int(bag.back()) == last:
			var swap = bag[0]
			bag[0] = bag.back()
			bag[bag.size() - 1] = swap
	var selected: int = int(bag.pop_back())
	config.set_meta(key, bag)
	config.set_meta(key + "_last", selected)
	return POOLS[phase][selected] as Texture2D
