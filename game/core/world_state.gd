class_name WorldState
extends RefCounted
## One moment of the future, read by every visual, sound and number.

enum Wall { NONE, STANDING, CRACKED, BREACHED }

var year: float = 2026.0
var water_m: float = 0.0
var flood_m: Dictionary = {}
var meadow: float = 1.0
var dune: float = 0.0
var wall_state: int = Wall.NONE
var homes: int = 2
var neighbours: int = 1
## Planters in use on the street. Planted today, so they show from the first year.
var saplings: int = 0
var home_alive: Dictionary = {}
var severity: float = 0.0
