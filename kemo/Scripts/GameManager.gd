# GameManager.gd
extends Node

@rpc("any_peer", "reliable", "call_local")
func start_game():
    print("Changing scene to game...")
    if get_tree():
        get_tree().change_scene_to_file("res://Scenes/game.tscn")
    else:
        push_error("SceneTree not ready!")
