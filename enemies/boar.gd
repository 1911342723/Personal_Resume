# 野猪敌人脚本，继承自 Enemy，包含 AI 状态机和受伤逻辑
extends Enemy

# 状态枚举
enum State {
	IDLE,      # 待机
	WALK,      # 巡逻
	RUN,       # 追击玩家
	HURT,      # 受伤
	DYING,     # 死亡
}

const KNOCKBACK_AMOUNT := 512.0  # 受击击退力度

var pending_damage: Damage  # 待处理伤害

# 各种检测器
@onready var wall_checker: RayCast2D = $Graphics/WallChecker  # 墙体检测
@onready var player_checker: RayCast2D = $Graphics/PlayerChecker  # 玩家检测
@onready var floor_checker: RayCast2D = $Graphics/FloorChecker  # 地面检测
@onready var calm_down_timer: Timer = $CalmDownTimer  # 冷静计时器

# 检查是否能看到玩家
func can_see_player() -> bool:
	if not player_checker.is_colliding():
		return false
	return player_checker.get_collider() is Player

# 状态机物理帧逻辑
func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE, State.HURT, State.DYING:
			move(0.0, delta)  # 静止或受伤/死亡时不移动
		
		State.WALK:
			move(max_speed / 3, delta)  # 巡逻慢速移动
		
		State.RUN:
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				direction *= -1  # 碰墙或悬空时转向
			move(max_speed, delta)  # 追击玩家全速移动
			if can_see_player():
				calm_down_timer.start()  # 看到玩家时重置冷静计时

# 状态机决策逻辑，决定下一个状态
func get_next_state(state: State) -> int:
	if stats.health == 0:
		return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	
	if pending_damage:
		return State.HURT
	
	match state:
		State.IDLE:
			if can_see_player():
				return State.RUN
			if state_machine.state_time > 2:
				return State.WALK
		
		State.WALK:
			if can_see_player():
				return State.RUN
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				return State.IDLE
		
		State.RUN:
			if not can_see_player() and calm_down_timer.is_stopped():
				return State.WALK
		
		State.HURT:
			if not animation_player.is_playing():
				return State.RUN
	
	return StateMachine.KEEP_CURRENT

# 状态切换时的处理逻辑
func transition_state(from: State, to: State) -> void:
#	print("[%s] %s => %s" % [
#		Engine.get_physics_frames(),
#		State.keys()[from] if from != -1 else "<START>",
#		State.keys()[to],
#	])
	
	match to:
		State.IDLE:
			animation_player.play("idle")
			if wall_checker.is_colliding():
				direction *= -1
		
		State.WALK:
			animation_player.play("walk")
			if not floor_checker.is_colliding():
				direction *= -1
				floor_checker.force_raycast_update()
		
		State.RUN:
			animation_player.play("run")
		
		State.HURT:
			animation_player.play("hit")
			stats.health -= pending_damage.amount
			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCKBACK_AMOUNT
			if dir.x > 0:
				direction = Direction.LEFT
			else:
				direction = Direction.RIGHT
			pending_damage = null
		
		State.DYING:
			animation_player.play("die")

# 受伤回调，被玩家攻击时触发
func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
