extends Node
class_name GroundTile

## If true, when the character performs ground checks and finds this tile, the reported angle
## for movement will be the pre-defined value set in Angle, instead of the raycast hit's angle.
var useFixedGroundAngle : bool = true

## Should be true if the tile has an angled surface.
## If false, this tile is considered fully solid and its reported angle depends on the current movement mode of the character.
var isAngled : bool = true

## The angle, in degrees, used to move along this ground tile.
var angle : float = 0

## If true, characters do not collide with it from underneath, or from the sides.
var isOneWayPlatform : bool = false
