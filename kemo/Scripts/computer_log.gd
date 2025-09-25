extends Area3D

@onready var VBoxContainer_ =$Panel/VBoxContainer
@onready var Panel_ = $Panel

func _ready():
	Panel_.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited) 

func _on_body_entered(body):
	if body.is_in_group("players"):
		Panel_.show()
		
func _on_body_exited(body):
	Panel_.hide()
