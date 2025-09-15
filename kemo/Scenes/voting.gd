extends Control

@onready var timer_label = $TimerLabel
@onready var player_grid = $PlayerGrid
@onready var skip_button = $SkipButton
@onready var leader_banner = $LeaderBanner/Label

var PlayerCard = preload("res://Scenes/PlayerCard.tscn")
var voting_time := 180  # 3 minutes in seconds

func _ready():
	print("Voting scene loaded")
	
	# Show leader if assigned
	var leader_id = Global.special_roles["Leader"]
	if leader_id != null:
		leader_banner.text = "Leader: " + Global.player_names[leader_id]
	else:
		leader_banner.text = "No Leader Assigned"

	# Build player cards
	for peer_id in Global.player_names.keys():
		var card = PlayerCard.instantiate()
		card.setup(peer_id, Global.player_names[peer_id], "?")  # cleaner setup call
		player_grid.add_child(card)

	# connect the vote button
		card.vote_button.pressed.connect(
		func():
			_on_vote_pressed(peer_id)
	)

	skip_button.pressed.connect(_on_skip_pressed)

	# Start countdown
	set_process(true)

func _process(delta):
	if voting_time > 0:
		voting_time -= delta
		var minutes = int(voting_time) / 60
		var seconds = int(voting_time) % 60
		timer_label.text = str(minutes) + ":" + str(seconds).pad_zeros(2)
	else:
		_end_voting()

func _on_vote_pressed(peer_id):
	print("Voted for", Global.player_names[peer_id])
	# TODO: send vote to server / GameManager

func _on_skip_pressed():
	print("Skip vote pressed")
	# TODO: send skip action to server

func _end_voting():
	print("Voting ended")
	# TODO: tally votes and change scene
	get_tree().change_scene_to_file("res://Scenes/YOUR_NEXT_SCENE.tscn")
