extends Control

@onready var play_button = $Playbutton
@onready var tutorial_button = $Tutorialbutton

func _ready():
    play_button.pressed.connect(_on_play_pressed)
    tutorial_button.disabled = true   # ปิดไว้ก่อนเพราะยังไม่ทำ

func _on_play_pressed():
    # พอกด Play ให้ไปหน้า main ที่มี host/join
    get_tree().change_scene_to_file("res://multiplayerอย่าย้ายไฟล์/main.tscn")
