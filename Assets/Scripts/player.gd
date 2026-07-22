extends CharacterBody2D

@export var speed = 10.0
@export var jump_power = 10.0
@export var respawn_position: Vector2  # Where the player will respawn
@export var fall_limit: float = 1000   # Y-coordinate below which the player respawns

var speed_multiplier = 30.0
var jump_multiplier = -30.0
var direction = 0

@onready var anim = $AnimatedSprite2D

func _ready():
	# Set default respawn position to the starting position if not set
	if respawn_position == Vector2.ZERO:
		respawn_position = global_position

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_power * jump_multiplier

	# Movement
	direction = Input.get_axis("move_left", "move_right")

	if direction != 0:
		velocity.x = direction * speed * speed_multiplier
	else:
		velocity.x = move_toward(velocity.x, 0, speed * speed_multiplier)

	# Flip sprite
	if direction != 0:
		anim.flip_h = direction < 0

	# Animation
	_update_animation()

	# Move
	move_and_slide()

	# Check if player fell off the map
	if global_position.y > fall_limit:
		respawn()

func _update_animation():
	# In the air:
	if not is_on_floor():
		# Going up → jump animation
		if velocity.y < 0:
			anim.play("jump")
		else:
			anim.play("fall")
		return

	# On the ground:
	if direction == 0:
		anim.play("idle")
	else:
		anim.play("run")

func respawn():
	global_position = respawn_position  # Move player to respawn point
	velocity = Vector2.ZERO              # Reset movement
	print("Player respawned!")           # Debug message
