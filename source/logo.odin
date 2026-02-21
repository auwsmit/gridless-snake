// raylib logo animation

package snake

import rl "vendor:raylib"
import "core:math"

// Constants
RAYLIB_LOGO_WIDTH      :: 256
RAYLIB_LOGO_OUTLINE    :: RAYLIB_LOGO_WIDTH / 16
RAYLIB_LOGO_FONT_SIZE  :: (RAYLIB_LOGO_WIDTH / 8) + RAYLIB_LOGO_OUTLINE
RAYLIB_LOGO_BACKGROUND :: rl.Color{10, 10, 10, 255}
RAYLIB_LOGO_COLOR      :: rl.WHITE

// Types
Logo_State :: enum { START, GROW1, GROW2, TEXT, PAUSE, END }

Logo_Animation_State :: struct {
	position_x, position_y, elapsed_time,
	top_side_rec_width, left_side_rec_height,
	bottom_side_rec_width, right_side_rec_height: f32,
	letters_count: i32,

	state:   Logo_State,
	alpha:   f32,
	skipped: bool,
}

logo: Logo_Animation_State

init_logo :: proc() {
	logo = {
		position_x            = f32(VIRTUAL_WIDTH) / 2 - RAYLIB_LOGO_WIDTH / 2,
		position_y            = f32(VIRTUAL_HEIGHT) / 2 - RAYLIB_LOGO_WIDTH / 2,
		elapsed_time          = 0,
		letters_count         = 0,
		top_side_rec_width    = RAYLIB_LOGO_OUTLINE,
		left_side_rec_height  = RAYLIB_LOGO_OUTLINE,
		bottom_side_rec_width = RAYLIB_LOGO_OUTLINE,
		right_side_rec_height = RAYLIB_LOGO_OUTLINE,
		state                 = .START,
		alpha                 = 1,
	}
}

update_logo :: proc() {
	grow_speed   : f32 = RAYLIB_LOGO_WIDTH * 0.9375
	letter_delay : f32 = 0.2
	fade_speed   : f32 = 1
	frame_time   : f32 = rl.GetFrameTime()
	is_modifier_key_down := (rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT) ||
							 rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT) ||
							 rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL))
	skip_input_pressed := rl.IsMouseButtonPressed(.LEFT)

	if !is_modifier_key_down && (rl.GetKeyPressed() != .KEY_NULL) {
		skip_input_pressed = true
	}

	if skip_input_pressed {
		if logo.letters_count < 6 && logo.alpha >= 1 {
			logo.skipped = true
			logo.top_side_rec_width = RAYLIB_LOGO_WIDTH
			logo.left_side_rec_height = RAYLIB_LOGO_WIDTH
			logo.bottom_side_rec_width = RAYLIB_LOGO_WIDTH
			logo.right_side_rec_height = RAYLIB_LOGO_WIDTH
			logo.letters_count = 10
			logo.elapsed_time = 0
			logo.state = .TEXT
		} else {
			logo.state = .END
			logo.elapsed_time = 1
		}
	}

	if logo.skipped && logo.elapsed_time < 1 {
		logo.elapsed_time += frame_time
		return
	}

	switch logo.state {
	case .START:
		logo.elapsed_time += frame_time
		if logo.elapsed_time >= 2 {
			logo.state = .GROW1
			logo.elapsed_time = 0
		}
	case .GROW1:
		logo.top_side_rec_width += grow_speed * frame_time
		logo.left_side_rec_height += grow_speed * frame_time

		if logo.top_side_rec_width >= RAYLIB_LOGO_WIDTH {
			logo.top_side_rec_width = RAYLIB_LOGO_WIDTH
			logo.left_side_rec_height = RAYLIB_LOGO_WIDTH
			logo.state = .GROW2
			logo.elapsed_time = 0
		}
	case .GROW2:
		logo.bottom_side_rec_width += grow_speed * frame_time
		logo.right_side_rec_height += grow_speed * frame_time

		if logo.bottom_side_rec_width >= RAYLIB_LOGO_WIDTH {
			logo.bottom_side_rec_width = RAYLIB_LOGO_WIDTH
			logo.right_side_rec_height = RAYLIB_LOGO_WIDTH
			logo.state = .TEXT
			logo.elapsed_time = 0
		}
	case .TEXT:
		logo.elapsed_time += frame_time

		if logo.letters_count < 10 && logo.elapsed_time >= letter_delay {
			logo.letters_count += 1
			logo.elapsed_time = 0
		}

		if logo.letters_count >= 10 {
			logo.alpha -= fade_speed * frame_time
			if logo.alpha < math.F32_EPSILON {
				logo.alpha = 0
				logo.state = .PAUSE
				logo.elapsed_time = 0
			}
		}
	case .PAUSE:
		logo.elapsed_time += frame_time
		if logo.elapsed_time >= 1.5 {
			logo.state = .END
		}
	case .END:
		g_mem.current_screen = .GAME
	}
}

draw_logo :: proc() {
	line_width   := f32(RAYLIB_LOGO_OUTLINE)
	offset_a     := f32(RAYLIB_LOGO_WIDTH * 0.9375)
	offset_b     := line_width * 2
	offset_c     := f32(RAYLIB_LOGO_WIDTH * 0.171875)
	offset_d     := f32(RAYLIB_LOGO_WIDTH * 0.1875)
	font_size    := f32(RAYLIB_LOGO_FONT_SIZE)

	rect_pos_x   := logo.position_x
	rect_pos_y   := logo.position_y
	top_width    := logo.top_side_rec_width
	left_height  := logo.left_side_rec_height
	right_height := logo.right_side_rec_height
	bottom_width := logo.bottom_side_rec_width

	logo_color   := rl.Fade(RAYLIB_LOGO_COLOR, logo.alpha)

	rl.ClearBackground(RAYLIB_LOGO_BACKGROUND)

	if logo.state < .PAUSE {
		rl.DrawText("powered by",
					i32((VIRTUAL_WIDTH / 2) - (RAYLIB_LOGO_WIDTH / 2)),
					i32((VIRTUAL_HEIGHT / 2) - (RAYLIB_LOGO_WIDTH / 2) - offset_b - line_width / 4),
					i32(font_size) / 2, logo_color)
	}

	switch logo.state {
	case .START:
		if (i32(logo.elapsed_time * 4)) % 2 != 0 {
			rl.DrawRectangleV({rect_pos_x, rect_pos_y}, {line_width, line_width}, logo_color)
		} else {
			rl.DrawRectangleV({rect_pos_x, rect_pos_y}, {line_width, line_width}, RAYLIB_LOGO_BACKGROUND)
		}
	case .GROW1:
		rl.DrawRectangleV({rect_pos_x, rect_pos_y}, {top_width, line_width}, logo_color)
		rl.DrawRectangleV({rect_pos_x, rect_pos_y}, {line_width, left_height}, logo_color)

	case .GROW2:
		rl.DrawRectangleV({rect_pos_x,            rect_pos_y},            {top_width,    line_width},   logo_color)
		rl.DrawRectangleV({rect_pos_x,            rect_pos_y},            {line_width,   left_height},  logo_color)
		rl.DrawRectangleV({rect_pos_x + offset_a, rect_pos_y},            {line_width,   right_height}, logo_color)
		rl.DrawRectangleV({rect_pos_x,            rect_pos_y + offset_a}, {bottom_width, line_width},   logo_color)

	case .TEXT:
		rl.DrawRectangleV({rect_pos_x,            rect_pos_y},              {top_width,    line_width},              logo_color)
		rl.DrawRectangleV({rect_pos_x,            rect_pos_y + line_width}, {line_width,   left_height - offset_b},  logo_color)
		rl.DrawRectangleV({rect_pos_x + offset_a, rect_pos_y + line_width}, {line_width,   right_height - offset_b}, logo_color)
		rl.DrawRectangleV({rect_pos_x,            rect_pos_y + offset_a},   {bottom_width, line_width},              logo_color)

		rl.DrawText(rl.TextSubtext("raylib", 0, logo.letters_count),
					i32(VIRTUAL_WIDTH / 2 - offset_c),
					i32(VIRTUAL_HEIGHT / 2 + offset_d),
					i32(font_size), logo_color)
	case .PAUSE, .END:
		// No draw logic
	}
}
