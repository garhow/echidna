extends Node

@onready var player = get_parent()

func _physics_process(_delta):
	player.inputMove = Vector2(Input.get_axis("player_move_left", "player_move_right"), Input.get_axis("player_look_down", "player_look_up")).normalized()
	player.inputJump = Input.is_action_pressed("player_jump")
