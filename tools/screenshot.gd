extends SceneTree
# Captures a PNG of a scene after N physics frames, for visually checking
# rendering/UI/VFX changes without a human driving the editor.
# Must run WITHOUT --headless (needs a real renderer) — use tools/screenshot.sh.
#
# Args (after `--`): <scene_path> <output_png_path> [wait_frames]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <scene_path> <output_png_path> [wait_frames]")
		quit(1)
		return

	var scene_path: String = args[0]
	var out_path: String = args[1]
	var wait_frames: int = int(args[2]) if args.size() > 2 else 30

	var res: Resource = load(scene_path)
	if res == null:
		printerr("failed to load scene: ", scene_path)
		quit(1)
		return

	var scene: Node = res.instantiate()
	root.add_child(scene)
	current_scene = scene

	for i in wait_frames:
		await process_frame

	var img := root.get_texture().get_image()
	var err := img.save_png(out_path)
	if err != OK:
		printerr("save_png failed: ", err)
		quit(1)
		return

	print("saved screenshot to ", out_path)
	quit(0)
