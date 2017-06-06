extends Area2D

export var level = ""
export var door_num = 0
export var exit_door = 0
var player

func _ready():
	set_process(true)
	player = get_node("/root/World/Player")

func _process(delta):
	if Input.is_action_just_pressed("move_up") && player.state != player.STATE_ABILITY_SELECT:
		if player in get_overlapping_bodies():
			get_node("/root/persistant").goto_level("res://levels/" + level,exit_door)
