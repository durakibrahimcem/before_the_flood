class_name Flotsam
extends Node2D
## The keepsakes that float when a room floods. Knows which rooms carry which
## keepsakes; the items live under the room itself, so they draw in its order.

## Each room's keepsakes: art that may not exist yet, where each rests, and how
## deep its hull rides. Ebru's art drops in at the paths below, no code changes.
const SETS := {
	"salon": [
		{
			"name": "Boat", "shape": "boat", "art": "res://water/art/boat.png",
			"rest": Vector2(790.0, 810.0), "draft_m": 0.02, "wander_px": 170.0, "rings": true,
		},
		{
			"name": "Cushion", "shape": "cushion", "art": "res://water/art/cushion.png",
			"rest": Vector2(930.0, 960.0), "draft_m": 0.10, "wander_px": 150.0,
		},
		{
			"name": "Photo", "shape": "photo", "art": "res://water/art/photo.png",
			"rest": Vector2(1010.0, 670.0), "draft_m": 0.03, "wander_px": 130.0,
		},
	],
}

var room: Room

var _items: Array[FlotsamItem] = []


func _ready() -> void:
	if room == null or not SETS.has(room.room_name):
		queue_free()
		return
	for spec: Dictionary in SETS[room.room_name]:
		var item := FlotsamItem.new()
		item.name = spec["name"]
		item.room = room
		item.shape = spec["shape"]
		item.texture = _art(spec)
		item.rest = spec["rest"]
		item.draft_m = spec["draft_m"]
		item.wander_px = spec["wander_px"]
		item.leaves_rings = spec.get("rings", false)
		room.add_child(item)
		_items.append(item)


func item(item_name: String) -> FlotsamItem:
	for keep: FlotsamItem in _items:
		if keep.name == item_name:
			return keep
	return null


## Ebru's art when it exists, and nothing until then: the item draws a placeholder.
func _art(spec: Dictionary) -> Texture2D:
	var path: String = spec["art"]
	return (load(path) as Texture2D) if FileAccess.file_exists(path) else null
