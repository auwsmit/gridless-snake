// EXPLANATION:
// Creates the game window, manages the main game loop,
// and defines the memory pool for hot-reloading
//
// See gameplay.odin for actual game code

package snake

import rl "vendor:raylib"
// import "core:fmt"
// import "core:strings"

WINDOW_NAME    :: "Gridless Snake"
VIRTUAL_WIDTH  :: 800.0
VIRTUAL_HEIGHT :: 500.0
GRID_UNIT      :: 20
ASPECT_RATIO   :: VIRTUAL_WIDTH/VIRTUAL_HEIGHT

Game_Memory :: struct {
	// global
	should_close: bool,
	current_screen: Screen_State,

	viewport: Viewport_Rectangle,
	ui_camera: rl.Camera2D,
	game_camera: rl.Camera2D,
	mouse_pos_ui: Vec2,
	mouse_pos_game: Vec2,

	// menu
	slider_timer: f32,

	// snake
	game: Gameplay_State,
}

Screen_State :: enum {
	LOGO, GAME,
}

g_mem: ^Game_Memory
render_texture: ^rl.Texture2D
game: ^Gameplay_State
snake: ^Entity_Snake
head: ^Snake_Part

refresh_globals :: proc() {
	game = &g_mem.game
	snake = &g_mem.game.snake
	head = &g_mem.game.snake.body[0]
	render_texture = &g_mem.viewport.render.texture
}

frame_time: f32
input: Input_State

init :: proc() {
	g_mem = new(Game_Memory)

	g_mem^ = Game_Memory {
		current_screen = .GAME,
		viewport = { render_scale = 4.0 }, // render resolution is render_scale * virtual resolution
	}

	init_gameplay()
	init_logo()
	init_viewport_render_texture()

	game_hot_reloaded(g_mem)
}

init_window :: proc() {
	rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_NAME)
	rl.SetWindowMinSize(320, 240)
	rl.SetTargetFPS(300)
	rl.SetExitKey(nil)
}

update :: proc() {
	frame_time = rl.GetFrameTime()
	update_aspect_ratio()
	g_mem.game_camera = update_game_camera()
	g_mem.ui_camera = update_ui_camera()

	// Global key bindings
	if rl.IsKeyPressed(.Q) {
		g_mem.should_close = true
	}
	if (rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)) && rl.IsKeyPressed(.ENTER) {
		rl.ToggleBorderlessWindowed()
	}

	switch g_mem.current_screen {
	case .LOGO: update_logo()
	case .GAME: update_gameplay()
	}
}

update_game_camera :: proc() -> rl.Camera2D {
	c: rl.Camera2D = {
		target = {VIRTUAL_WIDTH/2, VIRTUAL_HEIGHT/2},
		offset = {
			f32(render_texture.width)/2,
			f32(render_texture.height)/2,
		},
	}
	base_zoom := f32(render_texture.height)/VIRTUAL_HEIGHT

	// Uses `game.camera_zoom` and `game.camera_target`
	// to properly scale with render texture and window proportions
	c.zoom = base_zoom + base_zoom*game.camera_zoom
	c.target -= game.camera_target

	return c
}

update_ui_camera :: proc() -> rl.Camera2D {
	return {
		target = {VIRTUAL_WIDTH/2, VIRTUAL_HEIGHT/2},
		offset = {
			f32(render_texture.width)/2,
			f32(render_texture.height)/2,
		},
		zoom = f32(render_texture.height)/VIRTUAL_HEIGHT,
	}
}

draw :: proc() {
	rl.BeginTextureMode(g_mem.viewport.render)
		rl.BeginMode2D(g_mem.game_camera)

		switch g_mem.current_screen {
		case .LOGO: draw_logo()
		case .GAME: draw_gameplay()
		}

		rl.EndMode2D()
		rl.BeginMode2D(g_mem.ui_camera)

		#partial switch g_mem.current_screen {
		case .GAME: draw_menu()
		}

		rl.EndMode2D()
	rl.EndTextureMode()

	rl.BeginDrawing()

		rl.ClearBackground(rl.BLACK)
		rl.DrawTexturePro(render_texture^,
			{0, 0, f32(render_texture.width), f32(-render_texture.height)},
			{g_mem.viewport.x, g_mem.viewport.y, g_mem.viewport.width, g_mem.viewport.height},
			{0, 0}, 0, rl.WHITE)

	rl.EndDrawing()
}
