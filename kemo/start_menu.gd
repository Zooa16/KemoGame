# ไฟล์: start_menu.gd

extends Control

@onready var play_button = $Playbutton
@onready var tutorial_button = $Tutorialbutton
@onready var playername_input = $Playername
@onready var status = $status
@onready var confirm_button = $confirm
@onready var status_timer: Timer = $status_timer

const MAX_NAME_LENGTH = 12

func _ready():
	# เชื่อมต่อสัญญาณของปุ่ม Play และปุ่มยืนยัน
	play_button.pressed.connect(_on_play_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	
	# เชื่อมต่อสัญญาณ timeout ของ Timer เพื่อลบข้อความสถานะ
	status_timer.timeout.connect(_on_status_timer_timeout)
	status.modulate = Color.WHITE
	# ตั้งค่าเริ่มต้น
	tutorial_button.disabled = true
	play_button.disabled = true # ปิดปุ่ม Play ไว้ก่อนจนกว่าจะยืนยันชื่อ
	status.text = ""

func _on_confirm_button_pressed():
	var player_name = playername_input.text.strip_edges()
	
	if player_name.is_empty():
		player_name = "Player"
		
	var original_name_length = player_name.length()
	
	# ตรวจสอบความยาวของชื่อและตัดชื่อถ้าจำเป็น
	if original_name_length > MAX_NAME_LENGTH:
		player_name = player_name.substr(0, MAX_NAME_LENGTH)
		status.modulate = Color.RED
		status.text = "Over %d remaining! This name already." % MAX_NAME_LENGTH
	else:
		status.modulate = Color.GREEN
		status.text = "Name changed successfully!"
		
	# กำหนดชื่อใหม่ให้กับ Global
	Global.my_player_name = player_name
	
	# แสดงชื่อที่ถูกยืนยันแล้วในช่องกรอกชื่อ
	playername_input.text = player_name
	
	# เปิดปุ่ม Play และเริ่ม Timer เพื่อล้างข้อความสถานะ
	play_button.disabled = false
	status_timer.start()

func _on_status_timer_timeout():
	# ฟังก์ชันนี้จะถูกเรียกเมื่อ Timer หมดเวลา
	status.text = ""

func _on_play_pressed():
	# ไปหน้า main ที่มี host/join
	get_tree().change_scene_to_file("res://multiplayerอย่าย้ายไฟล์/main.tscn")
