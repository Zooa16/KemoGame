# computer.gd
extends Area3D

var computer_id = 3 # เปลี่ยนค่านี้สำหรับแต่ละคอมพิวเตอร์ (1-6) [cite: 4]
@onready var ui_enter_password = $CanvasLayer 
@onready var enter_password = $CanvasLayer/Panel/LineEdit 
@onready var submit_button = $CanvasLayer/Panel/Button

func _ready():
	ui_enter_password.hide() 
	body_entered.connect(_on_body_entered) 
	body_exited.connect(_on_body_exited) 
	
	# NEW: เชื่อมต่อ Signal เพื่อตรวจสอบ ID เมื่อข้อมูลพร้อม
	Global.connect("computer_ids_updated", _on_ids_updated)
	
	#⭐ NEW: เชื่อมต่อ Signal ของปุ่ม submit
	submit_button.pressed.connect(_on_submit_button_pressed)
	
	# ⭐ NEW: เชื่อมต่อ Signal จาก Global เพื่อรับการอัปเดตรหัสผ่าน
	Global.connect("password_updated", _on_password_updated)
func _on_ids_updated():
	if Global.computer_ids_to_activate.has(computer_id):
		print("Computer ID ", computer_id, " is activated. Ready to use.")
		# สามารถเพิ่ม Effect เช่น ไฟเขียว หรืออะไรก็ได้ที่แสดงว่าคอมทำงานได้ [cite: 5]
	else:
		print("Computer ID ", computer_id, " is not activated.") 
		# เพิ่ม Effect เช่น ไฟแดง เพื่อบอกว่าคอมใช้ไม่ได้ [cite: 5]
		set_process(false) # ปิดการทำงานของ _process ถ้ามี [cite: 5]
		set_physics_process(false) # ปิดการทำงานของ _physics_process ถ้ามี [cite: 5]

func _on_body_entered(body):
	if body.is_in_group("players"): 
		if Global.computer_ids_to_activate.has(computer_id):
			ui_enter_password.show()
		else:
			print("This computer is not activated.") 

func _on_body_exited(body):
	if body.is_in_group("players"):
		ui_enter_password.hide() 

# ⭐ NEW: ฟังก์ชันเมื่อกดปุ่ม Submit
func _on_submit_button_pressed():
	var password = enter_password.text
	# ส่งข้อมูลรหัสผ่านไปยังเซิร์ฟเวอร์
	rpc_id(1, "sync_password_to_global", password)

# ⭐ NEW: RPC ที่จะทำงานบนเซิร์ฟเวอร์เพื่อซิงค์ข้อมูล
@rpc("any_peer", "call_local")
func sync_password_to_global(password: String):
	# ตรวจสอบว่าโค้ดนี้ทำงานบนเซิร์ฟเวอร์เท่านั้น
	if not multiplayer.is_server():
		return
		
	# อัปเดตตัวแปรใน Global ซึ่งจะทำให้ Signal 'password_updated' ทำงานบนทุกเครื่อง
	Global.entered_password = password
	
	# ⭐ NEW: สามารถเพิ่มโค้ดตรวจสอบรหัสผ่านได้ที่นี่ในอนาคต
	if password == "1234":
		print("Correct password entered!")
	else:
		print("Incorrect password entered.")
		
# ⭐ NEW: ฟังก์ชันเมื่อรับการอัปเดตจาก Global
func _on_password_updated():
	print("Received password update from Global: ", Global.entered_password)
	# สามารถเพิ่มการแสดงผลบน UI หรือฟังก์ชันอื่น ๆ ได้ที่นี่
