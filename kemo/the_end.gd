extends Control


@onready var label = $Label
@onready var color_rect = $ColorRect
@onready var timer = $Timer

# ฟังก์ชันนี้ใช้สำหรับตั้งค่าข้อความเมื่อฉากถูกเรียกใช้
func set_end_message(message: String):
    label.text = message
    timer.start() # เริ่มตัวจับเวลา 5 วินาทีทันที

func _ready():
    # ตรวจสอบให้แน่ใจว่าหน้าจอเป็นสีดำเริ่มต้น
    color_rect.modulate.a = 0.0

# สัญญาณเมื่อ Timer ครบกำหนด 5 วินาที
func _on_timer_timeout():
    # เริ่มการเปลี่ยนสีหน้าจอให้เป็นสีขาว
    var tween = create_tween()
    tween.tween_property(color_rect, "modulate:a", 1.0, 3.0) # เปลี่ยนสีเป็นสีขาวภายใน 3 วินาที
    await tween.finished
    
    # รีเซ็ตข้อมูลเกมทั้งหมดใน Global
    reset_global_data()
    
    # ย้ายไปยังฉาก Start Menu
    get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")

func reset_global_data():
    Global.collected_cards_by_player.clear()
    Global.the_mission_team.clear()
    Global.no_mission_team.clear()
    Global.eliminated_player_id = -1
    Global.mission_wins = 0
    Global.mission_losses = 0
    Global.mission_success = false
    Global.revealed_role = false
    Global.player_roles.clear()
    Global.four_digit_code = ""
    Global.spawned_card_numbers.clear()
    Global.round_number = 1
    Global.leader_id = -1
    # Global.my_player_name ไม่ต้องรีเซ็ตตามที่คุณต้องการ
