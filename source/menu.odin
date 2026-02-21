// immediate-mode UI

package snake

// import "core:fmt"
import rl "vendor:raylib"
import "core:math"

MENU_WIDTH     :: 300
MENU_HEIGHT    :: 30
MENU_COLOR     :: rl.GRAY
MENU_HIGHLIGHT :: rl.WHITE
MENU_BORDER    :: 2

draw_menu :: proc() {
	if game.is_paused {
		// transparent overlay
		rl.DrawRectangleRec({0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT}, rl.Color{0, 0, 0, 100})

		draw_text_centered("PAUSED", 0, VIRTUAL_HEIGHT/4, VIRTUAL_WIDTH, 50)

		menu_pos := f32(VIRTUAL_HEIGHT/2) - MENU_HEIGHT
		if draw_button("Resume", VIRTUAL_WIDTH/2-(MENU_WIDTH/2), menu_pos, MENU_WIDTH, MENU_HEIGHT) {
			game.is_paused = !game.is_paused
		}

		menu_pos += MENU_HEIGHT + 40
		render_scale_before := g_mem.viewport.render_scale
		COOLDOWN_TIME :: f32(0.2)
		INCREMENT :: f32(1)
		draw_slider("Resolution scale", VIRTUAL_WIDTH/2 - MENU_WIDTH/2, menu_pos, MENU_WIDTH, MENU_HEIGHT, &g_mem.viewport.render_scale, 1, 4)
		g_mem.viewport.render_scale = math.round_f32(g_mem.viewport.render_scale/INCREMENT)*INCREMENT
		if (g_mem.viewport.render_scale != render_scale_before) {
			if (g_mem.slider_timer <= 0) {
				g_mem.slider_timer = COOLDOWN_TIME
				init_viewport_render_texture()
			} else {
				g_mem.viewport.render_scale = render_scale_before
			}
		}

		menu_pos += MENU_HEIGHT + 20
		if draw_button("Exit", VIRTUAL_WIDTH/2-(MENU_WIDTH/2), menu_pos, MENU_WIDTH, MENU_HEIGHT) {
			g_mem.should_close = true
		}

		input = {}
	}
}

// Draws text centered on a base position and width
draw_text_centered :: proc(text: cstring, x, y, width, size: f32, color := rl.WHITE) {
	text_width := f32(rl.MeasureText(text, i32(size)))
	text_pos := rl.Vector2{x + (width - text_width)/2, y}
	rl.DrawText(text, i32(text_pos.x), i32(text_pos.y), i32(size), color)
}

// interactive slider
draw_slider :: proc(text: cstring, x, y, width, height: f32,
					value: ^f32, min, max: f32, color := MENU_COLOR) {
	is_mouse_within_slider := rl.CheckCollisionPointRec(input.ui_mouse_pos, {x, y, width, height})

	rl.DrawRectangleV({x, y}, {width, height}, color)

	min_width: f32 = (min == 0)? 0 : height
	fill_width := rl.Remap(value^, min, max, min_width, width)
	mb := f32(MENU_BORDER) + (is_mouse_within_slider? 2 : 0)

	rl.DrawRectangleV({x+mb, y+mb}, {fill_width-mb*2, height-mb*2}, MENU_HIGHLIGHT)
	draw_text_centered(text, x, y-height, width, height)

	if is_mouse_within_slider {
		rl.DrawRectangleLinesEx({x, y, width, height}, 2, MENU_HIGHLIGHT)
	}

	// if interactable {
	if is_mouse_within_slider && rl.IsMouseButtonDown(.LEFT) {
		value^ = rl.Remap(input.ui_mouse_pos.x, x, x+width, min, max)
	}
}

draw_button :: proc(text: cstring, x, y, width, height: f32, color := MENU_COLOR) -> bool {
	is_mouse_within_button := rl.CheckCollisionPointRec(input.ui_mouse_pos, {x, y, width, height})

	rl.DrawRectangleV({x, y}, {width, height}, color)
	draw_text_centered(text, x, y, width, height)

	if is_mouse_within_button {
		rl.DrawRectangleLinesEx({x, y, width, height}, 2, MENU_HIGHLIGHT)
	}

	return is_mouse_within_button && rl.IsMouseButtonPressed(.LEFT)
}

