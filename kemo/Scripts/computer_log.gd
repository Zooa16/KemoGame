extends Area3D

@onready var target =

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("players"):
		body.global_position = target.global_position
		
		# reset ความเร็วเฉพาะถ้าเป็น CharacterBody3D
		if body is CharacterBody3D:
			body.velocity = Vector3.ZERO
