# 敌人基类，继承自 CharacterBody2D，提供基础移动和死亡逻辑
class_name Enemy
extends CharacterBody2D

# 方向枚举
enum Direction {
	LEFT = -1,
	RIGHT = +1,
}

signal died  # 死亡信号

# 朝向，LEFT 向左，RIGHT 向右
@export var direction := Direction.LEFT:
	set(v):
		direction = v
		if not is_node_ready():
			await ready
		graphics.scale.x = -direction  # 角色朝向切换
@export var max_speed: float = 180  # 最大速度
@export var acceleration: float = 2000  # 加速度

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float  # 默认重力

# 组件引用
@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var state_machine: Node = $StateMachine
@onready var stats: Node = $Stats

# 敌人移动逻辑
func move(speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, speed * direction, acceleration * delta)
	velocity.y += default_gravity * delta
	
	move_and_slide()

# 死亡处理，发送信号并销毁自身
func die() -> void:
	died.emit()
	queue_free()
