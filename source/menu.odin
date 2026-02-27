// immediate-mode UI

package snake

import rl "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:strings"

MENU_WIDTH     :: 300
MENU_HEIGHT    :: 30
MENU_COLOR     :: rl.GRAY
MENU_HIGHLIGHT :: rl.WHITE
MENU_BORDER    :: 2

menu_slider_timer: f32
menu_pos_y := f32(VIRTUAL_HEIGHT/3)

Menu :: struct {
	x, y: f32,
	width, height: f32,
}

start_menu :: proc(m: Menu) { menu_pos_y = m.y }

menu_paused: Menu = {
	VIRTUAL_WIDTH/2-MENU_WIDTH/2,
	VIRTUAL_HEIGHT/3,
	MENU_WIDTH, MENU_HEIGHT,
}

draw_menu :: proc() {
	if game.is_paused {
		// transparent overlay
		rl.DrawRectangleRec({0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT}, rl.Color{0, 0, 0, 100})

		draw_text_centered("PAUSED", 0, VIRTUAL_HEIGHT/6, VIRTUAL_WIDTH, 50)

		start_menu(menu_paused)

		if draw_button_menu("Resume", menu_paused) {
			game.is_paused = !game.is_paused
		}
		if draw_button_menu("Restart", menu_paused) {
			shutdown_gameplay()
			init_gameplay()
		}
		if draw_button_menu("Fullscreen", menu_paused) {
			rl.ToggleBorderlessWindowed()
		}

		render_scale_before := g_mem.viewport.render_scale
		COOLDOWN_TIME :: f32(0.2)
		INCREMENT :: f32(1)
		if draw_slider_menu("Resolution scale", menu_paused, &g_mem.viewport.render_scale, min = 1, max = 4) {
			g_mem.viewport.render_scale = math.round_f32(g_mem.viewport.render_scale/INCREMENT)*INCREMENT
			if (g_mem.viewport.render_scale != render_scale_before) {
				if (menu_slider_timer == 0) {
					menu_slider_timer = COOLDOWN_TIME
					init_viewport_render_texture()
				} else {
					g_mem.viewport.render_scale = render_scale_before
				}
			}
		}

		when !ODIN_BUILD_WEB {
			if draw_button_menu("Exit", menu_paused) {
				g_mem.should_close = true
			}
		}

		input = {}
	}

	// Debug
	if g_mem.is_debug {
		debug_text_y = 0
		rl.DrawFPS(0, 0)
		print_debug("zoom: %.2f", game.camera_zoom)
		print_debug("score: %v", game.score)
		print_debug("snake length: %v", len(game.snake.body))
		print_debug("snake history: %v", len(game.snake.history))
		print_debug("render res: %v, %v", g_mem.viewport.render.texture.width, g_mem.viewport.render.texture.height)
	}

}

// Draw debug text in the upper left corner, using odin formatting
debug_text_y: i32
print_debug :: proc(text: string, args: ..any) {
	// temporary formatted cstring
	temp_cstrf :: proc(s: string, args: ..any) -> (res: cstring) {
		return strings.clone_to_cstring(
			fmt.aprintf(s, ..args, allocator = context.temp_allocator),
			allocator = context.temp_allocator,
		)
	}

	debug_text_y += 20
	rl.DrawText(temp_cstrf(text, ..args), 0, debug_text_y, 20, rl.WHITE)
}


// Draws text centered on a base position and width
draw_text_centered :: proc(text: cstring, x, y, width, size: f32, color := rl.WHITE) {
	text_width := f32(rl.MeasureText(text, i32(size)))
	text_pos := rl.Vector2{x + (width - text_width)/2, y}
	rl.DrawText(text, i32(text_pos.x), i32(text_pos.y), i32(size), color)
}

// Immediate-mode slider
draw_slider :: proc(text: cstring, x, y, width, height: f32,
					value: ^f32, min, max: f32, color := MENU_COLOR) -> bool {
	is_mouse_within_slider := rl.CheckCollisionPointRec(input.mouse_pos_ui, {x, y+height, width, height})

	draw_text_centered(text, x, y, width, height)

	// background box
	rl.DrawRectangleV({x, y+height}, {width, height}, color)

	// fill box
	min_width: f32 = (min == 0)? 0 : height
	fill_width := rl.Remap(value^, min, max, min_width, width)
	mb := f32(MENU_BORDER) + (is_mouse_within_slider? 2 : 0)
	rl.DrawRectangleV({x+mb, y+mb+height}, {fill_width-mb*2, height-mb*2}, MENU_HIGHLIGHT)

	// highlight outline
	if is_mouse_within_slider {
		rl.DrawRectangleLinesEx({x, y+height, width, height}, 2, MENU_HIGHLIGHT)
	}

	// adjust value
	if is_mouse_within_slider && rl.IsMouseButtonDown(.LEFT) {
		value^ = rl.Remap(input.mouse_pos_ui.x, x, x+width, min, max)
		return true
	}

	return false
}

draw_slider_menu :: proc(text: cstring, menu: Menu,
				         value: ^f32, min, max: f32, color := MENU_COLOR) -> bool {
	clicked := draw_slider(text, menu.x, menu_pos_y, menu.width, menu.height, value, min, max)
	menu_pos_y += menu.height*2 + 10

	return clicked
}

// Immediate-mode button
draw_button :: proc(text: cstring, x, y, width, height: f32, color := MENU_COLOR) -> bool {
	is_mouse_within_button := rl.CheckCollisionPointRec(input.mouse_pos_ui, {x, y, width, height})

	rl.DrawRectangleV({x, y}, {width, height}, color)
	draw_text_centered(text, x, y, width, height)

	if is_mouse_within_button {
		rl.DrawRectangleLinesEx({x, y, width, height}, 2, MENU_HIGHLIGHT)
	}

	return is_mouse_within_button && rl.IsMouseButtonPressed(.LEFT)
}

draw_button_menu :: proc(text: cstring, menu: Menu) -> bool {
	clicked := draw_button(text, menu.x, menu_pos_y, menu.width, menu.height)
	menu_pos_y += menu.height + 10

	return clicked
}

