# 玩家主角控制脚本
# 继承自 CharacterBody2D，负责处理玩家的移动、攻击、受伤、交互等全部核心逻辑
class_name Player
extends CharacterBody2D

# 方向枚举，LEFT 表示左，RIGHT 表示右
enum Direction {
	LEFT = -1,
	RIGHT = +1,
}

# 玩家状态枚举，涵盖站立、奔跑、跳跃、攻击、受伤等所有状态
enum State {
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP,
	ATTACK_1,
	ATTACK_2,
	ATTACK_3,
	HURT,
	DYING,
	SLIDING_START,
	SLIDING_LOOP,
	SLIDING_END,
}

# 地面相关状态集合
const GROUND_STATES := [
	State.IDLE, State.RUNNING, State.LANDING,
	State.ATTACK_1, State.ATTACK_2, State.ATTACK_3,
]
# 各种物理和动作参数
const RUN_SPEED := 100.0  # 跑步速度
const FLOOR_ACCELERATION := RUN_SPEED / 0.2  # 地面加速度
const AIR_ACCELERATION := RUN_SPEED / 0.1    # 空中加速度
const ATTACK_MOVE_DISTANCE = 50              # 攻击时的位移
const JUMP_VELOCITY := -320.0                # 跳跃初速度
const WALL_JUMP_VELOCITY := Vector2(100, -380) # 蹬墙跳速度
const KNOCKBACK_AMOUNT := 512.0              # 受击击退力度
const SLIDING_DURATION := 0.1                # 滑铲持续时间
const SLIDING_SPEED := 256.0/1.25            # 滑铲速度
const SLIDING_ENERGY := 0                  # 滑铲消耗能量
const LANDING_HEIGHT := 100.0                # 判定落地的高度

# 导出变量，方便在编辑器中调整
@export var can_combo := false  # 是否可以连击
@export var direction := Direction.RIGHT:  # 当前朝向
	set(v):
		direction = v
		if not is_node_ready():
			await ready
		graphics.scale.x = direction  # 角色朝向切换

# 运行时变量
var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float  # 默认重力
var is_first_tick := false  # 状态首次进入标记
var is_combo_requested := false  # 是否请求连击
var pending_damage: Damage  # 待处理的伤害
var fall_from_y: float  # 跌落起始高度
var interacting_with: Array[Interactable]  # 当前可交互对象列表

# 组件引用，@onready 保证节点已就绪
@onready var graphics: Node2D = $Graphics
#@onready var animation_player: AnimationPlayer = $AnimationPlaye
@onready var animation_player: AnimatedSprite2D = $Graphics/AnimatedSprite2D

@onready var coyote_timer: Timer = $CoyoteTimer  # 土狼时间计时器
@onready var jump_request_timer: Timer = $JumpRequestTimer  # 跳跃请求计时器
@onready var hand_checker: RayCast2D = $Graphics/HandChecker  # 手部检测
@onready var foot_checker: RayCast2D = $Graphics/FootChecker  # 脚部检测
@onready var state_machine: Node = $StateMachine  # 状态机节点
@onready var stats: Node = Game.player_stats  # 玩家属性
@onready var invincible_timer: Timer = $InvincibleTimer  # 无敌计时器
@onready var slide_request_timer: Timer = $SlideRequestTimer  # 滑铲请求计时器
@onready var interaction_icon: AnimatedSprite2D = $InteractionIcon  # 交互提示图标
@onready var game_over_screen: Control = $CanvasLayer/GameOverScreen  # 游戏结束界面
@onready var pause_screen: Control = $CanvasLayer/PauseScreen  # 暂停界面
@onready var char_green_2: Sprite2D = $jianqi/CharGreen2  # 剑气特效
@onready var jianqi: Node2D = $jianqi  # 剑气节点
@onready var attack_shape_3: CollisionShape2D = $Graphics/Hitbox/AttackShape3  # 第三段攻击判定

# 初始化，进入场景时调用
func _ready() -> void:
	stand(default_gravity, 0.01)

# 处理玩家输入，包括跳跃、攻击、滑铲、交互、暂停
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	
	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2  # 松开跳跃键时截断上升
	
	if event.is_action_pressed("attack") and can_combo:
		is_combo_requested = true  # 连击请求
	
	if event.is_action_pressed("slide"):
		slide_request_timer.start()
	
	if event.is_action_pressed("interact") and interacting_with:
		interacting_with.back().interact()  # 与最近的可交互对象交互
	
	if event.is_action_pressed("pause"):
		pause_screen.show_pause()  # 显示暂停界面

# 物理帧更新，处理状态下的物理逻辑
func tick_physics(state: State, delta: float) -> void:
	interaction_icon.visible = not interacting_with.is_empty()  # 有交互对象时显示图标
	
	# 无敌时角色闪烁
	if invincible_timer.time_left > 0:
		graphics.modulate.a = sin(Time.get_ticks_msec() / 20.0) * 0.5 + 0.5
	else:
		graphics.modulate.a = 1
	
	# 根据当前状态调用不同的移动/站立/滑铲逻辑
	match state:
		State.IDLE:
			move(default_gravity, delta)
		
		State.RUNNING:
			move(default_gravity, delta)
		
		State.JUMP:
			move(0.0 if is_first_tick else default_gravity, delta)
		
		State.FALL:
			move(default_gravity, delta)
		
		State.LANDING:
			stand(default_gravity, delta)
		
		State.WALL_SLIDING:
			move(default_gravity / 3, delta)
			direction = Direction.LEFT if get_wall_normal().x < 0 else Direction.RIGHT
		
		State.WALL_JUMP:
			if state_machine.state_time < 0.1:
				stand(0.0 if is_first_tick else default_gravity, delta)
				direction = Direction.LEFT if get_wall_normal().x < 0 else Direction.RIGHT
			else:
				move(default_gravity, delta)
		
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			stand(default_gravity, delta)
		
		State.HURT, State.DYING:
			stand(default_gravity, delta)
		
		State.SLIDING_END:
			stand(default_gravity, delta)
		
		State.SLIDING_START, State.SLIDING_LOOP:
			slide(delta)
	
	is_first_tick = false  # 状态首次 tick 结束

# 普通移动逻辑，处理左右移动和重力
func move(gravity: float, delta: float) -> void:
	var movement := Input.get_axis("move_left", "move_right")
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, movement * RUN_SPEED, acceleration * delta)
	velocity.y += gravity * delta
	if not is_zero_approx(movement):
		direction = Direction.LEFT if movement < 0 else Direction.RIGHT
	
	move_and_slide()

# 站立逻辑，x 方向速度趋向 0
func stand(gravity: float, delta: float) -> void:
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.y += gravity * delta
	
	move_and_slide()

# 滑铲逻辑
func slide(delta: float) -> void:
	velocity.x = graphics.scale.x * SLIDING_SPEED
	velocity.y += default_gravity * delta
	
	move_and_slide()

# 死亡处理，显示游戏结束界面
func die() -> void:
	game_over_screen.show_game_over()

# 注册可交互对象
func register_interactable(v: Interactable) -> void:
	if state_machine.current_state == State.DYING:
		return
	if v in interacting_with:
		return
	interacting_with.append(v)

# 注销可交互对象
func unregister_interactable(v: Interactable) -> void:
	interacting_with.erase(v)

# 是否可以进行蹬墙滑行
func can_wall_slide() -> bool:
	return is_on_wall() and hand_checker.is_colliding() and foot_checker.is_colliding()

# 是否可以滑铲
func should_slide() -> bool:
	if slide_request_timer.is_stopped():
		return false
	if stats.energy < SLIDING_ENERGY:
		return false
	return not foot_checker.is_colliding()

# 状态机：根据当前状态和输入，决定下一个状态
func get_next_state(state: State) -> int:
	if stats.health == 0:
		return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	
	if pending_damage:
		return State.HURT
	
	var can_jump := is_on_floor() or coyote_timer.time_left > 0
	var should_jump := can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP
	
	if state in GROUND_STATES and not is_on_floor():
		return State.FALL
	
	var movement := Input.get_axis("move_left", "move_right")
	var is_still := is_zero_approx(movement) and is_zero_approx(velocity.x)
	
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if should_slide():
				return State.SLIDING_START
			if not is_still:
				return State.RUNNING
		
		State.RUNNING:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if should_slide():
				return State.SLIDING_START
			if is_still:
				return State.IDLE
		
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
		
		State.FALL:
			if is_on_floor():
				var height := global_position.y - fall_from_y
				return State.LANDING if height >= LANDING_HEIGHT else State.RUNNING
			if can_wall_slide():
				return State.WALL_SLIDING
		
		State.LANDING:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0:
				return State.WALL_JUMP
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
		
		State.WALL_JUMP:
			if can_wall_slide() and not is_first_tick:
				return State.WALL_SLIDING
			if velocity.y >= 0:
				return State.FALL
		
		State.ATTACK_1:
			if animation_player.frame == animation_player.sprite_frames.get_frame_count("attack_1") - 1:  # 检查是否播放到最后一帧	
				return State.ATTACK_2 if is_combo_requested else State.IDLE

		State.ATTACK_2:
			if animation_player.frame == animation_player.sprite_frames.get_frame_count("attack_2") - 1:  # 检查是否播放到最后一帧	
				return State.ATTACK_3 if is_combo_requested else State.IDLE
		
		State.ATTACK_3:
			if animation_player.frame == animation_player.sprite_frames.get_frame_count("attack_3") - 1:  # 检查是否播放到最后一帧	
				return State.IDLE
			#if direction > 0:
				#char_green_2.flip_h = false
				#char_green_2.flip_v = false
				#char_green_2.position.x = attack_shape_3.position.x
			#else: 
				#char_green_2.flip_h = true
				#char_green_2.flip_v = true
				#char_green_2.position.x = -attack_shape_3.position.x
			#if not animation_player.is_playing():
				#if direction > 0:
					#velocity.x += 150
				#else: 
					#velocity.x -= 150
				#return State.IDLE
		
		State.HURT:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.SLIDING_START:
			if not animation_player.is_playing():
				return State.SLIDING_LOOP
		
		State.SLIDING_END:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.SLIDING_LOOP:
			if state_machine.state_time > SLIDING_DURATION or is_on_wall():
				return State.SLIDING_END
	
	return StateMachine.KEEP_CURRENT

# 状态切换时的处理逻辑，包括动画、物理、音效等
func transition_state(from: State, to: State) -> void:
	print("[%s] %s => %s" % [
		Engine.get_physics_frames(),
		State.keys()[from] if from != -1 else "<START>",
		State.keys()[to],
	])
	
	if from not in GROUND_STATES and to in GROUND_STATES:
		coyote_timer.stop()
	
	match to:
		State.IDLE:
			animation_player.play("idle")
		
		State.RUNNING:
			animation_player.play("running")
		
		State.JUMP:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			jump_request_timer.stop()
			SoundManager.play_sfx("Jump")
		
		State.FALL:
			animation_player.play("fall")
			if from in GROUND_STATES:
				coyote_timer.start()
			fall_from_y = global_position.y
		
		State.LANDING:
			animation_player.play("landing")
		
		State.WALL_SLIDING:
			animation_player.play("wall_sliding")
		
		State.WALL_JUMP:
			animation_player.play("jump")
			velocity = WALL_JUMP_VELOCITY
			velocity.x *= get_wall_normal().x
			jump_request_timer.stop()
			
		State.ATTACK_1:
			animation_player.play("attack_1")
			is_combo_requested = false
			can_combo = true
			SoundManager.play_sfx("Attack")
			if direction>0:
				velocity.x+=100
			else:
				velocity.x-=100
		State.ATTACK_2:
			animation_player.play("attack_2")
			is_combo_requested = false
			can_combo = true
			SoundManager.play_sfx("Attack")
			if direction>0:
				velocity.x+=100
			else:
				velocity.x-=100
			
		State.ATTACK_3:
			animation_player.play("attack_3")
			is_combo_requested = false
			SoundManager.play_sfx("Attack")
			if direction>0:
				velocity.x+=100
			else:
				velocity.x-=100
			
		State.HURT:
			animation_player.play("hurt")
			
			#Input.start_joy_vibration(0, 0, 0.8, 0.8)
			Game.shake_camera(4)
			
			stats.health -= pending_damage.amount
			
			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCKBACK_AMOUNT
			
			pending_damage = null
			invincible_timer.start()
		
		State.DYING:
			animation_player.play("die")
			invincible_timer.stop()
			interacting_with.clear()
		
		State.SLIDING_START:
			animation_player.play("sliding_start")
			slide_request_timer.stop()
			stats.energy -= SLIDING_ENERGY
		
		State.SLIDING_LOOP:
			animation_player.play("sliding_loop")
		
		State.SLIDING_END:
			animation_player.play("sliding_end")
	
	is_first_tick = true

# 受伤回调，被敌人攻击时触发
func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	if invincible_timer.time_left > 0:
		return
	
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner

# 攻击命中回调，攻击敌人时触发
func _on_hitbox_hit(hurtbox: Variant) -> void:
	Game.shake_camera(2)
	
	Engine.time_scale = 0.01  # 慢动作特效
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1
