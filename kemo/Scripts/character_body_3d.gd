extends CharacterBody3D

const SPEED = 15.0
const SPEED_SLIDE = 25.0
const JUMP_VELOCITY = 9.0
const SLIDE_TIME = 1.0   
const SLIDE_COOLDOWN = 1.5 

@onready var animation_body = $body
@onready var animation_color = $color

var is_sliding = false
var slide_timer = 0.0
var slide_cooldown_timer = 0.0  

func _physics_process(delta: float) -> void:
	# Update cooldown
	if slide_cooldown_timer > 0:
		slide_cooldown_timer -= delta

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Slide start (เช็กเงื่อนไข 3 อย่าง: on_floor, มี direction, cooldown หมด)
	if Input.is_action_just_pressed("slide") and is_on_floor() and direction and not is_sliding and slide_cooldown_timer <= 0:
		is_sliding = true
		slide_timer = SLIDE_TIME
		slide_cooldown_timer = SLIDE_COOLDOWN
		velocity.x = direction.x * SPEED_SLIDE
		velocity.z = direction.z * SPEED_SLIDE
		animation_body.play("slide")
		animation_color.play("slide")
	
	# Slide update
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			is_sliding = false
	else:
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			
			if direction.x > 0:
				animation_body.flip_h = true
				animation_color.flip_h = true
			elif direction.x < 0:
				animation_body.flip_h = false
				animation_color.flip_h = false
				
			animation_body.play("run")
			animation_color.play("run")
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			animation_body.play("idle")
			animation_color.play("idle")

	move_and_slide()
