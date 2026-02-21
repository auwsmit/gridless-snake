package snake

import rl "vendor:raylib"

@(export)
game_init_window :: proc() {
	init_window()
}

@(export)
game_init :: proc() {
	init()
}

@(export)
game_update :: proc() {
	update()
	draw()
}

@(export)
game_should_close :: proc() -> bool {
	return rl.WindowShouldClose() || g_mem.should_close
}

@(export)
game_shutdown :: proc() {
	shutdown_gameplay()
	free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseAudioDevice()
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g_mem = (^Game_Memory)(mem)

	refresh_globals()
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}

