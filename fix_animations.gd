# Godot 编辑器脚本：批量修正动画资源的更新模式
@tool
extends EditorScript

# 入口函数，运行时会依次修正指定场景的动画
func _run() -> void:
	fix_scene("res://enemies/boar.tscn")  # 修正野猪敌人动画
	fix_scene("res://player.tscn")        # 修正玩家动画

# 修正指定场景下所有 AnimationPlayer 的动画
func fix_scene(path: String) -> void:
	EditorInterface.open_scene_from_path(path)  # 打开场景
	
	for node in EditorInterface.get_edited_scene_root().get_children():
		if node is AnimationPlayer:
			fix_animation_player(node)  # 修正动画播放器
	
	EditorInterface.save_scene()  # 保存场景

# 修正 AnimationPlayer 下所有动画的更新模式
func fix_animation_player(animation_player: AnimationPlayer) -> void:
	if not animation_player.has_animation("RESET"):
		return  # 没有 RESET 动画则跳过
	var reset := animation_player.get_animation("RESET")
	
	for animation_name in animation_player.get_animation_list():
		if animation_name == "RESET":
			continue  # 跳过 RESET 动画本身
		
		var animation := animation_player.get_animation(animation_name)
		fix_animation(animation, reset)  # 修正动画

# 将 reset 动画的 value track 更新模式应用到其它动画
func fix_animation(animation: Animation, reset: Animation) -> void:
	for src in reset.get_track_count():
		var type := reset.track_get_type(src)
		var path := reset.track_get_path(src)
		
		if type != Animation.TYPE_VALUE:
			continue  # 只处理 value track
		
		var dst := find_track(animation, type, path)
		if dst == -1:
			continue  # 目标动画没有该 track
		
		animation.value_track_set_update_mode(dst, reset.value_track_get_update_mode(src))

# 在动画中查找指定类型和路径的 track，返回索引
func find_track(animation: Animation, type: Animation.TrackType, path: NodePath) -> int:
	for i in animation.get_track_count():
		if animation.track_get_type(i) != type:
			continue
		if animation.track_get_path(i) != path:
			continue
		return i
	return -1
