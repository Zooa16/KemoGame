extends Node3D

@onready var animated = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready():
    # Play the "spin" animation
    animated.play("spin")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    # Check if the animation has finished playing
    if animated.is_playing() == false:
        # If it has, play it again from the beginning
        animated.play("spin")
