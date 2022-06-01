extends Node2D

##
# Classes
##

class GroundInfo:
	var height : float
	var point : Vector2
	var distance : float
	var normal : Vector2
	var angle : float
	var valid : bool = false

##
# Constants
##

const groundAcceleration = 168.75
const groundTopSpeed = 360
const speedLimit = 960
const rollingMinSpeed = 61.875
const unrollThreshold = 30
const friction = 168.75
const rollingFriction = 84.375
const deceleration = 1800
const rollingDeceleration = 450
const slopeFactor = 450
const rollUphillSlope = 281.25
const rollDownhillSlope = 1125
const sideRaycastOffset = -4
const sideRaycastDist = 11
const groundRaycastDist = 36
const fallVelocityThreshold = 150

##
# Dictionaries
##

var animations = {
	"roll": "Rolling",
	"run": "Running",
	"stand": "Standing"
}

##
# Enums
##

enum GroundMode {
	CEILING,
	FLOOR,
	LEFTWALL,
	RIGHTWALL
}

##
# Variables
##

# Engine
export var debug = true

# States
var grounded : bool
var jumped : bool
var rolling : bool

# Physics - General
var velocity : Vector2
var characterAngle : float
var lowCeiling : bool
var underwater : bool

var standingHeight : float = 40
var ballHeight : float = 30
var standWidthHalf : float = 9
var spinWidthHalf : float = 7
func heightHalf():
	if rolling or jumped: return ballHeight
	else: return standingHeight / 2

var standLeftRPos : Vector2
var spinLeftRPos : Vector2
var standRightRPos : Vector2
var spinRightRPos : Vector2

var waterLevel : Transform

func leftRaycastPos():
	if rolling or jumped: return spinLeftRPos
	else: return standLeftRPos
		
func rightRaycastPos():
	if rolling or jumped: return spinRightRPos
	else: return standRightRPos

var speedHash : String = "Running"
var standHash : String = "Standing"
var spinHash : String = "Spinning"
var pushHash : String = "Walking"

# Physics - Ground
var groundVelocity : float
var hControlLock : bool
var hControlLockTime : float = 0.5
var currentGroundInfo : GroundInfo
var groundMode = GroundMode.FLOOR

# Physics - Air
var airAcceleration : float = 337.5
var jumpVelocity : float = 390
var jumpReleaseThreshold : float = 240
var gravity : float = -787.5
var terminalVelocity : float = 960
var airDrag : float = 0.96875

# Physics - Underwater
var uwAcceleration : float = 84.375
var uwDeceleration : float = 900
var uwFriction : float = 84.375
var uwRollingFriction : float = 42.1875
var uwGroundTopSpeed : float = 180
var uwAirAcceleration : float = 168.75
var uwGravity : float = -225
var uwJumpVelocity : float = 210
var uwJumpReleaseThreshold : float = 120

# Nodes
onready var animator = $Sprites

##
# Script functions
##

func _ready():
	waterLevel = get_tree().get_nodes_in_group("WaterLevel")[0].transform
	standLeftRPos = Vector2(-standWidthHalf, 0)
	standRightRPos = Vector2(standWidthHalf, 0)
	spinLeftRPos = Vector2(-spinWidthHalf, 0)
	spinRightRPos = Vector2(spinWidthHalf, 0)

func _process(_delta):
	if Input.is_action_just_pressed("Toggle Debug"): debug = !debug
	debug_info()

func _physics_process(delta):
	var input : Vector2 = Vector2(Input.get_axis("Left", "Right"), Input.get_axis("Down", "Up"))
	
	var accelSpeedCap : float
	if underwater: accelSpeedCap = uwGroundTopSpeed
	else: accelSpeedCap = groundTopSpeed
	
	if grounded:
		if !rolling and input.y < -0.005 and abs(groundVelocity) >= rollingMinSpeed:
			rolling = true
			transform.origin -= Vector2(0, 5)
		
		var slope = 0
		if rolling:
			var angleSin = sin(currentGroundInfo.angle)
			var uphill : bool
			
			if angleSin >= 0 and groundVelocity >= 0: uphill = true
			elif angleSin <= 0 and groundVelocity <= 0: uphill = false
			
			if uphill: slope = rollUphillSlope
			elif !uphill: slope = rollDownhillSlope
		else: slope = slopeFactor
		
		groundVelocity += (slope * sin(currentGroundInfo.angle)) * delta
		
		var lostFooting : bool = false
		
		if groundMode != GroundMode.FLOOR and abs(groundVelocity) < fallVelocityThreshold:
			groundMode = GroundMode.FLOOR
			grounded = false
			hControlLock = true
			hControlLockTime = 0.5
			lostFooting = true
		
		if Input.is_action_just_pressed("Jump") and !lowCeiling:
			var jumpVel : float
			
			if underwater: jumpVel = uwJumpVelocity
			else: jumpVel = jumpVelocity
			
			velocity.x -= jumpVel * sin(currentGroundInfo.angle)
			velocity.y += jumpVel * cos(currentGroundInfo.angle)
			
			grounded = false
			jumped = true
		else:
			if hControlLock:
				hControlLockTime -= delta
				if hControlLockTime <= 0:
					hControlLock = false
			
			if rolling or abs(input.x) < 0.005:
				var fric : float
				var rollFric : float
				
				if underwater:
					fric = uwFriction
					rollFric = uwRollingFriction
				else:
					fric = friction
					rollFric = rollingFriction
				
				var frc : float
				
				if rolling: frc = rollFric
				else: frc = fric
				
				if groundVelocity > 0:
					groundVelocity -= frc * delta
					if groundVelocity < 0: groundVelocity = 0
				elif groundVelocity < 0:
					groundVelocity += frc * delta
					if groundVelocity > 0: groundVelocity = 0
			
			if !hControlLock and abs(input.x) >= 0.005:
				var accel : float
				var decel : float
				
				if underwater:
					accel = uwAcceleration
					decel = uwDeceleration
				else:
					accel = groundAcceleration
					decel = deceleration
				
				if input.x < 0:
					if groundVelocity < 0:
						var newScale : Vector2 = Vector2.ONE
						newScale.x *= sign(groundVelocity)
						scale = newScale
					
					var acceleration : float = 0
					
					if rolling and groundVelocity > 0: acceleration = rollingDeceleration
					elif !rolling and groundVelocity > 0: acceleration = decel
					elif !rolling and groundVelocity <= 0: acceleration = accel
					
					if groundVelocity > -accelSpeedCap:
						groundVelocity = max(-accelSpeedCap, groundVelocity + (input.x * acceleration) * delta)
				else:
					if groundVelocity > 0:
						var newScale : Vector2 = Vector2.ONE
						scale = newScale
					
					var acceleration : float = 0
					
					if rolling and groundVelocity < 0: acceleration = rollingDeceleration
					elif !rolling and groundVelocity < 0: acceleration = decel
					elif !rolling and groundVelocity >= 0: acceleration = accel
					
					if groundVelocity < accelSpeedCap:
						groundVelocity = max(accelSpeedCap, groundVelocity + (input.x * acceleration) * delta)
			
			if groundVelocity > speedLimit: groundVelocity = speedLimit
			elif groundVelocity < -speedLimit: groundVelocity = -speedLimit
			
			if rolling and abs(groundVelocity) < unrollThreshold:
				rolling = false
				position += Vector2(0, 5)
			
			var angledSpeed : Vector2 = Vector2(groundVelocity * cos(currentGroundInfo.angle), groundVelocity * sin(currentGroundInfo.angle))
			velocity = angledSpeed
			
			if (lostFooting): groundVelocity = 0
	else:
		var jumpRelThreshold : float
		if underwater: jumpRelThreshold = uwJumpReleaseThreshold
		else: jumpRelThreshold = jumpReleaseThreshold
		
		if jumped and velocity.y > jumpRelThreshold and Input.is_action_just_released("Jump"):
			velocity.y = jumpRelThreshold
		else:
			if velocity.y > 0 and velocity.y < 4 and abs(velocity.x) > 7.5:
				velocity.x *= airDrag
			
			var grv : float
			if underwater: grv = uwGravity
			else: grv = -gravity
			
			velocity.y = max(velocity.y + (grv * delta), -terminalVelocity)
		
		if (!rolling and jumped) and abs(input.x) >= 0.005:
			if (input.x < 0 and velocity.x > -accelSpeedCap) || input.x > 0 and velocity.x < accelSpeedCap:
				var airAcc : float
				if underwater: airAcc = uwAirAcceleration
				else: airAcc = airAcceleration
				
				velocity.x = clamp(velocity.x + (input.x * airAcc * delta), -accelSpeedCap, accelSpeedCap)
	
	# Clamp velocity to global speed limit; going any faster could result in passing through things
	velocity.x = clamp(velocity.x, -speedLimit, speedLimit)
	velocity.y = clamp(velocity.y, -speedLimit, speedLimit)
	
	# Apply movement
	position += Vector2(velocity.x, velocity.y) * delta
	
	# Collision testing
	var leftHit : RayCast2D
	var rightHit : RayCast2D
	
	var raycastSideOffset : float
	if grounded: raycastSideOffset = sideRaycastOffset
	else: raycastSideOffset = 0
	
	leftHit = WallCheck(sideRaycastDist, raycastSideOffset)[0]
	rightHit = WallCheck(sideRaycastDist, raycastSideOffset)[1]
	
	if leftHit.get_collider() != null and rightHit.get_collider() != null:
		print("squashed")
	elif leftHit.get_collider() != null:
		position = Vector2(leftHit.get_collision_point().x + sideRaycastDist, position.y)
		if velocity.x < 0:
			velocity.x = 0
			groundVelocity = 0
	elif rightHit.get_collider() != null:
		position = Vector2(rightHit.get_collision_point().x - sideRaycastDist, position.y)
		if velocity.x > 0:
			velocity.x = 0
			groundVelocity = 0
	
	var ceilingCeil : GroundInfo
	var ceilingLeft = false
	var ceilingRight = false
	var ceilDir : int = groundMode + 2
	if ceilDir > 3: ceilDir -= 4
	
	var ceiling = GroundedCheck(groundRaycastDist, ceilDir)
	
	ceilingCeil = ceiling[0]
	ceilingLeft = ceiling[1]
	ceilingRight = ceiling[2]
	
	var groundedLeft = false
	var groundedRight = false
	
	if grounded:
		var currentGround = GroundedCheck(groundRaycastDist, groundMode)
		currentGroundInfo = currentGround[0]
		grounded = currentGround[1] || currentGround[2]
	else:
		if ceilingCeil.valid and velocity.y > 0:
			var hitCeiling = false
			if position.y >= ceilingCeil.point.y - heightHalf(): hitCeiling = true
			
			var angleDeg : float = rad2deg(ceilingCeil.angle)
			
			# Check for attaching to ceiling
			if hitCeiling and ((angleDeg >= 225 and angleDeg <= 270) or (angleDeg >= 90 and angleDeg <= 135)):
				grounded = true
				jumped = false
				rolling = false
				currentGroundInfo = ceilingCeil
				groundMode = GroundMode.CEILING
				groundVelocity = velocity.y * sign(sin(currentGroundInfo.angle))
				velocity.y = 0
			elif hitCeiling:
				if position.y > ceilingCeil.point.y - heightHalf():
					position = Vector2(position.x, ceilingCeil.point.y - heightHalf())
					velocity.y = 0
		else:
			var infoFull = GroundedCheck(groundRaycastDist, GroundMode.FLOOR)
			
			var info : GroundInfo = infoFull[0]
			groundedLeft = infoFull[1]
			groundedRight = infoFull[2]
			
			grounded = (groundedLeft || groundedRight) && velocity.y <= 0 && position.y <= (info.height + heightHalf())
			
			if grounded:
				if jumped:
					position += Vector2(0, 5)
				
				jumped = false
				rolling = false
				
				currentGroundInfo = info
				groundMode = GroundMode.FLOOR
				var angleDeg : float = rad2deg(currentGroundInfo.angle)
				
				if angleDeg < 22.5 or (angleDeg > 337.5 and angleDeg <= 360):
					groundVelocity = velocity.x
				elif (angleDeg >= 22.5 and angleDeg < 45) or (angleDeg >= 315 and angleDeg < 337.5):
					if abs(velocity.x) > abs(velocity.y): groundVelocity = velocity.x
					else: groundVelocity = velocity.y * 0.5 * sign(sin(currentGroundInfo.angle))
				elif (angleDeg >= 45 and angleDeg < 90) or (angleDeg >= 270 and angleDeg < 315):
					if abs(velocity.x) > abs(velocity.y): groundVelocity = velocity.x
					else: groundVelocity = velocity.y * sign(sin(currentGroundInfo.angle))
				
				velocity.y = 0
	
	if grounded:
		StickToGround(currentGroundInfo)
		animator.play(animations.run)
		animator.speed_scale = abs(groundVelocity)
		
		lowCeiling = ceilingCeil.valid && position.y > ceilingCeil.point.y - 25
	else:
		currentGroundInfo = null
		groundMode = GroundMode.FLOOR
		lowCeiling = false
		
		if abs(input.x) > 0.005 and !(rolling and jumped):
			var newScale = Vector2.ONE
			newScale.x *= sign(input.x)
			scale = newScale
		
		if characterAngle > 0 and characterAngle <= 180:
			characterAngle -= delta * 180
			if characterAngle < 0: characterAngle = 0
		elif characterAngle < 360 and characterAngle > 180:
			characterAngle += delta * 180
			if characterAngle >= 360: characterAngle = 0
	
	if rolling or jumped:
		animator.play(animations.roll)
	
	if !underwater and position.y <= waterLevel.origin.y:
		pass #EnterWater()
	elif underwater and position.y > waterLevel.origin.y:
		print("mokey")
		#ExitWater()
	
	rotation = rad2deg(characterAngle)

##
# Functions
##

func EnterWater():
	groundVelocity *= 0.5
	underwater = true
	velocity.x *= 0.5
	velocity.y *= 0.25

func ExitWater():
	underwater = false
	velocity.y *= 2

func WallCheck(distance : float, heightOffset : float):
	var pos = Vector2(position.x, position.y + heightOffset)
	
	var hitLeft = RayCast2D.new()
	hitLeft.enabled = true
	hitLeft.position = pos
	hitLeft.cast_to = Vector2.LEFT * distance
	
	var hitRight = RayCast2D.new()
	hitRight.enabled = true
	hitRight.position = pos
	hitRight.cast_to = Vector2.RIGHT * distance
	
	return [hitLeft, hitRight]

func GroundedCheck(distance : float, groundMode):
	var groundedLeft : bool
	var groundedRight : bool
	
	var rot = Transform2D().rotated(deg2rad(90 * groundMode))
	var dir = rot * Vector2.DOWN
	var leftCastPos = rot * leftRaycastPos()
	var rightCastPos = rot * rightRaycastPos()
	
	var leftHit = RayCast2D.new()
	leftHit.enabled = true
	leftHit.position = position + leftCastPos
	leftHit.cast_to = dir * distance
	groundedLeft = leftHit.is_colliding()
	
	var rightHit = RayCast2D.new()
	rightHit.enabled = true
	rightHit.position = position + rightCastPos
	rightHit.cast_to = dir * distance
	groundedRight = rightHit.is_colliding()
	
	var found = null
	
	if groundedLeft and groundedRight:
		var leftCompare : float = 0
		var rightCompare : float = 0
		
		match groundMode:
			GroundMode.FLOOR:
				leftCompare = leftHit.get_collision_point().y
				rightCompare = rightHit.get_collision_point().y
			GroundMode.RIGHTWALL:
				leftCompare = -leftHit.get_collision_point().x
				rightCompare = -rightHit.get_collision_point().x
			GroundMode.CEILING:
				leftCompare = -leftHit.get_collision_point().y
				rightCompare = -rightHit.get_collision_point().y
			GroundMode.LEFTWALL:
				leftCompare = leftHit.get_collision_point().x
				rightCompare = rightHit.get_collision_point().x
			_:
				pass
		
		if leftCompare >= rightCompare: found = GetGroundInfoCast(leftHit)
		else: found = GetGroundInfoCast(rightHit)
	elif groundedLeft: found = GetGroundInfoCast(leftHit)
	elif groundedRight: found = GetGroundInfoCast(rightHit)
	else: found = GroundInfo.new()
	
	return [found, groundedLeft, groundedRight]

func GetGroundInfoVector(center : Vector2):
	var info = GroundInfo.new()
	var groundHit = RayCast2D.new()
	groundHit.enabled = true
	groundHit.position = center
	groundHit.cast_to = groundRaycastDist * Vector2.DOWN
	if groundHit.get_collider() != null:
		info.height = groundHit.get_collision_point().y
		info.point = groundHit.get_collision_point()
		info.normal = groundHit.get_collision_normal()
		info.angle = Vector2().angle_to(info.normal)
		info.valid = true

func GetGroundInfoCast(hit : RayCast2D):
	var info = GroundInfo.new()
	print("trying")
	if hit.get_collider() != null:
		info.height = hit.get_collision_point().y
		info.point = hit.get_collision_point()
		info.normal = hit.get_collision_normal()
		info.angle = Vector2().angle_to(info.normal)
		info.valid = true

func StickToGround(info : GroundInfo):
	var angle : float = rad2deg(info.angle)
	characterAngle = angle
	
	match groundMode:
		GroundMode.FLOOR:
			if angle < 315 and angle > 225: groundMode = GroundMode.LEFTWALL
			elif angle > 45 and angle < 180: groundMode = GroundMode.RIGHTWALL
			position.y = info.point.y + heightHalf()
		GroundMode.RIGHTWALL:
			if angle < 45 and angle > 0: groundMode = GroundMode.FLOOR
			elif angle > 135 and angle < 270: groundMode = GroundMode.CEILING
			position.x = info.point.x - heightHalf()
		GroundMode.CEILING:
			if angle < 135 and angle > 45: groundMode = GroundMode.RIGHTWALL
			elif angle > 225 and angle < 360: groundMode = GroundMode.LEFTWALL
			position.y = info.point.y - heightHalf()
		GroundMode.LEFTWALL:
			if angle < 225 and angle > 45: groundMode = GroundMode.CEILING
			elif angle > 315: groundMode = GroundMode.FLOOR
			position.x = info.point.x + heightHalf()
		_:
			pass

func debug_info():
	if debug:
		$Camera/Debug/Grounded.text = "Grounded: " + str(grounded)
		$Camera/Debug/Jumped.text = "Jumped: " + str(jumped)
		$Camera/Debug/Underwater.text = "Underwater: " + str(underwater)
		if currentGroundInfo != null and currentGroundInfo.valid:
			$Camera/Debug/Angle.text = "Angle (Deg): " + str(rad2deg(currentGroundInfo.angle))
			$Camera/Debug/Speed.text = "Speed: " + str(round(groundVelocity))
