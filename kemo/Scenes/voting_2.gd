extends Control


@onready var player_ui_nodes = {
	1: $Player/player1, 2: $Player/player2, 3: $Player/player3,
	4: $Player/player4, 5: $Player/player5, 6: $Player/player6,
	7: $Player/player7, 8: $Player/player8, 9: $Player/player9,
	10: $Player/player10
}
@onready var player_name_labels = {
	1: $Player/player1/player1_name, 2: $Player/player2/player2_name, 3: $Player/player3/player3_name,
	4: $Player/player4/player4_name, 5: $Player/player5/player5_name, 6: $Player/player6/player6_name,
	7: $Player/player7/player7_name, 8: $Player/player8/player8_name, 9: $Player/player9/player9_name,
	10: $Player/player10/player10_name
}
@onready var player_modulate_nodes = {
	1: $Player/player1/Modulate, 2: $Player/player2/Modulate, 3: $Player/player3/Modulate,
	4: $Player/player4/Modulate, 5: $Player/player5/Modulate, 6: $Player/player6/Modulate,
	7: $Player/player7/Modulate, 8: $Player/player8/Modulate, 9: $Player/player9/Modulate,
	10: $Player/player10/Modulate
}

# Dictionary for the vote status icon
@onready var Selected = {
	1: $Player/player1/Selected, 2: $Player/player2/Selected, 3: $Player/player3/Selected,
	4: $Player/player4/Selected, 5: $Player/player5/Selected, 6: $Player/player6/Selected,
	7: $Player/player7/Selected, 8: $Player/player8/Selected, 9: $Player/player9/Selected,
	10: $Player/player10/Selected
}

@onready var Select_panel = $Select_panel
@onready var Select_button = $Select_panel/Select
@onready var Cancel_button = $Select_panel/Cancel
@onready var skip_button = $Skip_button

@onready var Eliminated_player_ui = $"Eliminated players"
@onready var Eliminated_player_Modulate = $"Eliminated players/Modulate"
@onready var Eliminated_player_name = $"Eliminated players/Modulate/Label"

# New: Add these three new nodes from your scene
@onready var Tie = $Tie
@onready var Skip_vote = $"Skip vote"
@onready var Number_of_votes = $"Vote results/Number of votes"

@onready var proceeding_timer: Timer = $ProceedingTimer

var leader_id: int
var players_to_vote_on: Array = []
var selected_players: Array = []
var current_mission: Dictionary

# Missions data structure
var missions = [
	{"name": "Intel Retrieval", "players_required": 2, "description": "Retrieve critical data from the server."},
	{"name": "System Shutdown", "players_required": 3, "description": "Deactivate the rogue AI's core before it breaches the firewall."},
	{"name": "Sabotage", "players_required": 4, "description": "Sabotage the enemy's main power grid."}
]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
