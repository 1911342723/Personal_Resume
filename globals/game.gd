# 游戏全局管理脚本，负责场景切换、存档、配置、玩家属性等全局功能
extends Node

# 摄像机震动信号，参数为震动强度
signal camera_should_shake(amount: float)

# 存档和配置文件路径
const SAVE_PATH := "user://data.sav"
const CONFIG_PATH := "user://config.ini"

# world_states 用于记录每个场景的敌人生存状态等信息
# 结构：{ 场景名: {enemies_alive: [敌人路径]} }
var world_states := {}

# 运行时引用
@onready var player_stats: Stats = $PlayerStats  # 玩家属性
@onready var color_rect: ColorRect = $ColorRect  # 用于场景切换的淡入淡出
@onready var default_player_stats := player_stats.to_dict()  # 默认玩家属性备份

# 初始化，设置淡入色透明，加载音量配置
func _ready() -> void:
	color_rect.color.a = 0
	load_config()

# 切换场景，支持淡入淡出、参数传递、入口点定位等
func change_scene(path: String, params := {}) -> void:
	var duration := params.get("duration", 0.2) as float  # 切换动画时长
	
	var tree := get_tree()
	tree.paused = true  # 切换时暂停游戏
	
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "color:a", 1, duration)  # 淡出
	await tween.finished
	
	# 保存当前场景状态
	if tree.current_scene is World:
		var old_name := tree.current_scene.scene_file_path.get_file().get_basename()
		world_states[old_name] = tree.current_scene.to_dict()
	
	tree.change_scene_to_file(path)  # 切换场景
	if "init" in params:
		params.init.call()  # 切换后初始化回调
	
	# Godot 4.2 以后用 tree_changed 代替 process_frame
	await tree.tree_changed
	
	# 还原新场景的状态
	if tree.current_scene is World:
		var new_name := tree.current_scene.scene_file_path.get_file().get_basename()
		if new_name in world_states:
			tree.current_scene.from_dict(world_states[new_name])
		
		# 定位入口点
		if "entry_point" in params:
			for node in tree.get_nodes_in_group("entry_points"):
				if node.name == params.entry_point:
					tree.current_scene.update_player(node.global_position, node.direction)
					break
		
		# 直接定位玩家位置
		if "position" in params and "direction" in params:
			tree.current_scene.update_player(params.position, params.direction)
	
	tree.paused = false  # 恢复游戏
	
	tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "color:a", 0, duration)  # 淡入

# 存档，保存当前场景、玩家属性、敌人生存状态等
func save_game() -> void:
	var scene := get_tree().current_scene
	var scene_name := scene.scene_file_path.get_file().get_basename()
	world_states[scene_name] = scene.to_dict()
	
	var data := {
		world_states=world_states,
		stats=player_stats.to_dict(),
		scene=scene.scene_file_path,
		player={
			direction=scene.player.direction,
			position={
				x=scene.player.global_position.x,
				y=scene.player.global_position.y,
			},
		},
	}
	var json := JSON.stringify(data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(json)

# 读档，恢复场景、玩家属性、敌人生存状态等
func load_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	
	var json := file.get_as_text()
	var data := JSON.parse_string(json) as Dictionary
	
	change_scene(data.scene, {
		direction=data.player.direction,
		position=Vector2(
			data.player.position.x,
			data.player.position.y
		),
		init=func ():
			world_states = data.world_states
			player_stats.from_dict(data.stats)
	})

# 新游戏，重置玩家属性和世界状态，进入初始场景
func new_game() -> void:
	change_scene("res://worlds/forest.tscn", {
		duration=1,
		init=func ():
			world_states = {}
			player_stats.from_dict(default_player_stats)
	})

# 返回标题界面
func back_to_title() -> void:
	change_scene("res://ui/title_screen.tscn", {
		duration=1,
	})

# 是否有存档
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# 保存音量等配置
func save_config() -> void:
	var config := ConfigFile.new()
	
	config.set_value("audio", "master", SoundManager.get_volume(SoundManager.Bus.MASTER))
	config.set_value("audio", "sfx", SoundManager.get_volume(SoundManager.Bus.SFX))
	config.set_value("audio", "bgm", SoundManager.get_volume(SoundManager.Bus.BGM))
	
	config.save(CONFIG_PATH)

# 读取音量等配置
func load_config() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	
	SoundManager.set_volume(
		SoundManager.Bus.MASTER,
		config.get_value("audio", "master", 0.5)
	)
	SoundManager.set_volume(
		SoundManager.Bus.SFX,
		config.get_value("audio", "sfx", 1.0)
	)
	SoundManager.set_volume(
		SoundManager.Bus.BGM,
		config.get_value("audio", "bgm", 1.0)
	)

# 触发摄像机震动
func shake_camera(amount: float) -> void:
	camera_should_shake.emit(amount)
