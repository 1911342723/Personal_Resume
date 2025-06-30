# 玩家属性类，管理生命值、能量值及其变化
class_name Stats
extends Node

# 生命值和能量值变化信号
signal health_changed
signal energy_changed

# 最大生命值、最大能量、能量回复速度（可在编辑器中调整）
@export var max_health: int = 3
@export var max_energy: float = 10
@export var energy_regen: float = 0.8

# 当前生命值，自动限制在 0~max_health 范围，变化时发出信号
@onready var health: int = max_health:
	set(v):
		v = clampi(v, 0, max_health)
		if health == v:
			return
		health = v
		health_changed.emit()

# 当前能量值，自动限制在 0~max_energy 范围，变化时发出信号
@onready var energy: float = max_energy:
	set(v):
		v = clampf(v, 0, max_energy)
		if energy == v:
			return
		energy = v
		energy_changed.emit()

# 每帧自动回复能量
func _process(delta: float) -> void:
	energy += energy_regen * delta

# 属性转为字典，便于存档
func to_dict() -> Dictionary:
	return {
		max_energy=max_energy,
		max_health=max_health,
		health=health,
	}

# 从字典恢复属性
func from_dict(dict: Dictionary) -> void:
	max_energy = dict.max_energy
	max_health = dict.max_health
	health = dict.health
