# round results.gd
extends CanvasLayer


@onready var black_screen: ColorRect = $ColorRect
@onready var label: Label = $Label


func _ready():
    if Global.mission_success:
        label.text = "ภารกิจสำเร็จ!"
        label.modulate = Color.GREEN # เปลี่ยนสีข้อความเป็นสีเขียว
    else:
        label.text = "ภารกิจล้มเหลว!"
        label.modulate = Color.RED # เปลี่ยนสีข้อความเป็นสีแดง
