extends Area3D

@onready var VBoxContainer_: VBoxContainer = $Panel/VBoxContainer 
@onready var Panel_ = $Panel
@onready var Close_Button = $Close_Button

# ⭐ ตัวแปรใหม่: จำกัดจำนวนข้อความสูงสุด
const MAX_LOG_ENTRIES := 40
# ⭐ ตัวแปรใหม่: เก็บขนาดของ log ล่าสุดที่ทราบ เพื่อตรวจสอบการอัปเดต
var last_log_size := 0

func _ready():
	Panel_.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# อัปเดต log เริ่มต้นเผื่อมีข้อความอยู่แล้ว
	update_log_display()


func _process(_delta): 
	# ตรวจสอบและอัปเดตเฉพาะเมื่อ Panel แสดงอยู่ และขนาดของ Global.message_log เปลี่ยนไป
	if Panel_.visible and Global.message_log.size() != last_log_size:
		update_log_display()
		
func _on_body_entered(body):
	# ⭐ แก้ไข: ตรวจสอบว่าเป็น Local Player ที่เดินเข้า Area3D นี้หรือไม่
	# เราใช้ get_multiplayer_authority() เพื่อตรวจสอบว่า authority ตรงกับ ID ของ Peer ในเครื่องนี้หรือไม่
	if body.is_in_group("players") and body.get_multiplayer_authority() == multiplayer.get_unique_id():
		Panel_.show()
		# อัปเดต log ทันทีเมื่อเปิด Panel ขึ้นมา
		update_log_display()
		
func _on_body_exited(body):
	# ⭐ แก้ไข: ตรวจสอบว่าเป็น Local Player ที่เดินออกจาก Area3D นี้หรือไม่
	if body.is_in_group("players") and body.get_multiplayer_authority() == multiplayer.get_unique_id():
		Panel_.hide()


# -------------------------------------------------------------
# ⭐ ฟังก์ชันหลักสำหรับอัปเดตและจัดการการแสดงผล Log
# -------------------------------------------------------------
func update_log_display():
	var current_log = Global.message_log
	var new_log_size = current_log.size()
	
	if new_log_size <= last_log_size:
		# ไม่มีข้อความใหม่
		return
		
	# 1. สร้าง Label สำหรับข้อความใหม่ที่เพิ่มเข้ามา
	for i in range(last_log_size, new_log_size):
		var log_entry = current_log[i]
		
		# สร้าง Label ใหม่
		var new_label = Label.new()
		new_label.text = log_entry
		new_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		# เพิ่ม Label เข้าไปใน VBoxContainer
		VBoxContainer_.add_child(new_label)
		
	# 2. จัดการจำนวนข้อความไม่ให้เกิน MAX_LOG_ENTRIES (20)
	var children_count = VBoxContainer_.get_child_count()
	if children_count > MAX_LOG_ENTRIES:
		var excess_count = children_count - MAX_LOG_ENTRIES
		
		# ลบข้อความที่เก่าที่สุด (ซึ่งคือ Child ตัวแรก ๆ ใน VBoxContainer)
		for i in range(excess_count):
			var oldest_label = VBoxContainer_.get_child(0)
			oldest_label.queue_free()
			
	# 3. อัปเดตขนาด Log ล่าสุดที่ทราบ
	last_log_size = new_log_size
