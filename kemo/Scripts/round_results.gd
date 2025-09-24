extends CanvasLayer


@onready var black_screen: ColorRect = $ColorRect
@onready var label: Label = $Label
@onready var scene_change_timer: Timer = $SceneChangeTimer

func _ready():
    # เชื่อมต่อสัญญาณและเริ่มตัวจับเวลาเมื่อ scene ถูกโหลด
    scene_change_timer.timeout.connect(_on_scene_change_timer_timeout)
    scene_change_timer.start()
    
    # ตรวจสอบว่ามีข้อความมาจาก GameManager หรือไม่
    # ถ้าไม่มี ให้ใช้ข้อความตามค่า Global.mission_success
    if not label.text:
        if Global.mission_success:
            label.text = "Mission accomplished!"
            label.modulate = Color.GREEN
        else:
            label.text = "Mission failed!"
            label.modulate = Color.RED

# ฟังก์ชันนี้จะถูกเรียกเมื่อตัวจับเวลาหมดเวลา
func _on_scene_change_timer_timeout():
    GameManager.start_game()
