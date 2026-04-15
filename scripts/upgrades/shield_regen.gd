extends Upgrade
class_name shield_regen

@export var cooldown_decrease = 0.5
@export var recharge_interval_decrease = 0.1
@export var recharge_delay_decrease = 0.2

func _ready() -> void:
	self.description = "Shield\nRegen"
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	print(body)
	if body.is_in_group("player"):
		var shield: Shield = body.get_node("Shield")
		if shield == null:
			print("Shield is null, why's that huh?")
		else:
			var recharge_interval = shield.recharge_interval
			var recharge_delay = shield.recharge_delay
			var cooldown = shield.cooldown_time
			
			if cooldown != 0:
				if cooldown - cooldown_decrease <= 0:
					shield.cooldown_time = 0
				else:
					shield.cooldown_time = cooldown - cooldown_decrease
			if recharge_interval != 0:
				if recharge_interval - recharge_interval_decrease <= 0:
					shield.recharge_interval = 0
				else:
					shield.recharge_interval = recharge_interval - recharge_interval_decrease 
			if recharge_delay != 0:
				if recharge_delay - recharge_delay_decrease <= 0:
					shield.recharge_delay = 0
				else:
					shield.recharge_delay = recharge_delay - recharge_delay_decrease
			self.on_item_pickup()
