# Global.gd
extends Node

var mission_size: int = 0

var mission_wins: int = 0
var mission_losses: int = 0
# ⭐ NEW: ตัวแปรสำหรับเก็บผลลัพธ์ของภารกิจ
var mission_success: bool = false

var revealed_role: bool = false
var my_player_name: String = "Player"
var player_colors: Dictionary = {}
var player_names: Dictionary = {}
var player_roles: Dictionary = {}
var four_digit_code: String = ""
var spawned_card_numbers: Array = []
var message_log: Array = []

var selected_hunter_id = -1

# Dictionary to store collected card numbers per player
# Key: player ID, Value: Array of collected card numbers
var collected_cards_by_player: Dictionary = {}

# เพิ่มตัวแปร the_mission_team: Array เพื่อเก็บรายชื่อผู้เล่นในทีมภารกิจ
var the_mission_team: Array = []
var no_mission_team: Array = []

var round_number: int = 1
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

# NEW: ตัวแปรสำหรับเก็บ ID คอมพิวเตอร์ที่ถูกเปิดใช้งาน
var computer_ids_to_activate: Array = []:
	set(value):
		computer_ids_to_activate = value
		# DEBUG: print to confirm the value is set and signal is emitted
		print("DEBUG: Global.computer_ids_to_activate was updated to ", value)
		emit_signal("computer_ids_updated")
		
signal computer_ids_updated # ต้องประกาศ signal ก่อนใช้งาน

# ⭐ NEW: เพิ่มตัวแปรสำหรับเก็บรหัสผ่านที่กรอก
var entered_password: String = "":
	set(value):
		entered_password = value
		print("DEBUG: Global.entered_password was updated to ", value)
		emit_signal("password_updated")

# ⭐ NEW: เพิ่ม Signal สำหรับแจ้งเตือนเมื่อรหัสผ่านถูกอัปเดต
signal password_updated


func reset_global_data():
	collected_cards_by_player.clear()
	the_mission_team.clear()
	no_mission_team.clear()
	eliminated_player_id = -1
	mission_wins = 0
	mission_losses = 0
	mission_success = false
	revealed_role = false
	player_roles.clear()
	four_digit_code = ""
	spawned_card_numbers = []
	round_number = 1
	

# -------------------------
# NEW: LOGGING FUNCTION (Host/Server only)
# -------------------------
func add_to_message_log(message: String) -> void:
	# ⭐ แก้ไขเงื่อนไขการตรวจสอบเครือข่ายสำหรับ Godot 4
	# ตรวจสอบว่าเป็น Editor หรือ ไม่มี Peer (ไม่ได้เชื่อมต่อ) หรือ เป็น Server (Host)
	if Engine.is_editor_hint() or (multiplayer.get_multiplayer_peer() == null) or multiplayer.is_server():
		# ใช้ Time.get_time_string_from_system() เพื่อเพิ่ม Timestamp
		var timestamp = Time.get_time_string_from_system() 
		var log_entry = "[%s] %s" % [timestamp, message]
		
		# บันทึกเข้า Array log
		message_log.append(log_entry)
		
		# แสดงผลในคอนโซลของ Host
		print("GAME LOG (Host): ", log_entry)
	else:
		# ป้องกัน Client ไม่ให้เรียกฟังก์ชันนี้โดยตรงโดยไม่ตั้งใจ
		print("WARNING: Client tried to call add_to_message_log directly.")
