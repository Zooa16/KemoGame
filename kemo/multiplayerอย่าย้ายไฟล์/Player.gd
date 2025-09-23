extends CharacterBody3D

const SPEED = 5.0
const SPEED_SLIDE = 10.0
const JUMP_VELOCITY = 9.0
const SLIDE_TIME = 1.0
const SLIDE_COOLDOWN = 1.5

@onready var animation_body: AnimatedSprite3D = $body
@onready var animation_color: AnimatedSprite3D = $color
@onready var player_name_label: Label3D = $Label3D
@onready var spring_arm: SpringArm3D = $body/SpringArm3D
@onready var camera: Camera3D = $body/SpringArm3D/Camera3D

# NEW: role label node
@onready var role_label: Label3D = $RoleLabel
@onready var role_label2: Label3D = $RoleLabel2

# ⭐ NEW: Card-related properties and nodes
var collected_cards: Array = []
var max_cards_to_collect: int = 3
@onready var drop_cards_button = get_node("/root/game/UI/DropCardsButton")

var is_sliding = false
var slide_timer = 0.0
var slide_cooldown_timer = 0.0
var gravity = 20.0
var mouse_locked = true

# The role of this player node (synced via RPC)
var role: String = ""

# state sync
var target_position: Vector3
var target_rotation_y: float
var current_anim: String = ""

# ⭐ NEW: Add a signal to notify the game manager about card collection changes.
signal card_collected_updated(collected_count)


func _enter_tree():
    set_multiplayer_authority(str(name).to_int())

func _ready():
    add_to_group("players")
    if not is_multiplayer_authority():
        camera.current = false
    else:
        camera.current = true
        spring_arm.spring_length = 32.0
        spring_arm.collision_mask = 1
    
    set_player_name(Global.my_player_name)
    
    if role_label:
        role_label.text = ""
        role_label.visible = false
    if role_label2:
        role_label2.text = ""
        role_label2.visible = false
    
    # ⭐ NEW: Call the update function to set the initial visibility.
    update_drop_button_visibility()

# ---------------- ROLE HANDLING ----------------
@rpc("any_peer", "reliable", "call_local")
func set_role(new_role: String, is_leader: bool = false):
    role = new_role
    print("Assigned role:", role, " Leader:", is_leader, " to peer:", get_multiplayer_authority())
    
    if is_leader:
        Global.leader_id = get_multiplayer_authority()
    elif Global.leader_id == get_multiplayer_authority():
        Global.leader_id = -1

    if is_multiplayer_authority():
        if role_label:
            var private_text = "Role: " + new_role
            role_label.text = private_text
            if Global.role_colors.has(new_role):
                role_label.modulate = Global.role_colors[new_role]
            role_label.visible = true
        
        var reveal_scene = preload("res://Scenes/role_reveal.tscn").instantiate()
        get_tree().root.add_child(reveal_scene)
        reveal_scene.show_role(new_role, is_leader)
        
        if multiplayer.is_server():
            var gm_node = get_tree().get_root().get_node("GameManager")
            if gm_node:
                reveal_scene.role_reveal_finished.connect(Callable(gm_node, "on_role_reveal_finished"))

    rpc("update_role_visibility_all")

@rpc("any_peer", "reliable", "call_local")
func update_role_visibility_all():
    update_role_visibility()

func update_role_visibility():
    if role_label2:
        if Global.leader_id == get_multiplayer_authority():
            role_label2.text = "Leader"
            role_label2.modulate = Global.role_colors["Leader"]
            role_label2.visible = true
        else:
            role_label2.visible = false
            
    if role_label:
        if is_multiplayer_authority():
            role_label.visible = true
        else:
            role_label.visible = false
            

#---------------- CARD INVENTORY ----------------
# ⭐ NEW: RPC function to add a card to the player's inventory
@rpc("any_peer", "call_local")
func add_card(card_id: String):
    # This function is called by the server on the client's instance.
    if collected_cards.size() >= max_cards_to_collect:
        return
        
    if card_id in collected_cards:
        return
        
    collected_cards.append(card_id)
    print("Player ", get_multiplayer_authority(), " has now collected ", collected_cards.size(), " cards.")
    
    # ⭐ NEW: The button visibility logic now happens here, on the client.
    update_drop_button_visibility()

# ⭐ NEW: Function to control the button's visibility.
# ⭐ NEW: Function to control the button's visibility.
func update_drop_button_visibility():
    if is_multiplayer_authority():
        if is_instance_valid(drop_cards_button):
            if collected_cards.size() >= 1:
                drop_cards_button.show()
            else:
                drop_cards_button.hide()
# ---------------- MOVEMENT / SYNC ----------------
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
        global_position = global_position.lerp(target_position, 0.2)
        rotation.y = lerp_angle(rotation.y, target_rotation_y, 0.2)

# ---------------- RPC ----------------
@rpc("unreliable", "any_peer")
func update_state(new_pos: Vector3, new_rot_y: float):
    target_position = new_pos
    target_rotation_y = new_rot_y

func set_initial_position(new_pos: Vector3):
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
    if player_name_label:
        player_name_label.text = new_name

@rpc("any_peer", "reliable", "call_local")
func set_player_color(new_color: Color):
    if animation_color:
        animation_color.modulate = new_color
        
# ---------------- Helper ----------------
func _play_anim(sprite: AnimatedSprite3D, anim_name: String):
    if sprite.animation != anim_name:
        sprite.play(anim_name)

func play_anim_all(anim_name: String):
    set_animation_and_flip(anim_name)
    set_animation_and_flip.rpc(anim_name)

func set_flip_all(flip: bool):
    set_flip_all_rpc(flip)
    set_flip_all_rpc.rpc(flip)
