extends CanvasLayer

signal role_reveal_finished

@onready var black_screen: ColorRect = $ColorRect
@onready var label: Label = $Label

func show_role(role: String, duration: float = 6) -> void:
    # กำหนดชื่อและสีของ Role
    label.text = role
    if Global.role_colors.has(role):
        label.modulate = Global.role_colors[role]
    else:
        label.modulate = Color.WHITE

    # ตั้งค่าเริ่มต้น: หน้าจอเป็นสีดำสนิท และตัวอักษรยังมองไม่เห็น
    black_screen.modulate.a = 1.0
    label.modulate.a = 0.0

    # สร้าง Tween
    var tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    # ลำดับอนิเมชัน
    # 1. ค้างหน้าจอดำไว้ 1 วินาที
    tween.tween_interval(1.0)

    # 2. ตัวอักษรค่อยๆ ปรากฏขึ้นในเวลา 1 วินาที
    tween.tween_property(label, "modulate:a", 1.0, 1.0)

    # 3. ค้างหน้าจอไว้เพื่อให้ผู้เล่นอ่าน role
    var visible_time = max(0, duration - 1.0 - 1.0 - 1.0)
    tween.tween_interval(visible_time)

    # 4. หน้าจอสีดำและตัวอักษรค่อยๆ จางหายไปพร้อมกันใน 1 วินาที
    tween.parallel().tween_property(black_screen, "modulate:a", 0.0, 3.0)
    tween.parallel().tween_property(label, "modulate:a", 0.0, 3.0)
    
    # 5. เมื่อ animation ทั้งหมดจบลง ให้ปล่อยสัญญาณ
    await tween.finished
    emit_signal("role_reveal_finished")
    queue_free() # สามารถลบตัวเองออกได้
