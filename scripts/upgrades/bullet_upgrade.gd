extends Upgrade
class_name BulletUpgrade
## Pickup that adds a bullet mode to the player's bow. Offered after boss rooms.
## Build one with BulletUpgrade.create(mode) rather than instantiating directly.
##
## To add a new mode: add it to MODES below, then implement its behaviour in
## bow_weapon.gd (patterns) or player_bullet.gd (per-bullet modifiers).

const MODES := {
	"spread":   {"name": "Spread Shot",      "color": Color(0.3, 1.0, 0.4)},
	"bounce":   {"name": "Bouncing Bullets", "color": Color(0.3, 0.7, 1.0)},
	"big":      {"name": "Big Bullets",      "color": Color(1.0, 0.5, 0.1)},
	"tracking": {"name": "Tracking Bullets", "color": Color(1.0, 0.25, 1.0)},
	"cardinal": {"name": "Cardinal Shot",    "color": Color(1.0, 0.9, 0.2)},
	"burst":    {"name": "Burst Fire",       "color": Color(1.0, 0.4, 0.7)},
}

var bullet_mode: String = ""

static func create(mode: String) -> BulletUpgrade:
	var u := BulletUpgrade.new()
	u.bullet_mode = mode
	u.description = MODES[mode]["name"]
	u.collision_layer = PhysicsLayers.PICKUPS
	u.collision_mask  = PhysicsLayers.PLAYERS

	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape_node.shape = circle
	u.add_child(shape_node)

	var sprite := Sprite2D.new()
	sprite.texture = _diamond_texture()
	sprite.modulate = MODES[mode]["color"]
	u.add_child(sprite)
	return u

## Modes the player's weapon can take but doesn't have yet.
static func modes_available_for(p: CharacterBody2D) -> Array:
	return MODES.keys().filter(func(mode: String) -> bool:
		return _weapon_supports_modes(p) and not p.current_weapon.has_bullet_mode(mode))

static func _weapon_supports_modes(p: CharacterBody2D) -> bool:
	return p.current_weapon != null and p.current_weapon.has_method("add_bullet_mode")

static func _diamond_texture() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	for x in range(8):
		for y in range(8):
			if abs(x - 3.5) + abs(y - 3.5) > 3.5:
				img.set_pixel(x, y, Color.TRANSPARENT)
	return ImageTexture.create_from_image(img)

func is_available(p: CharacterBody2D) -> bool:
	return bullet_mode in modes_available_for(p)

func apply(p: CharacterBody2D) -> void:
	p.current_weapon.add_bullet_mode(bullet_mode)
