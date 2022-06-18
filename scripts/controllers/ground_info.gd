extends Node
class_name GroundInfo

## The world-space position of the ground point.
var point : Vector2

## The normal vector of the ground point's surface.
var normal : Vector2 = Vector2.ZERO

## The angle (in radians) of the ground point's surface.
var angle : float

## Whether or not the GroundInfo contains valid data.
var isValid : bool
