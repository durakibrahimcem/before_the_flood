class_name DuneSpot
extends Node2D
## One thin patch on the dune; sand blows from it until grass is planted.

const SAND_BLOW := Color(0.92, 0.80, 0.52, 0.9)
const PATCH_FILL := Color(0.96, 0.88, 0.66, 0.85)
const PATCH_RIM := Color(0.60, 0.48, 0.30, 0.55)
const GRASS := Color(0.42, 0.60, 0.30)
const GRASS_LINE := Color(0.25, 0.38, 0.19)
const BLADE_ANGLES: Array[float] = [-60.0, -35.0, -12.0, 14.0, 36.0, 58.0]
const BLADE_HEIGHTS: Array[float] = [46.0, 54.0, 42.0, 52.0, 44.0, 56.0]
## Sparks answer a planted tuft in the sand's own colour.
const PLANT_SPARK := Color("e8d9a8")

var is_planted := false

var spot_texture: Texture2D
var plant_texture: Texture2D

var particles: CPUParticles2D


func _ready() -> void:
	particles = CPUParticles2D.new()
	particles.amount = 24
	particles.lifetime = 0.9
	particles.one_shot = false
	particles.emitting = true
	particles.preprocess = 0.6
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 22.0
	particles.direction = Vector2(1, 0)
	particles.spread = 18.0
	particles.initial_velocity_min = 70.0
	particles.initial_velocity_max = 150.0
	particles.gravity = Vector2(0, 26)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.6
	particles.color = SAND_BLOW
	add_child(particles)


func plant() -> void:
	is_planted = true
	TaskJuice.play("plant")
	particles.emitting = false
	queue_redraw()
	TaskJuice.pop(self)
	TaskJuice.sparks(get_parent(), position, PLANT_SPARK)


func _draw() -> void:
	if is_planted:
		if plant_texture != null:
			draw_texture(plant_texture, -plant_texture.get_size() * 0.5)
		else:
			_draw_grass()
	elif spot_texture != null:
		draw_texture(spot_texture, -spot_texture.get_size() * 0.5)
	else:
		_draw_patch()


func _draw_patch() -> void:
	var edge := PackedVector2Array()
	for i: int in 12:
		var angle := TAU * float(i) / 12.0
		var wave := 1.0 + 0.22 * sin(angle * 3.0)
		edge.append(Vector2(cos(angle) * 30.0 * wave, sin(angle) * 17.0 * wave))
	edge.append(edge[0])
	draw_colored_polygon(edge, PATCH_FILL)
	draw_polyline(edge, PATCH_RIM, 3.0)


func _draw_grass() -> void:
	for i: int in BLADE_ANGLES.size():
		var angle := deg_to_rad(BLADE_ANGLES[i])
		var tip := Vector2(sin(angle), -cos(angle)) * BLADE_HEIGHTS[i]
		var blade := PackedVector2Array([Vector2.ZERO, tip * 0.5 + Vector2(3.0, -4.0), tip])
		draw_polyline(blade, GRASS_LINE, 7.0)
		draw_polyline(blade, GRASS, 4.0)
