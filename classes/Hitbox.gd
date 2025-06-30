# 攻击判定盒，继承自 Area2D
class_name Hitbox
extends Area2D

# 命中信号，参数为被命中的 hurtbox
signal hit(hurtbox)

# 初始化时连接 area_entered 信号
func _init() -> void:
	area_entered.connect(_on_area_entered)

# 区域进入回调，处理命中逻辑
func _on_area_entered(hurtbox: Hurtbox) -> void:
	print("[Hit] %s => %s" % [owner.name, hurtbox.owner.name])  # 打印命中信息
	hit.emit(hurtbox)  # 发送命中信号
	hurtbox.hurt.emit(self)  # 通知被命中的对象受伤
