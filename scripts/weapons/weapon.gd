class_name Weapon
extends RefCounted

# Datos de un arma. Sin estado de runtime: el cooldown vive en el player.

var weapon_name: String
var damage: int
var fire_rate: float   # segundos entre disparos
var max_range: float   # alcance máximo del raycast
var spread: float      # dispersión en radianes (0 = sin spread)
var pellets: int       # número de raycasts por disparo

func _init(
	p_name: String,
	p_damage: int,
	p_fire_rate: float,
	p_max_range: float,
	p_spread: float = 0.0,
	p_pellets: int = 1,
):
	weapon_name = p_name
	damage = p_damage
	fire_rate = p_fire_rate
	max_range = p_max_range
	spread = p_spread
	pellets = p_pellets
