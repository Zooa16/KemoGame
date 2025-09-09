# Global.gd
extends Node

var player_colors: Dictionary = {}
var player_names: Dictionary = {}


# List of all possible roles (accessible from anywhere)
var roles: Array = [
"Data Retriever",
"Support",
"The Oracle",
"Tracer",
"Hacker",
"Enforcer",
"System Controller",
]

# Optional: you can also keep colors, icons, descriptions here
var role_colors := {
	"Data Retriever": Color.BLUE,
	"Support": Color.BLUE,
	"The Oracle": Color.BLUE,
	"Tracer": Color.RED,
	"Hacker": Color.BLUE,
	"Enforcer": Color.RED,
	"System Controller": Color.RED,
}


var role_counts := {
"Data Retriever": 1,
"Support": 3,  # ✅ allow 3 Supports
"The Oracle": 1,
"Tracer": 2,   # ✅ allow 2 Tracers
"Hacker": 1,
"Enforcer": 1,
"System Controller": 1,
}

# Store the local player's role (set by Player.gd when it receives its role)
var player_role: String = ""

# Store a reference dictionary if needed {peer_id: role} (server only)
var player_roles := {}
