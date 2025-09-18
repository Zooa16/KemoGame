# Global.gd
extends Node

var my_player_name: String = "Player" # กำหนดค่าเริ่มต้นเป็น "Player"
var player_colors: Dictionary = {}
var player_names: Dictionary = {}
var player_roles: Dictionary = {
	1: {"base": "Enforcer", "leader": false},
	2: {"base": "Support", "leader": false},
	3: {"base": "Tracer", "leader": false},
	4: {"base": "Hacker", "leader": false},
	5: {"base": "Support", "leader": false},
	6: {"base": "Data Retriever", "leader": false},
	7: {"base": "The Oracle", "leader": false},
	8: {"base": "System Controller", "leader": false},
	9: {"base": "Tracer", "leader": false},
	10: {"base": "Support", "leader": true}
} # ✅ only one opening { and one closing }


# List of all possible roles (accessible from anywhere)

var roles: Array = [
	"Data Retriever",
	"Support",
	"The Oracle",
	"Tracer",
	"Hacker",
	"Enforcer",
	"System Controller",
	# "Leader" is handled separately so it doesn't get shuffled out
]

var role_colors := {
	"Data Retriever": Color.BLUE,
	"Support": Color.BLUE,
	"The Oracle": Color.BLUE,
	"Tracer": Color.RED,
	"Hacker": Color.BLUE,
	"Enforcer": Color.RED,
	"System Controller": Color.RED,
	"Leader": Color.YELLOW  # 👑 Leader is gold/yellow so it's visible
}

var role_counts := {
	"Data Retriever": 1,
	"Support": 3,
	"The Oracle": 1,
	"Tracer": 2,
	"Hacker": 1,
	"Enforcer": 1,
	"System Controller": 1,
	# Leader is not randomized by count, handled separately
}

# Store the Leader separately
var leader_id: int = -1


# Store the local player's role (set by Player.gd when it receives its role)
var player_role: String = ""


const MAX_PLAYERS := 10
