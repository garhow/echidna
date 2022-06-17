extends CharacterBody2D

enum SpringVelocityMode {
	VERTICAL,
	HORIZONTAL,
	DIAGONAL
}

enum GroundMode {
	FLOOR,
	RIGHT_WALL,
	CEILING,
	LEFT_WALL
}

# Debug
@export var showDebug : bool = true # Enables debug mode.

# Animation
@onready var animator : AnimatedSprite2D = $Sprite # Character's animated sprite.
@export var smoothRotation : bool = false # When enabled, the character will rotate smoothly to match the ground angle they are standing on. When disabled, the character's rotation will snap to 45-degree increments.

# Hitbox
@onready var hitbox : CollisionShape2D = $Collision
var standingHitboxSize : Vector2 = Vector2(19, 34)
var shortHitboxSize : Vector2 = Vector2(19, 20)

# General
var standingHeightHalf : float = 20 # Half the character's height when standing.
var ballHeightHalf : float = 15 # Half the character's height when rolling or jumping.
var heightHalf : float = ballHeightHalf if rolling or jumped else standingHeightHalf
var rollingPositionOffset : float = standingHeightHalf - ballHeightHalf
var groundRaycastDist : float = 36
var standingWidthHalf : float = 10
var ballWidthHalf : float = 7
var stepUpHeight : float = 15
var stepDownHeightMin : float = 4
var wallCollisionWidthHalf : float = 11
var flatGroundSideRaycastOffset : float = -8
var springAirborneAngleThreshold : float = 45
var postHitInvulnerabilityDuration : float = 2

var collisionMaskA
var collisionMaskB

# Movement Settings
var baseMovementSettings : MovementSettings = MovementSettings.new()
var underwaterMovementSettings : MovementSettings = MovementSettings.new()
var currentMovementSettings : MovementSettings = underwaterMovementSettings if underwater else baseMovementSettings

# Ground Movement
var globalSpeedLimit : float = 960
var rollingMinSpeed : float = 61.875
var unrollThreshold : float = 30
var defaultSlopeFactor : float = 450
var rollUphillSlopeFactor : float = 281.25
var rollDownhillSlopeFactor : float = 1125
var fallVelocityThreshold : float = 150
var horizontalControlLockTime : float = 0.5
var lowCeilingHeight : float = 25

# Air Movement
var airDragMaxYVelocity : float = 4
var airDragMinAbsoluteXVelocity : float = 7.5
var uprightRotationRate : float = 168.75
var brakeTagName : String = "brake"
var brakeGroundSpeedThreshold : float = 240
var jumpSpinTagName : String = "jumpSpin"
var springJumpDuration : float = 0.8

var waterLevel : Transform2D
var inputMove : Vector2
var inputJump : bool
var inputJumpLastFrame : float

var grounded : bool
var rolling : float
var jumped : float

var groundSpeed : float

var facingDirection : float

var isBraking : bool = false
var isJumpSpinning : bool = false
var isSpringJumping : bool = false
var springJumpTimer : float = 0

var isHit : bool
var postHitInvulnerabilityTimer : float = 0

var isInvulnerable : bool = isHit or postHitInvulnerabilityTimer > 0

var lookingUp : bool
var lookingDown : bool

var hControlLock : bool
var hControlLockTimer : float = 0
var currentGroundInfo : GroundInfo = GroundInfo.new()
var currentGroundMode : GroundMode = GroundMode.FLOOR

var currentVelocity : Vector2

var characterAngle : float
var lowCeiling : bool
var underwater : bool

func getGroundRaycastPositions(groundMode : GroundMode, ceilingCheck : bool):
	var coord : float = (ballWidthHalf if rolling or jumped else standingWidthHalf) + 0.005
	var leftRaycastPosition : Vector2
	var rightRaycastPosition : Vector2
	match groundMode:
		GroundMode.FLOOR:
			leftRaycastPosition = Vector2(-coord, 0)
			rightRaycastPosition = Vector2(coord, 0)
		GroundMode.RIGHT_WALL:
			leftRaycastPosition = Vector2(0, -coord)
			rightRaycastPosition = Vector2(0, coord)
		GroundMode.CEILING:
			leftRaycastPosition = Vector2(coord, 0)
			rightRaycastPosition = Vector2(-coord, 0)
		GroundMode.LEFT_WALL:
			leftRaycastPosition = Vector2(0, coord)
			rightRaycastPosition = Vector2(0, -coord)
		_:
			leftRaycastPosition = Vector2.ZERO
			rightRaycastPosition = Vector2.ZERO
	
	if ceilingCheck:
		leftRaycastPosition = -leftRaycastPosition
		rightRaycastPosition = -rightRaycastPosition
	
	return [leftRaycastPosition, rightRaycastPosition]

func GetGroundRaycastDirection(groundMode : GroundMode, ceilingCheck : bool):
	var dir : Vector2 = Vector2.DOWN
	if grounded:
		match groundMode:
			GroundMode.FLOOR:
				dir = Vector2.DOWN
			GroundMode.RIGHT_WALL:
				dir = Vector2.RIGHT
			GroundMode.CEILING:
				dir = Vector2.UP
			GroundMode.LEFT_WALL:
				dir = Vector2.LEFT
	
	if ceilingCheck:
		dir = -dir
	
	return dir

var shouldApplyAirDrag : bool = currentVelocity.y > 0 and currentVelocity.y < airDragMaxYVelocity and abs(currentVelocity.x) > airDragMinAbsoluteXVelocity

var currentGroundMask
var hitResultsCache

var animations = {
	"hit": "Hit",
	"idle": "Idle",
	"run": "Running"
}

func resetMovement():
	inputMove = Vector2.ZERO
	inputJump = false
	inputJumpLastFrame = false
	groundSpeed = 0
	hControlLock = false
	hControlLockTimer = 0
	currentGroundInfo = GroundInfo.invalid
	grounded = false
	rolling = false
	jumped = false
	currentGroundMode = GroundMode.FLOOR
	currentVelocity = Vector2.ZERO
	characterAngle = 0
	lowCeiling = false
	underwater = false
	isBraking = false
	isSpringJumping = false
	springJumpTimer = 0
	isJumpSpinning = false
	setCollisionLayer(0)

func setCollisionLayer(layer : int):
	match layer:
		0:
			currentGroundMask = collisionMaskA
		1:
			currentGroundMask = collisionMaskB

func setSpringState(launchVelocity : Vector2, forceAirborne : bool, springVelocityMode : SpringVelocityMode, newHorizontalControlLockTime : float = 0.0, useJumpSpinAnimation : bool = true):
	if launchVelocity.length_squared() < 0.001:
		return
	
	if grounded:
		if forceAirborne:
			grounded = false
		else:
			var launchDirection : Vector2 = launchVelocity.normalized()
			if launchDirection.angle_to_point(currentGroundInfo.normal) < springAirborneAngleThreshold:
				grounded = false
	
	if grounded:
		var newSpeed : float = launchVelocity.length()
		match currentGroundMode:
			GroundMode.FLOOR:
				groundSpeed = newSpeed * sign(launchVelocity.x)
			GroundMode.RIGHT_WALL:
				groundSpeed = newSpeed * sign(launchVelocity.y)
			GroundMode.CEILING:
				groundSpeed = newSpeed * -sign(launchVelocity.x)
			GroundMode.LEFT_WALL:
				groundSpeed = newSpeed * -sign(launchVelocity.y)
		facingDirection = sign(groundSpeed)
	else:
		match springVelocityMode:
			SpringVelocityMode.VERTICAL:
				currentVelocity.y = launchVelocity.y
			SpringVelocityMode.HORIZONTAL:
				currentVelocity.x = launchVelocity.x
				facingDirection = sign(velocity.x)
			_:
				currentVelocity = launchVelocity
				facingDirection = sign(currentVelocity.x)
		jumped = false
		rolling = false
		groundSpeed = 0
		if useJumpSpinAnimation:
			animator.play(animations.run)
			animator.speed_scale = 1
			isJumpSpinning = true
			isSpringJumping = false
			springJumpTimer = 0
		else:
			animator.play(animations.run)
			animator.speed_scale = max(abs(groundSpeed), 0.1)
			isJumpSpinning = false
			isSpringJumping = true
			springJumpTimer = springJumpDuration
		############################################################# endHitState()
	
	if newHorizontalControlLockTime > 0:
		setHorizontalControlLock(newHorizontalControlLockTime)

func setHorizontalControlLock(time : float, keepLongerTime : bool = true):
	hControlLock = true
	hControlLockTimer = keepLongerTime if max(time, hControlLockTimer) else time

func setHitState(source : Vector2, damage : bool = true):
	isHit = true
	postHitInvulnerabilityTimer = 0
	isBraking = false
	isSpringJumping = false
	isJumpSpinning = false
	characterAngle = 0
	grounded = false
	jumped = false
	
	# Jumping resets the horizontal control lock
	hControlLock = false
	hControlLockTimer = 0
	var hitStateVelocity : Vector2 = currentMovementSettings.hitStateVelocity
	var positionDif : float = position.x - source.x
	
	# If the damage source is nearly directly above or below us, default to getting knocked away from where we are facing at a lower speed
	if abs(positionDif) < 1:
		currentVelocity = Vector2(hitStateVelocity.x * -facingDirection, hitStateVelocity.y)
	else:
		currentVelocity = Vector2(hitStateVelocity.x * sign(positionDif), hitStateVelocity.y)
	
func _ready():
	facingDirection = 1
	setCollisionLayer(0)

func _draw():
	if showDebug:
		$Canvas/Debug.visible = true
		$"Canvas/Debug/Input Jump".button_pressed = inputJump
		$"Canvas/Debug/Input Move".text = "Input Move: " + str(inputMove)
		$Canvas/Debug/Underwater.button_pressed = underwater
		$Canvas/Debug/Jumped.button_pressed = jumped
		$Canvas/Debug/Rolling.button_pressed = rolling
		$"Canvas/Debug/Control Lock".button_pressed = hControlLock
		$Canvas/Debug/Grounded.button_pressed = grounded
		$"Canvas/Debug/Air Drag".button_pressed = shouldApplyAirDrag
		$Canvas/Debug/Mode.text = "Mode: " + str(currentGroundMode)
		$"Canvas/Debug/Ground Speed".text = "Ground Speed: " + str(groundSpeed)
		$Canvas/Debug/Velocity.text = "Velocity: " + str(currentVelocity)
		if currentGroundInfo.isValid:
			$Canvas/Debug/Angle.text = "Angle (Deg): " + str(rad2deg(currentGroundInfo.angle))
		else:
			$Canvas/Debug/Angle.text = "Angle (Deg): --"
		$Canvas/Debug/Layer.text = "Layer: " + ("A" if currentGroundMask == collisionMaskA else "B")
	update()

func applyMovement(delta : float):
	# Clamp velocity to global speed limit
	currentVelocity.x = clamp(currentVelocity.x, -globalSpeedLimit, globalSpeedLimit)
	currentVelocity.y = clamp(currentVelocity.y, -globalSpeedLimit, globalSpeedLimit)
	
	# Apply movement
	position += Vector2(currentVelocity.x, currentVelocity.y) * delta

func doWallCollisions(delta : float, newGrounded : bool, groundMode : GroundMode = GroundMode.FLOOR):
	var startPosition : Vector2 = position
	var leftCastDir : Vector2 = Vector2.LEFT
	var rightCastDir : Vector2 = Vector2.RIGHT
	var castDistance = wallCollisionWidthHalf
	
	if grounded:
		startPosition += currentVelocity * delta
		
		match groundMode:
			GroundMode.FLOOR:
				leftCastDir = Vector2.LEFT
				rightCastDir = Vector2.RIGHT
			GroundMode.RIGHT_WALL:
				leftCastDir = Vector2.DOWN
				rightCastDir = Vector2.UP
			GroundMode.CEILING:
				leftCastDir = Vector2.RIGHT
				rightCastDir = Vector2.LEFT
			GroundMode.LEFT_WALL:
				leftCastDir = Vector2.UP
				rightCastDir = Vector2.DOWN
		
		if currentGroundInfo.angle == 0:
			startPosition.y += flatGroundSideRaycastOffset
			if rolling:
				startPosition.y += rollingPositionOffset
	else:
		castDistance = max(wallCollisionWidthHalf, abs(currentVelocity.x) * delta)
	
	if (grounded and groundSpeed < 0) or (!grounded and currentVelocity.x < 0):
		var hitCountCast : RayCast2D = RayCast2D.new()
		hitCountCast.position = startPosition
		hitCountCast.target_position = leftCastDir * castDistance
		
		############################################## PLEASE FINISH FUNCTION

func _physics_process(delta : float):
	var accelSpeedCap : float = currentMovementSettings.groundTopSpeed
	if postHitInvulnerabilityTimer > 0:
		postHitInvulnerabilityTimer = move_toward(postHitInvulnerabilityTimer, 0, delta)
		if postHitInvulnerabilityTimer <= 0:
			animator.play(animations.hit)
			animator.speed_scale = 1
	
	if grounded:
		var slopeFactor : float = 0
		var sinGroundAngle = sin(currentGroundInfo.angle)
		var cosGroundAngle = cos(currentGroundInfo.angle)
		
		if rolling:
			var isUphill : bool = (sinGroundAngle >= 0 and groundSpeed >= 0) or (sinGroundAngle <= 0 and groundSpeed <= 0)
			slopeFactor = rollUphillSlopeFactor if isUphill else rollDownhillSlopeFactor
		else:
			slopeFactor = defaultSlopeFactor
		
		groundSpeed += (slopeFactor * -sinGroundAngle) * delta
		
		if (!jumped and inputJump and !inputJumpLastFrame) and !lowCeiling:
			var jumpVel : float = currentMovementSettings.jumpVelocity
			currentVelocity.x -= jumpVel * sinGroundAngle
			currentVelocity.y += jumpVel * cosGroundAngle
			isBraking = false
			grounded = false
			jumped = true
			
			hControlLock = false
			hControlLockTimer = 0
		else:
			if hControlLock:
				hControlLockTimer -= delta
				if hControlLockTimer <= 0:
					hControlLock = false
			
			var prevGroundSpeedSign : float = sign(groundSpeed)
			
			if rolling or inputMove.x == 0:
				var currentFriction : float = currentMovementSettings.rollingFriction if rolling else currentMovementSettings.friction
				groundSpeed = move_toward(groundSpeed, 0, currentFriction * delta)
			
			if !hControlLock and inputMove.x != 0:
				var acceleration : float = 0
				var movingAgainstCurrentSpeed : bool = groundSpeed == 0 and sign(inputMove.x) != sign(groundSpeed)
				
				if rolling and movingAgainstCurrentSpeed:
					acceleration = currentMovementSettings.rollingDeceleration
				elif !rolling and movingAgainstCurrentSpeed:
					acceleration = currentMovementSettings.deceleration
					if !isBraking and currentGroundMode == GroundMode.FLOOR and abs(groundSpeed) >= brakeGroundSpeedThreshold:
						isBraking = true
				elif !rolling and !movingAgainstCurrentSpeed:
					acceleration = currentMovementSettings.groundAcceleration
				
				if inputMove.x < 0 and groundSpeed > -accelSpeedCap:
					groundSpeed = max(-accelSpeedCap, groundSpeed + (inputMove.x * acceleration) * delta)
				elif inputMove.x > 0 and groundSpeed < accelSpeedCap:
					groundSpeed = min(accelSpeedCap, groundSpeed + (inputMove.x * acceleration) * delta)
				
				if sign(inputMove.x) == sign(groundSpeed):
					facingDirection = sign(inputMove.x)
			
			# Clamp ground speed to global speed limit
			groundSpeed = clamp(groundSpeed, -globalSpeedLimit, globalSpeedLimit)
			
			# We're now moving the other direction, stop braking early if needed
			if isBraking and sign(groundSpeed) != prevGroundSpeedSign:
				isBraking = false
			
			if rolling and abs(groundSpeed) < unrollThreshold:
				rolling = false
				position += Vector2(0, rollingPositionOffset)
			
			var angledSpeed : Vector2 = Vector2(groundSpeed * cos(currentGroundInfo.angle), groundSpeed * sin(currentGroundInfo.angle))
			currentVelocity = angledSpeed
		
		doWallCollisions(delta, grounded, currentGroundMode)
		
		var hasVerticalInput : bool = inputMove.y != 0
		
		# If we're not moving, check if we're looking up or down
		if groundSpeed == 0:
			isBraking = false
			
			if hasVerticalInput:
				if inputMove.y < 0:
					groundSpeed = 0
					lookingDown = true
					lookingUp = false
				elif inputMove.y > 0:
					groundSpeed = 0
					lookingDown = false
					lookingUp = true
			else:
				lookingDown = false
				lookingUp = false
		else:
			lookingDown = false
			lookingUp = false
			
			if !rolling and hasVerticalInput:
				if inputMove.y < 0 and abs(groundSpeed) >= rollingMinSpeed:
					rolling = true
					isBraking = false
					# When rolling, offset position downwards
					position -= Vector2(0, rollingPositionOffset)
		
		applyMovement(delta)
	else:
		if !isHit:
			# If we are moving up faster than the threshold and the jump button is released, clamp our upward velocity to the threshold to allow for some jump height control
			var jumpReleaseThreshold : float = currentMovementSettings.jumpReleaseThreshold
			if jumped and !inputJump and currentVelocity.y > jumpReleaseThreshold:
				currentVelocity.y = jumpReleaseThreshold
			
			if !(rolling and jumped) and inputMove.x != 0:
				var airAcc : float = currentMovementSettings.airAcceleration
				if inputMove.x < 0 and currentVelocity.x > -accelSpeedCap:
					currentVelocity.x = max(-accelSpeedCap, currentVelocity.x + (inputMove.x * airAcc * delta))
				elif inputMove.x > 0 and currentVelocity.x < accelSpeedCap:
					currentVelocity.x = min(accelSpeedCap, currentVelocity.x + (inputMove.x * airAcc * delta))
				
				facingDirection = sign(inputMove.x)
			
			if shouldApplyAirDrag:
				velocity.x -= velocity.x * currentMovementSettings.airDrag
			
			if characterAngle > 0 and characterAngle <= 180:
				characterAngle -= delta * uprightRotationRate
				if characterAngle < 0: characterAngle = 0
			elif characterAngle < 360 and characterAngle > 180:
				characterAngle += delta * uprightRotationRate
				if characterAngle >= 360: characterAngle = 0
		
		applyMovement(delta)
		
		var gravity = currentMovementSettings.hitStateGravity if isHit else currentMovementSettings.gravity
		currentVelocity.y = max(currentVelocity.y + (gravity * delta), -currentMovementSettings.terminalVelocity)
		
		doWallCollisions(delta, grounded)
	
	var ceilingLeft : bool = false
	var ceilingRight : bool = false
	
	################################## FINISH FIXEDUPDATE
