extends CharacterBody3D 

const SPEED = 5.0
const SPEED_SLIDE = 10.0
const JUMP_VELOCITY = 9.0
const SLIDE_TIME = 1.0   
const SLIDE_COOLDOWN = 1.5 

@onready var animation_body: AnimatedSprite3D = $body
@onready var animation_color: AnimatedSprite3D = $color
@onready var camera = $body/Camera3D
@onready var player_name_label: Label3D = $Label3D # เพิ่มบรรทัดนี้

var is_sliding = false
var slide_timer = 0.0
var slide_cooldown_timer = 0.0  
var gravity = 20.0
var mouse_locked = true

# state sync
var target_position: Vector3
var target_rotation_y: float
var current_anim: String = ""   # เก็บ state animation ปัจจุบัน

func _enter_tree():
    set_multiplayer_authority(str(name).to_int())

func _ready():
    if not is_multiplayer_authority():
        camera.current = false
    else:
        camera.current = true

func _physics_process(delta):
    if is_multiplayer_authority():
        if slide_cooldown_timer > 0:
            slide_cooldown_timer -= delta

        if not is_on_floor():
            velocity.y -= gravity * delta

        if Input.is_action_just_pressed("jump") and is_on_floor():
            velocity.y = JUMP_VELOCITY
        
        var input_dir := Input.get_vector("left", "right", "forward", "back")
        var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

        # Slide start
        if Input.is_action_just_pressed("slide") and is_on_floor() and direction and not is_sliding and slide_cooldown_timer <= 0:
            is_sliding = true
            slide_timer = SLIDE_TIME
            slide_cooldown_timer = SLIDE_COOLDOWN
            velocity.x = direction.x * SPEED_SLIDE
            velocity.z = direction.z * SPEED_SLIDE
            play_anim_all("slide")
            
        # Slide update
        if is_sliding:
            slide_timer -= delta
            if slide_timer <= 0:
                is_sliding = false
        else:
            if direction:
                velocity.x = direction.x * SPEED
                velocity.z = direction.z * SPEED
                play_anim_all("run")

                if direction.x > 0:
                    set_flip_all(true)
                elif direction.x < 0:
                    set_flip_all(false)
                else:
                    set_flip_all(false)
            else:
                velocity.x = move_toward(velocity.x, 0, SPEED)
                velocity.z = move_toward(velocity.z, 0, SPEED)
                play_anim_all("idle")

        move_and_slide()
        update_state.rpc(global_position, rotation.y)
    else:
        # smooth client interpolation
        global_position = global_position.lerp(target_position, 0.2)
        rotation.y = lerp_angle(rotation.y, target_rotation_y, 0.2)

# ---------------- RPC ----------------
@rpc("unreliable", "any_peer")
func update_state(new_pos: Vector3, new_rot_y: float):
    target_position = new_pos
    target_rotation_y = new_rot_y

# ลบ @rpc(...) ออก
func set_initial_position(new_pos: Vector3):
    # ตั้งค่าตำแหน่งเริ่มต้นทันทีที่ได้รับจาก Host
    global_position = new_pos
    target_position = new_pos
    
@rpc("unreliable", "any_peer")
func set_animation_and_flip(anim_name: String):
    if current_anim == anim_name: 
        return
    current_anim = anim_name
    _play_anim(animation_body, anim_name)
    _play_anim(animation_color, anim_name)

@rpc("unreliable", "any_peer")
func set_flip_all_rpc(flip: bool):
    animation_body.flip_h = flip
    animation_color.flip_h = flip

@rpc("any_peer", "reliable", "call_local")
func set_player_name(new_name: String):
    # กำหนดชื่อบน Label3D
    if player_name_label:
        player_name_label.text = new_name

@rpc("any_peer", "reliable", "call_local")
func set_player_color(new_color: Color):
    # กำหนดสีให้ AnimatedSprite3D
    if animation_color:
        animation_color.modulate = new_color
# ---------------- Helper ----------------
func _play_anim(sprite: AnimatedSprite3D, anim_name: String):
    if sprite.animation != anim_name:
        sprite.play(anim_name)

# ฟังก์ชันใหม่ → เรียก local + rpc พร้อมกัน
func play_anim_all(anim_name: String):
    set_animation_and_flip(anim_name)      # local
    set_animation_and_flip.rpc(anim_name)  # ส่งไป client อื่น

func set_flip_all(flip: bool):
    set_flip_all_rpc(flip)       # local
    set_flip_all_rpc.rpc(flip)   # sync ไปทุก client
