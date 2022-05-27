# Generic character controller script (physics and animation)

extends KinematicBody2D # Inherits properties and functions of Area2D type

##
# Constants
##


const PHYSICS_MULTIPLIER = 40 # Physics scale multiplier

# Physics
const ACCELERATION = 0.046875 * PHYSICS_MULTIPLIER # Acceleration factor
const DECELERATION = 0.1 * PHYSICS_MULTIPLIER # Deceleration factor
const FALL_THRESHOLD = 2.5 * PHYSICS_MULTIPLIER # Tolerance speed for sticking to walls and ceilings
const FRICTION = 0.046875 * PHYSICS_MULTIPLIER # Friction (same as acceleration)
const GRAVITY = 0.21875 * PHYSICS_MULTIPLIER # Gravity
const JUMP_FORCE = 6.5 * PHYSICS_MULTIPLIER # Jump force (6 for Knuckles)
const SLOPE = 0.125 * PHYSICS_MULTIPLIER # Slope factor when walking/running
const SLOPE_ROLL_DOWN = 0.3125 * PHYSICS_MULTIPLIER # Slope factor when rolling downhill
const SLOPE_ROLL_UP = 0.078125 * PHYSICS_MULTIPLIER # Slope factor when rolling uphill
const TOP_SPEED = 6 * PHYSICS_MULTIPLIER # Top movement speed

# Animations
const ANIMATIONS = {
	"boost": "Boosting",
	"roll": "Rolling",
	"run": "Running",
	"skid": "Skidding",
	"stand": "Standing",
	"walk": "Walking"
}

##
# Variables
##

# Nodes
onready var info_text = $Camera/Info
onready var sprite = $Sprites

# Physics
var speed : float # Player's speed
var velocity : Vector2 = Vector2.ZERO # Player velocity

# States
var direction : int # Player direction (0 = left, 1 = right)
var state : int # Player state (normal = 0, rolling = 1, airborne = 2)
var is_grounded : bool = false # Is the player on the ground?
var is_jumping : bool = false # Is the player jumping?
var is_pushing : bool = false # Is the player pushing an object?
var is_rolling : bool = false # Is the player rolling?
var is_skidding : bool = false # Is the player skidding?

##
# Functions
##

func _process(_delta):
	info_text.text = "state: "+str(state)+"\ndirection: "+str(direction)+"\nvelocity: "+str(floor(velocity.x))+", "+str(floor(velocity.y))+"\nis_grounded: "+str(is_grounded)+"\nis_jumping: "+str(is_jumping)+"\nis_pushing: "+str(is_pushing)+"\nsphere_col: "+str(!$SphericalCollision.disabled)

func _physics_process(_delta):
	check_state()
	match state:
		0:
			state_normal()
		1:
			state_rolling()
		2:
			state_airborne()
	process_direction()
	process_animation()

# Perform a state check (normal, rolling, airborne)
func check_state():
	if is_grounded and !is_rolling:
		state = 0
	elif is_grounded and is_rolling:
		state = 1
	elif !is_grounded:
		state = 2

# Perform actions for normal state
func state_normal():
	# 1: Check for special animations that prevent control (such as balancing)
	# TODO
	
	# 2: Check for starting a spindash.
	# TODO
	
	# 3: Adjust ground speed based on current ground angle (slope factor)
	# TODO
	
	# 4: Check for starting a jump
	jump_check()
	
	# 5: Update ground speed based on directional input and apply friction/deceleration
	grounded_movement()
	
	# 6: Check for starting ducking, balancing on ledges, etc.
	# TODO
	
	# 7: Wall sensor collision occurs
	collision_check_wall()
	
	# 8: Check for starting a roll
	# TODO
	
	# 9: Handle camera boundaries (keep player inside the view and kill player if they touch the kill plane)
	# TODO
	
	# 10: Move sonic
	velocity = move_and_slide(velocity, Vector2.UP)
	
	# 11: Floor sensor collision occurs
	collision_check_ground()
	
	# 12: Check for falling when ground speed is too low on walls & ceilings

# Perform actions for rolling state
func state_rolling():
	pass

# Perform actions for airborne state
func state_airborne():
	# 1: Check for jump button release (variable jump velocity)
	# TODO
	
	# 2: Check for turning Super
	# TODO
	
	# 3: Update X Speed based on directional input
	airborne_movement()
	
	# 4: Apply air drag
	if velocity.y < 0 && velocity.y > -4:
		velocity.x -= (velocity.x / 0.125) / 256
	
	# 5: Move player (update X position and Y position based on X speed and Y speed)
	# TODO
	velocity = move_and_slide(velocity, Vector2.UP)
	
	# 6: Apply gravity (update Y speed by adding GRAVITY to it)
	velocity.y += Vector2.DOWN.y * GRAVITY
	
	# 7: Check if player is underwater for reduced gravity
	# TODO
	
	# 8: Rotate angle back to 0
	# TODO
	
	# 9: Perform collision checks (wall collision occurs first)
	collision_check_wall()
	collision_check_ground()

func jump_check():
	is_jumping = false
	if $DefaultCollision.disabled:
		$DefaultCollision.disabled = false
		$SphericalCollision.disabled = true
	if Input.is_action_just_pressed("jump"):
		velocity.x -= JUMP_FORCE * sin(0)
		velocity.y -= JUMP_FORCE * cos(0)
		$DefaultCollision.disabled = true
		$SphericalCollision.disabled = false
		is_jumping = true
		is_grounded = false

func grounded_movement():
	if Input.is_action_pressed("ui_left"):
		if $MidLeft.is_colliding():
			if direction == 0:
				is_pushing = true
		else:
			if speed > 0:
				is_skidding = true
				speed -= DECELERATION
				if speed <= 0:
					speed = -0.5
			elif speed > -TOP_SPEED:
				is_skidding = false
				speed -= ACCELERATION
				if speed <= -TOP_SPEED:
					speed = -TOP_SPEED
	elif Input.is_action_pressed("ui_right"):
		if $MidRight.is_colliding():
			if direction == 1:
				is_pushing = true
		else:
			if speed < 0:
				is_skidding = true
				speed += DECELERATION
				if speed >= 0:
					speed = 0.5
			elif speed < TOP_SPEED:
				is_skidding = false
				speed += ACCELERATION
				if speed >= TOP_SPEED:
					speed = TOP_SPEED
	else:
		speed -= min(abs(speed), FRICTION) * sign(speed)
	if is_skidding and speed == 0:
		is_skidding = false
	velocity.x = speed

func airborne_movement():
	if Input.is_action_pressed("ui_left"):
		if speed > 0:
			speed -= DECELERATION
			if speed <= 0:
				speed = -0.5
		else:
			speed -= ACCELERATION
	elif Input.is_action_pressed("ui_right"):
		if speed < 0:
			speed += DECELERATION
			if speed >= 0:
				speed = 0.5
		else:
			speed += ACCELERATION
	velocity.x = speed

func collision_check_ground():
	if is_on_floor() or $LowerLeft.is_colliding() or $LowerRight.is_colliding():
		is_grounded = true
		velocity.y = 0
	else:
		is_grounded = false

func collision_check_wall():
	if is_on_wall():
		velocity.x = 0
		if $MidLeft.is_colliding() and direction == 0:
			speed = 0
		elif $MidRight.is_colliding() and direction == 1:
			speed = 0

##
# Direction manager
##

func process_direction():
	if speed < 0:
		direction = 0
	elif speed > 0:
		direction = 1

##
# Animation manager
##

func process_animation():
	sprite.speed_scale = 1
	if direction == 0:
		sprite.flip_h = true
	elif direction == 1:
		sprite.flip_h = false
	if is_grounded and !is_rolling and !is_skidding:
		if speed == 0:
			sprite.play(ANIMATIONS.stand)
		elif abs(speed) > 0:
			sprite.speed_scale = abs(speed) * 0.02
			if abs(speed) < TOP_SPEED:
				sprite.play(ANIMATIONS.walk)
			elif abs(speed) == TOP_SPEED:
				sprite.play(ANIMATIONS.run)
			elif abs(speed) > TOP_SPEED:
				sprite.play(ANIMATIONS.boost)
	if is_jumping or is_rolling:
		if abs(speed) > TOP_SPEED:
			sprite.speed_scale = abs(speed) * 0.02
		else:
			sprite.speed_scale = TOP_SPEED * 0.02
		sprite.play(ANIMATIONS.roll)
	if is_skidding:
		sprite.play(ANIMATIONS.skid)
