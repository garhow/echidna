extends Node

class_name MovementSettings

# Ground Movement
var groundAcceleration : float = 168.75
var groundTopSpeed : float = 360
var friction : float = 168.75
var rollingFriction : float = 84.375
var deceleration : float = 1800
var rollingDeceleration = 450

# Air Movement
var airAcceleration : float = 337.5
var jumpVelocity : float = 390
var jumpReleaseThreshold : float = 240
var gravity : float = 787.5
var terminalVelocity : float = 960
var airDrag : float = 0.03125

# Other
var hitStateVelocity : Vector2 = Vector2(120, 240)
var hitStateGravity : float = -675
