# 洞穴场景脚本，继承自 World
extends World

# 野猪死亡后触发，延迟 1 秒切换到结局界面
func _on_boar_died() -> void:
	await get_tree().create_timer(1).timeout
	Game.change_scene("res://ui/game_end_screen.tscn", {
		duration=1,
	})
