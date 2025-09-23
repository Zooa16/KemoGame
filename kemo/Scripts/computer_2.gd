# computer.gd
extends Area3D

var computer_id = 2 # เปลี่ยนค่านี้สำหรับแต่ละคอมพิวเตอร์ (1-6) [cite: 4]
@onready var ui_enter_password = $CanvasLayer 
@onready var enter_password = $CanvasLayer/Panel/LineEdit 

func _ready():
    ui_enter_password.hide() 
    body_entered.connect(_on_body_entered) 
    body_exited.connect(_on_body_exited) 
    
    # NEW: เชื่อมต่อ Signal เพื่อตรวจสอบ ID เมื่อข้อมูลพร้อม
    Global.connect("computer_ids_updated", _on_ids_updated)
    
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
