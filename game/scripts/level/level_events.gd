class_name LevelEvents
extends RefCounted
## Safe access to the `Events` autoload (it may be absent in isolated tests).

static func bus(from: Node) -> Node:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_node_or_null("/root/Events")

static func emit(from: Node, sig: StringName, args: Array = []) -> void:
	var b: Node = bus(from)
	if b == null or not b.has_signal(sig):
		return
	match args.size():
		0: b.emit_signal(sig)
		1: b.emit_signal(sig, args[0])
		2: b.emit_signal(sig, args[0], args[1])
		_: b.emit_signal(sig, args[0], args[1], args[2])

static func is_player(body: Node) -> bool:
	if body.is_in_group("player"):
		return true
	return body is CollisionObject3D and ((body as CollisionObject3D).collision_layer & 2) != 0

static func is_enemy(body: Node) -> bool:
	if body.is_in_group("enemy"):
		return true
	return body is CollisionObject3D and ((body as CollisionObject3D).collision_layer & 4) != 0
