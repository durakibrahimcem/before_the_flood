class_name Main
extends Node2D
## Owns the current room and the walking character.

const ROOMS := {
	"bedroom": preload("res://rooms/bedroom/bedroom.tscn"),
	"salon": preload("res://rooms/salon/salon.tscn"),
	"street": preload("res://rooms/street/street.tscn"),
	"shore": preload("res://rooms/shore/shore.tscn"),
}

var room: Room

@onready var arda: Arda = $Arda


func _ready() -> void:
	enter_room("bedroom", Vector2.INF)


func enter_room(room_name: String, arrive_at: Vector2) -> void:
	if room != null:
		room.remove_child(arda)
		room.queue_free()
	else:
		remove_child(arda)
	room = ROOMS[room_name].instantiate()
	room.door_used.connect(enter_room)
	add_child(room)
	room.add_child(arda)
	arda.room = room
	arda.position = room.spawn if arrive_at == Vector2.INF else arrive_at
	WorldClock.refresh()
