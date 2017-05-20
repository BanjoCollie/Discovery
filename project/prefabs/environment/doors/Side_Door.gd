extends Area2D

export var level = ""
export var door_num = 0
export var exit_door = 0
export var flipped = false
var player

func _ready():
	set_process(true)
	player = get_node("/root/World/Player")
	
	if flipped:
		get_node("Back").set_pos(-get_node("Back").get_pos())
		get_node("Back").set_flip_h(true)
		get_node("Front").set_pos(-get_node("Front").get_pos())
		get_node("Front").set_flip_h(true)
		get_node("Collision").set_pos(-get_node("Collision").get_pos())

func _process(delta):
	if player in get_overlapping_bodies():
		get_node("/root/persistant").goto_level("res://levels/" + level,exit_door)
