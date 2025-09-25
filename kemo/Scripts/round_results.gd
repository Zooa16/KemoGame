# round_results.gd
extends CanvasLayer

@onready var result_label: Label = $ResultLabel
@onready var next_round_timer: Timer = $NextRoundTimer
@onready var back_to_menu_button: Button = $BackToMenuButton

func _ready():
    update_result_display()
    
func update_result_display():
    # โค้ดส่วนนี้ถูกต้องแล้ว ไม่ต้องแก้ไข
    var local_player_id = multiplayer.get_unique_id()
    var player_role = Global.player_roles.get(local_player_id, {}).get("base", "Unknown")
    
    var awakened_roles = ["Data Retriever", "Support", "The Oracle", "Hacker"]
    var entity_roles = ["Tracer", "Enforcer", "System Controller"]

    if Global.mission_wins >= 1 or Global.mission_losses >= 1:
        if Global.mission_wins >= 1:
            if player_role in awakened_roles:
                result_label.modulate = Color.GREEN
                result_label.text = "The matrix is broken, you guys have won."
            elif player_role in entity_roles:
                result_label.modulate = Color.GREEN
                result_label.text = "The Awakened's are now under your control."
        else: # Global.mission_losses >= 1
            if player_role in awakened_roles:
                result_label.modulate = Color.RED
                result_label.text = "You are now being controlled by the Entities."
            elif player_role in entity_roles:
                result_label.modulate = Color.RED
                result_label.text = "You win, the Awakened's are now under your control."

        back_to_menu_button.visible = true
        back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
        
    else:
        var result_text = ""
        if Global.mission_success:
            result_text = "ภารกิจสำเร็จ!"
        else:
            result_text = "ภารกิจล้มเหลว..."
        result_label.text = result_text

        back_to_menu_button.visible = false
        next_round_timer.wait_time = 5.0
        next_round_timer.one_shot = true
        next_round_timer.timeout.connect(_on_next_round_timer_timeout)
        next_round_timer.start()

func _on_next_round_timer_timeout():
    if multiplayer.is_server():
        var game_manager = get_node("/root/GameManager")
        if is_instance_valid(game_manager):
            game_manager.start_game.rpc()

func _on_back_to_menu_pressed():
    # ล้างข้อมูล Global บนเครื่องตัวเอง
    Global.reset_global_data()
    # กลับไปหน้าเมนูหลัก
    get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")
