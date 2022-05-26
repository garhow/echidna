class_name Player

extends KinematicBody2D

const MULTIPLICATION = 1

# Movement constants
const ACCELERATION = 0.046875 * MULTIPLICATION # Acceleration factor
const DECELERATION = 0.1 * MULTIPLICATION # Deceleration factor
const FALL_THRESHOLD = 2.5 * MULTIPLICATION # Tolerance speed for sticking to walls and ceilings
const FRICTION = 0.046875 * MULTIPLICATION # Friction (same as acceleration)
const GRAVITY = 0.21875 * MULTIPLICATION # Gravity
const JUMP_FORCE = 6.5 * MULTIPLICATION # Jump force (6 for Knuckles)
const SLOPE = 0.125 # Slope factor when walking/running
const SLOPE_ROLL_DOWN = 0.3125 * MULTIPLICATION # Slope factor when rolling downhill
const SLOPE_ROLL_UP = 0.078125 * MULTIPLICATION # Slope factor when rolling uphill
const TOP_SPEED = 6 * MULTIPLICATION # Top movement speed

# Animations
const animations = {
	"roll": "Rolling",
	"run": "Running",
	"skid": "Skidding",
	"stand": "Standing",
	"walk": "Walking"
}

# Player states
var is_jumping : bool = false
var is_skidding : bool = false

# Movement variables
var velocity : Vector2 = Vector2.ZERO
var ground_speed : float = 0  # The speed at which the player is moving on the ground

# Node variables
onready var default_collision = get_node("DefaultCollision")
onready var spherical_collision = get_node("SphericalCollision")
onready var sprite = get_node("Sprites")

##
# Function
##

func _physics_process(delta):
	process_jumping()
	process_movement()
	process_animation()
	print(velocity)
	velocity = move_and_slide(velocity, Vector2.UP, false)

func process_jumping():
	if is_jumping:
		default_collision.disabled
		spherical_collision.disabled = false
	elif !is_jumping:
		default_collision.disabled = false
		spherical_collision.disabled = true

func process_movement():
	if is_on_floor():
		is_jumping = false
		velocity.y = 0
		ground_movement()
	elif !is_on_floor():
		velocity.y += Vector2.DOWN.y * GRAVITY

func ground_movement():
	if Input.is_action_just_pressed("jump"):
		is_jumping = true
		velocity.x -= JUMP_FORCE * cos(90)
		velocity.y -= JUMP_FORCE * sin(90)
	if Input.is_action_pressed("ui_left"):
		if ground_speed > 0:
			is_skidding = true
			ground_speed -= DECELERATION
			if ground_speed <= 0:
				ground_speed = -0.5
		elif ground_speed > -TOP_SPEED:
			is_skidding = false
			ground_speed -= ACCELERATION
			if ground_speed <= -TOP_SPEED:
				ground_speed = -TOP_SPEED
	elif Input.is_action_pressed("ui_right"):
		if ground_speed < 0:
			is_skidding = true
			ground_speed += DECELERATION
			if ground_speed >= 0:
				ground_speed = 0.5
		elif ground_speed < TOP_SPEED:
			is_skidding = false
			ground_speed += ACCELERATION
			if ground_speed >= TOP_SPEED:
				ground_speed = TOP_SPEED
	else:
		ground_speed -= min(abs(ground_speed), FRICTION) * sign(ground_speed)
	velocity.x = ground_speed

func process_animation():
	sprite.speed_scale = 1
	if is_on_floor():
		if ground_speed == 0:
			# Play idle animation if not moving
			sprite.play(animations.stand)
		else:
			# Flip character if facing left
			if ground_speed > 0:
				sprite.flip_h = false
			elif ground_speed < 0:
				sprite.flip_h = true
			
			# Walking and running animations
			if abs(ground_speed) > 0:
				sprite.speed_scale = abs(ground_speed)
				if abs(ground_speed) < TOP_SPEED:
					sprite.play(animations.walk)
				if abs(ground_speed) >= TOP_SPEED:
					sprite.play(animations.run)
			
			if is_skidding:
				sprite.play(animations.skid)
	if is_jumping:
		sprite.play(animations.roll)
