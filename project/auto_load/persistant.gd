extends Node

var current_scene = null

#Player variables
var player_hp = 1
var player_ammo = 1

func _ready():
	var root = get_tree().get_root()
	current_scene = root.get_child( root.get_child_count() -1 )

func goto_level(path,door):
    call_deferred("_deferred_goto_scene",path,door)

func _deferred_goto_scene(path,door):
	var player = current_scene.get_node("Player")
	player_hp = player.health
	player_ammo = player.ammo
	
	current_scene.free()
	var s = ResourceLoader.load(path)
	print(s)
	current_scene = s.instance()
	get_tree().get_root().add_child(current_scene)
	get_tree().set_current_scene( current_scene )
	
	#Find the door to put the player at
	var exit_door = null
	for child in current_scene.get_children():
		if child.get("door_num") != null:
			if child.door_num == door:
				exit_door = child
	
	player = current_scene.get_node("Player")
	#Move player to correct door
	if exit_door != null:
		player.set_global_pos(exit_door.get_global_pos())
	#Set player variables
	player.health = player_hp
	player.ammo = player_ammo
	player.get_node("CanvasLayer/Info/Health").set_text("Health: " + str(player_hp))
	player.get_node("CanvasLayer/Info/Ammo").set_text("Ammo: " + str(player_ammo))