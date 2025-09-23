# Card.gd

extends Area3D

var is_collected = false
@onready var game_node = get_node("/root/game")

func _ready():
	# Only connect the signal on the server to avoid duplicate calls.
	if multiplayer.is_server():
		body_entered.connect(_on_body_entered)
	
	if not is_instance_valid(game_node):
		push_error("Game node not found.")

func _on_body_entered(body):
	# This function now only runs on the server.
	if not body.is_in_group("players"):
		return
		
	# The server checks the multiplayer authority of the player who collided.
	var player_id = body.get_multiplayer_authority()
	
	if is_collected:
		return
		
	if is_instance_valid(game_node):
		print("Server processing card collection for peer: ", player_id)
		game_node.process_card_collection(self.get_path(), player_id)

# This function is now called by the server via RPC. It hides the card.
@rpc("any_peer", "call_local")
func hide_card():
	if not is_collected:
		is_collected = true
		visible = false
		print("Card hidden: ", self.name)
		
# This function is called by the server via RPC. It shows the card at a new position.
@rpc("any_peer", "call_local")
func show_card(new_position: Vector3):
	is_collected = false
	visible = true
	global_transform.origin = new_position
	print("Card shown: ", self.name)
