# 世界场景主脚本，负责地图、相机、玩家等全局管理
class_name World
extends Node2D

@export var bgm: AudioStream  # 当前场景的背景音乐

@onready var tile_map: TileMap = $TileMap  # 地图瓦片
@onready var camera_2d: Camera2D = $Player/Camera2D  # 跟随玩家的相机
@onready var player: CharacterBody2D = $Player  # 玩家对象

# 初始化，设置相机边界、播放 BGM
func _ready() -> void:
	var used := tile_map.get_used_rect().grow(-1)
	var tile_size := tile_map.tile_set.tile_size
	
	camera_2d.limit_top = used.position.y * tile_size.y
	camera_2d.limit_right = used.end.x * tile_size.x
	camera_2d.limit_bottom = used.end.y * tile_size.y
	camera_2d.limit_left = used.position.x * tile_size.x
	camera_2d.reset_smoothing()
	
	if bgm:
		SoundManager.play_bgm(preload("res://assets/bgm/idpuuy.mp3"))
		SoundManager.play_bgm(bgm)

# 更新玩家位置和朝向，并重置相机
func update_player(pos: Vector2, direction: Player.Direction) -> void:
	player.global_position = pos
	player.fall_from_y = pos.y
	player.direction = direction
	camera_2d.reset_smoothing()
	camera_2d.force_update_scroll()  # 4.2 开始

# 保存场景状态（如存活敌人）
func to_dict() -> Dictionary:
	var enemies_alive := []
	for node in get_tree().get_nodes_in_group("enemies"):
		var path := get_path_to(node) as String
		enemies_alive.append(path)
	return {
		enemies_alive=enemies_alive,
	}

# 恢复场景状态（如移除已死亡敌人）
func from_dict(dict: Dictionary) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var path := get_path_to(node) as String
		if path not in dict.enemies_alive:
			node.queue_free()
	
