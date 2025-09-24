extends CanvasLayer


@onready var black_screen: ColorRect = $ColorRect
@onready var label: Label = $Label
# ⭐ NEW: เพิ่ม Timer สำหรับหน่วงเวลาการเปลี่ยนฉาก
@onready var scene_change_timer: Timer = $SceneChangeTimer

func _ready():
    if Global.mission_success:
        label.text = "Mission accomplished!"
        label.modulate = Color.GREEN # เปลี่ยนสีข้อความเป็นสีเขียว
    else:
        label.text = "Mission failed!"
        label.modulate = Color.RED # เปลี่ยนสีข้อความเป็นสีแดง
    
    # ⭐ NEW: เริ่ม Timer เพื่อรอ 5 วินาที
    scene_change_timer.wait_time = 5.0
    scene_change_timer.one_shot = true
    scene_change_timer.timeout.connect(_on_scene_change_timer_timeout)
    scene_change_timer.start()


func _on_scene_change_timer_timeout():
    get_tree().change_scene_to_file("res://Scenes/game.tscn")
