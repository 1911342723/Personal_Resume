# 伤害数据结构，记录伤害数值和来源
class_name Damage
extends RefCounted

var amount: int  # 伤害数值
var source: Node2D  # 伤害来源（如敌人、玩家等）
