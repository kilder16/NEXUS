class_name Weapon
extends RefCounted

# Datos de un arma. El cooldown vive en el player; la munición sí vive acá
# (max_ammo < 0 = munición infinita, default para pistola/rifle/escopeta/melee).

var weapon_name: String
var damage: int
var fire_rate: float   # segundos entre disparos
var max_range: float   # alcance máximo del raycast
var spread: float      # dispersión en radianes (0 = sin spread)
var pellets: int       # número de raycasts por disparo
var max_ammo: int      # < 0 = infinita; >= 0 = capacidad por nivel
var ammo: int          # munición restante (< 0 = infinita)

func _init(
	p_name: String,
	p_damage: int,
	p_fire_rate: float,
	p_max_range: float,
	p_spread: float = 0.0,
	p_pellets: int = 1,
	p_max_ammo: int = -1,
):
	weapon_name = p_name
	damage = p_damage
	fire_rate = p_fire_rate
	max_range = p_max_range
	spread = p_spread
	pellets = p_pellets
	max_ammo = p_max_ammo
	ammo = p_max_ammo

func has_limited_ammo() -> bool:
	return max_ammo >= 0

func has_ammo() -> bool:
	return max_ammo < 0 or ammo > 0

func consume_ammo() -> void:
	if has_limited_ammo() and ammo > 0:
		ammo -= 1
