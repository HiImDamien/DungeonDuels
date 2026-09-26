class_name Enemy
extends CharacterBody2D
## Shared behaviour for every enemy: health, hit flash, kill credit and firing
## enemy bullets. Subclasses handle their own movement and attack patterns.
##
## Every enemy scene needs an AnimatedSprite2D child, and the enemy must be
## added to a room that already contains the "Player" node.

const ENEMY_BULLET := preload("res://scenes/enemy/enemy_bullet.tscn")
const HIT_FLASH_TIME := 0.15
const HIT_FLASH_COLOR := Color(1, 0.2, 0.2)

@export var max_health: int = 3
@export var bullet_speed: float = 100.0

@onready var player_instance: player = get_parent().get_node("Player")
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: int

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	safe_margin = 0.08

func take_damage(amount: int = 1, attacker = null) -> void:
	health -= amount
	if health <= 0:
		if attacker != null and "kills" in attacker:
			attacker.kills += 1
		queue_free()
		return
	_on_damaged()
	_flash_hit()

## Override to react to taking non-lethal damage (e.g. boss phase changes).
func _on_damaged() -> void:
	pass

## The sprite colour to return to after a hit flash.
func _base_tint() -> Color:
	return Color.WHITE

func _flash_hit() -> void:
	animated_sprite.modulate = HIT_FLASH_COLOR
	await get_tree().create_timer(HIT_FLASH_TIME).timeout
	if is_instance_valid(self):
		animated_sprite.modulate = _base_tint()

## False during the grace period or while this room's player is dead.
func can_attack() -> bool:
	return not GameState.is_grace and not player_instance.is_dead

func direction_to_player() -> Vector2:
	return (player_instance.global_position - global_position).normalized()

func spawn_bullet(dir: Vector2) -> void:
	var bullet = ENEMY_BULLET.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	bullet.direction = dir.normalized()
	bullet.speed = bullet_speed
