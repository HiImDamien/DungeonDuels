extends Camera2D

# How quickly to move through the noise
@export var noise_shake_speed: float = 60.0
# Noise returns values in the range (-1, 1)
# So this is how much to multiply the returned value by
@export var noise_shake_strength: float = 10.0
# Multiplier for lerping the shake strength to zero
@export var shake_decay_rate: float = 5.0

@onready var rand = RandomNumberGenerator.new()
@onready var noise = FastNoiseLite.new()

# Used to keep track of where we are in the noise
# so that we can smoothly move through it
var noise_i: float = 0.0
var shake_strength: float = 0.0

func _ready() -> void:
	rand.randomize()
	noise.seed = rand.randi()
	# Period affects how quickly the noise changes values
	noise.frequency = 2

func apply_noise_shake() -> void:
	shake_strength = noise_shake_strength

func _process(delta: float) -> void:
	shake_strength = lerp(shake_strength, float(0), shake_decay_rate * delta)
	# Shake by adjusting offset so we can move the camera around the level via its position
	offset = get_noise_offset(delta)

func get_noise_offset(delta: float) -> Vector2:
	noise_i += delta * noise_shake_speed
	# Set x values of each call to different values so x and y read from unrelated noise areas
	return Vector2(
		noise.get_noise_2d(1, noise_i) * shake_strength,
		noise.get_noise_2d(100, noise_i) * shake_strength
	)
