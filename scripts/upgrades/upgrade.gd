extends Area2D
class_name Upgrade

var description: String = ""
var room_manager = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
func disable():
	for connection in body_entered.get_connections():
		body_entered.disconnect(connection.callable)
		
func on_item_pickup():
	disable()
	if room_manager:
		room_manager.on_upgrade_pickup(self)
	queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
