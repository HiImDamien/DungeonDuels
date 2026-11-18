extends Area2D
class_name Upgrade
## Base class for the pickups offered after clearing a room.
##
## To add a new upgrade: extend this, set `description` in _init(), override
## apply() (and is_available() if it can max out), then add its scene to
## UPGRADE_SCENES in room_manager.gd.

var description: String = ""
var room_manager = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

## Whether this upgrade should be offered to (and can be picked up by) the
## player. Called before the node enters the tree, so don't use @onready vars.
func is_available(_player: CharacterBody2D) -> bool:
	return true

## Apply the upgrade's effect to the player who picked it up.
func apply(_player: CharacterBody2D) -> void:
	pass

## How this pickup is named in the balance log: the script's class_name
## (already snake_case, e.g. "attack_rate"). BulletUpgrade overrides it.
func pick_id() -> String:
	return get_script().get_global_name()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or not is_available(body):
		return
	body_entered.disconnect(_on_body_entered)
	apply(body)
	GameState.record_pick(body.player_index, pick_id())
	if room_manager:
		room_manager.on_upgrade_pickup(self)
	queue_free()
