extends Node

func _ready():
	# ตรวจสอบว่ารหัสที่ผู้เล่นกรอกตรงกับรหัสที่ถูกสร้างขึ้นจากการ์ดหรือไม่
	if Global.entered_password_code == Global.spawned_card_code:
		print("Password is CORRECT!")
		# ใส่โค้ดสำหรับ Logic เมื่อรหัสถูกต้อง เช่น ให้ทีม Data Retriever ชนะ
	else:
		print("Password is INCORRECT!")
		# ใส่โค้ดสำหรับ Logic เมื่อรหัสผิด เช่น ให้ทีม Hacker/Tracer ชนะ
