extends Control

@onready var name_label: Label = $"Panel/NameLabel"
@onready var role_label: Label = $"Panel/RoleLabel"
@onready var vote_button: Button = $"Panel/VoteButton"

var peer_id: int

func setup(peer_id_value: int, name: String, role: String):
	peer_id = peer_id_value
	
	# Debug: make sure nodes are found
	print("DEBUG: NameLabel = ", name_label)
	print("DEBUG: RoleLabel = ", role_label)
	print("DEBUG: VoteButton = ", vote_button)

	if name_label:
		name_label.text = name
	if role_label:
		role_label.text = role
