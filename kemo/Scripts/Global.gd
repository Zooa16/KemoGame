# Global.gd
extends Node

var mission_size: int = 0

var my_player_name: String = "Player"
var player_colors: Dictionary = {}
var player_names: Dictionary = {}
var player_roles: Dictionary = {}

# เพิ่มตัวแปร the_mission_team: Array เพื่อเก็บรายชื่อผู้เล่นในทีมภารกิจ
var the_mission_team: Array = []

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

var role_colors := {
    "Data Retriever": Color.BLUE,
    "Support": Color.BLUE,
    "The Oracle": Color.BLUE,
    "Tracer": Color.RED,
    "Hacker": Color.BLUE,
    "Enforcer": Color.RED,
    "System Controller": Color.RED,
    "Leader": Color.YELLOW
}

var role_counts := {
    "Data Retriever": 1,
    "Support": 3,
    "The Oracle": 1,
    "Tracer": 2,
    "Hacker": 1,
    "Enforcer": 1,
    "System Controller": 1,
}

# Store the Leader separately
var leader_id: int = -1

# Store the local player's role (set by Player.gd when it receives its role)
var player_role: String = ""

# NEW: Store the ID of the eliminated player
var eliminated_player_id: int = -1

const MAX_PLAYERS := 10
