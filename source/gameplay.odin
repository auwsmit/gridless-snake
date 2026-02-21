// This file is related to Snake gameplay specifically
// See game.odin for the main game loop
package snake

import rl "vendor:raylib"
// import "core:fmt"
import "core:math"

TICK_RATE :: 1/60.0

SNAKE_COLOR :: rl.DARKPURPLE
SNAKE_SPEED :: 150
SNAKE_LENGTH :: 20
SNAKE_WIDTH :: 20
SNAKE_GAP :: 20
FOOD_WIDTH :: 20

Input_State :: struct {
	turn_up, turn_down,
	turn_left, turn_right,
	shift, space: bool,
	mouse_wheel_move: f32,

	game_mouse_pos,
	ui_mouse_pos,
	mouse_delta: rl.Vector2,
}

Gameplay_State :: struct {
	camera_zoom: f32,
	camera_target: rl.Vector2,

	time_accumulator: f32,
	is_paused: bool,
	game_over: bool,
	snake: Entity_Snake,
	food: [dynamic]Entity_Food,
	score: int,

	grass_a_texture,
	grass_b_texture,
	apple_texture: rl.Texture,
}

Entity_Snake :: struct {
	body: [dynamic]Snake_Part,
	history: [dynamic]Snake_History,
	speed: f32,
	travel_distance: f32,
	spawn_index: int,
	history_offset: int,
	should_grow: int,
	color_mod: int,
	next_color: rl.Color,
}

Snake_Part :: struct {
	using rec_angled: Rectangle_Angled,
	history_index: int,
	color: rl.Color,
}

Snake_History :: struct { // history for the snake's trail
	using position: rl.Vector2,
	angle: f32,
	color: rl.Color,
}

Entity_Food :: struct {
	using rec_angled: Rectangle_Angled,
}

did_tick: bool

get_input :: proc(old_input: Input_State) -> Input_State {
	updated_input := old_input // keep previous input for next tick
	updated_input.shift            ||= rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	updated_input.turn_up          ||= rl.IsKeyDown(.UP)         || rl.IsKeyDown(.W)
	updated_input.turn_down        ||= rl.IsKeyDown(.DOWN)       || rl.IsKeyDown(.S)
	updated_input.turn_left        ||= rl.IsKeyDown(.LEFT)       || rl.IsKeyDown(.A)
	updated_input.turn_right       ||= rl.IsKeyDown(.RIGHT)      || rl.IsKeyDown(.D)
	updated_input.space            ||= rl.IsKeyPressed(.SPACE)
	updated_input.mouse_wheel_move +=  rl.GetMouseWheelMove()
	updated_input.mouse_delta      +=  rl.GetMouseDelta()
	updated_input.game_mouse_pos = rl.GetScreenToWorld2D(rl.GetMousePosition(), g_mem.game_camera)
	updated_input.ui_mouse_pos = rl.GetScreenToWorld2D(rl.GetMousePosition(), g_mem.ui_camera)

	return updated_input
}

init_gameplay :: proc() {
	game = &g_mem.game
	snake = &g_mem.game.snake

	snake.body = make([dynamic]Snake_Part, 1, 1)
	snake.history = make([dynamic]Snake_History)
	snake.speed = SNAKE_SPEED
	head := &game.snake.body[0]
	head.rec = {VIRTUAL_WIDTH/2, VIRTUAL_HEIGHT/2, SNAKE_WIDTH, SNAKE_LENGTH}
	head.origin = {head.width/2, head.height/2}

	game.food = make([dynamic]Entity_Food)

	for _ in 1..=3 {
		f,_ := make_food()
		append(&g_mem.game.food, f)
	}

	game.grass_a_texture = rl.LoadTexture("assets/grass_a.png")
	game.grass_b_texture = rl.LoadTexture("assets/grass_b.png")
	game.apple_texture = rl.LoadTexture("assets/apple.png")

	// TEMP
	// game.snake.should_grow = 30
	// game.score = 30
}

update_gameplay :: proc() {
	if rl.IsKeyPressed(.P) || rl.IsKeyPressed(.ESCAPE) {
		game.is_paused = !game.is_paused
	}

	if game.game_over {
		if rl.IsMouseButtonPressed(.LEFT) || rl.GetKeyPressed() != .KEY_NULL {
			shutdown_gameplay()
			init_gameplay()
		}
	}

	input = get_input(input) // accumulates input for next tick

	// update menu timer
	timer_countdown(&g_mem.slider_timer)
	// if (g_mem.slider_timer >= 0) {
	// 	g_mem.slider_timer -= frame_time
	// }

	if !game.is_paused && !game.game_over {

		// if rl.IsKeyPressed(.SPACE) {
		// 	snake.should_grow += 1
		// }
		game.time_accumulator += frame_time

		tick_rate := f32(TICK_RATE)
		if rl.IsKeyDown(.PERIOD) { tick_rate /= 2 }

		for game.time_accumulator >= tick_rate {
			tick()
			game.time_accumulator -= tick_rate
		}
	}

}

tick :: proc() {
	did_tick = true

	update_snake()

	if input.space {
		food,_ := make_food(input.game_mouse_pos)
		append(&game.food, food)
	}

	all_food_collision()

	// camera controls
	if (input.mouse_wheel_move != 0) {
		game.camera_zoom += input.mouse_wheel_move*0.1
		game.camera_zoom = math.clamp(game.camera_zoom, -0.9, 2)
	}

	if (rl.Vector2Length(input.mouse_delta) > 0) && rl.IsMouseButtonDown(.RIGHT) {
		game.camera_target += input.mouse_delta/(g_mem.viewport.scale*g_mem.game_camera.zoom)
	}
}

get_snake_head :: proc() -> ^Snake_Part {
	return &g_mem.game.snake.body[0]
}

cinc := 1
update_snake:: proc() {
	head := get_snake_head()

	// track the snake's path in a history buffer for the body to follow
	snake.color_mod += cinc
	if snake.color_mod >= 30 { cinc = -1 }
	else if snake.color_mod < 1 { cinc = 1 }
	snake.next_color = rl.ColorBrightness(SNAKE_COLOR, -0.2 + 0.01*f32(snake.color_mod))

	latest: Snake_History = {rl.Vector2{head.x, head.y}, head.angle, snake.next_color}
	append(&snake.history, latest)

	// turn snake
	turn_rate: f32 = snake.speed*4
	max_turn_rate := turn_rate*TICK_RATE
	target := rl.Vector2{head.x, head.y}

	// // absolute keyboard
	// if input.turn_up    { target += {0,  -1} }
	// if input.turn_down  { target += {0,  +1} }
	// if input.turn_left  { target += {-1, 0}   }
	// if input.turn_right { target += {+1, 0}   }

	if rl.IsMouseButtonDown(.LEFT) {
		target = input.game_mouse_pos
		direction := target - {head.x, head.y}
		target_angle := math.atan2(direction.y, direction.x)*rl.RAD2DEG + 90

		// // absolute direction
		// head.angle = target_angle

		angle_diff := target_angle - head.angle
		for angle_diff < -180 { angle_diff += 360 }
		for angle_diff > 180  { angle_diff -= 360 }

		if abs(angle_diff) > max_turn_rate {
			direction_sign: f32 = (angle_diff > 0)? 1 : -1
			head.angle += max_turn_rate*direction_sign
		} else {
			head.angle = target_angle
		}
	} else { // keyboard input
		if input.shift { turn_rate /= 2 }
		if input.turn_left { head.angle -= turn_rate/2*TICK_RATE }
		if input.turn_right { head.angle += turn_rate/2*TICK_RATE }
	}

	movement: rl.Vector2 = {0, -snake.speed}*TICK_RATE
	movement = rl.Vector2Rotate(movement, head.angle*rl.DEG2RAD)

	// move head
	head.x += movement.x
	head.y += movement.y

	// the trail history buffer is shaved by this amount once it gets too long
	HISTORY_END_BUFFER :: 128

	snake.travel_distance += snake.speed*TICK_RATE
	if snake.travel_distance > (SNAKE_LENGTH + SNAKE_GAP) {
		snake.spawn_index += 1
		if snake.spawn_index >= HISTORY_END_BUFFER {
			remove_range(&snake.history, 0, HISTORY_END_BUFFER)
			snake.spawn_index = 0
			snake.history_offset += HISTORY_END_BUFFER
		}
		if snake.should_grow > 0 {
			snake.should_grow -= 1
			snake.travel_distance = 0
			append(&snake.body, snake_grow())
		}
	}

	// body follows head
	for &segment,i in snake.body {
		if i > 0 { // skip head
			if segment.history_index > snake.history_offset {
				segment.history_index -= snake.history_offset
			}
			segment.x = snake.history[segment.history_index].x
			segment.y = snake.history[segment.history_index].y
			segment.angle = snake.history[segment.history_index].angle
			segment.color = snake.history[segment.history_index].color
			segment.history_index += 1
		}
	}
	snake.history_offset = 0

	// collision check
	for &segment,i in snake.body {
		if i > 0 && check_collision(segment, get_snake_head()) {
			game.game_over = true
		}
	}
}

snake_grow :: proc() -> Snake_Part {
	s: Snake_Part
	s.width = get_snake_head().width
	s.height = get_snake_head().height
	s.x = snake.history[snake.spawn_index].x
	s.y = snake.history[snake.spawn_index].y
	s.angle = snake.history[snake.spawn_index].angle
	s.origin = get_snake_head().origin
	s.history_index = snake.spawn_index

	return s
}

// - spawn pos is random when unspecified
// - food needs to be appended to `game.food` array
make_food :: proc(spawn_pos: rl.Vector2 = {0, 0}) -> (food: Entity_Food, spawn_found := true)  {

	spawn_pos := spawn_pos
	food.width = FOOD_WIDTH
	food.height = FOOD_WIDTH
	food.origin = {food.height/2, food.width/2}

	check_valid_spawn :: proc(f: Entity_Food) -> bool {
		f := f
		f.x -= f.width*2
		f.y -= f.height*2
		f.width *= 4
		f.height *= 4
		for segment in snake.body {
			if check_collision(f, segment) {
				return false
			}
		}
		return true
	}

	if spawn_pos == {0, 0} {
		spawn_pos = {
			f32(rl.GetRandomValue(i32(0+food.width), i32(VIRTUAL_WIDTH-food.width))),
			f32(rl.GetRandomValue(i32(0+food.width), i32(VIRTUAL_HEIGHT-food.width))),
		}
	}

	food.x = spawn_pos.x
	food.y = spawn_pos.y
	for i := 0; check_valid_spawn(food) == false; i+=1 {
		if i == 1000 {
			return food, false
		}
		food.x = f32(rl.GetRandomValue(i32(0+food.width), i32(VIRTUAL_WIDTH-food.width)))
		food.y = f32(rl.GetRandomValue(i32(0+food.width), i32(VIRTUAL_HEIGHT-food.width)))
	}

	return food, spawn_found
}

all_food_collision :: proc() {
	for food,i in game.food {
		if check_collision(food, get_snake_head()) {
			game.score += 1
			snake.should_grow += 1
			unordered_remove(&game.food, i)
			new_food, did_spawn := make_food()
			if did_spawn {
				append(&game.food, new_food)
			}
		}
	}
}


GRASS_TIMER_LENGTH :: 1.6
grass_timer: f32 = GRASS_TIMER_LENGTH
grass_flag: bool

draw_gameplay :: proc() {
	defer if did_tick {
		input = {} // clear tick input after drawing
		did_tick = false
	}

	rl.ClearBackground(rl.DARKGREEN)

	if timer_countdown(&grass_timer) {
		// timer finished, reset timer
		grass_timer = GRASS_TIMER_LENGTH
		grass_flag = !grass_flag
	}

	grass_rec := rl.Rectangle{0, 0, f32(game.grass_a_texture.width), f32(game.grass_a_texture.height)}
	screen_rec := rl.Rectangle{0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT}
	if grass_flag {
		rl.DrawTexturePro(game.grass_a_texture, grass_rec, screen_rec, rl.Vector2(0), 0, rl.WHITE)
	} else {
		rl.DrawTexturePro(game.grass_b_texture, grass_rec, screen_rec, rl.Vector2(0), 0, rl.WHITE)
	}

	head := get_snake_head()

	apple_rec := rl.Rectangle{0, 0, f32(game.apple_texture.width), f32(game.apple_texture.height)}
	apple_origin := rl.Vector2{f32(game.apple_texture.width/4), f32(game.apple_texture.height/4)}
	apple_origin -= {0.5, 0.5}
	for f in game.food {
		rl.DrawTexturePro(game.apple_texture, apple_rec, f.rec, apple_origin+f.origin, 0, rl.WHITE)
	}

	if rl.IsMouseButtonDown(.LEFT) {
		rl.DrawLineEx({head.x, head.y},
			input.game_mouse_pos,
			4, rl.ColorAlpha(rl.BLACK, 0.2))
	}

	tail_end := 3
	if len(snake.body)-1 <= tail_end { tail_end = len(snake.body)-2 }
	#reverse for &segment,i in snake.body {
		if i == 0 { continue }

		h_index := segment.history_index
		if segment.history_index > snake.history_offset {
			h_index -= snake.history_offset
		}

		body_color := snake.history[h_index].color
		draw_rec := segment.rec_angled
		if i > len(snake.body)-tail_end-3 {
			draw_rec.width /= f32(tail_end)*0.5 + 1
			draw_rec.origin.x -= (segment.width-draw_rec.width)/2
			tail_end -= 1
		}

		rl.DrawRectanglePro(draw_rec, draw_rec.origin, segment.angle, body_color)

		copy := segment
		for _ in 1..=4 {
			h_index += 3
			if h_index > len(snake.history)-1 {
				continue
			}
			copy.x = snake.history[h_index].x
			copy.y = snake.history[h_index].y
			copy.width = draw_rec.width
			copy.origin = draw_rec.origin
			copy.angle = snake.history[h_index].angle
			copy.color = snake.history[h_index].color
			rl.DrawRectanglePro(copy, copy.origin, copy.angle, copy.color)
		}
	}

	head_color := rl.ColorBrightness(SNAKE_COLOR, -0.2)
	rl.DrawRectanglePro(head, head.origin, head.angle, head_color)

	if game.game_over {
		rl.DrawRectangleRec({0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT}, rl.Color{0, 0, 0, 100})

		text := rl.TextFormat("SCORE: %i", len(snake.body)-1)
		draw_text_centered(text, 0, VIRTUAL_HEIGHT/2-25, VIRTUAL_WIDTH, 50)
	}

	// temp cursor thing
	// cursor: rl.Rectangle = { input.game_mouse_pos.x-GRID_UNIT/2, input.game_mouse_pos.y-GRID_UNIT/2, GRID_UNIT, GRID_UNIT}
	// rl.DrawRectangleRec(cursor, rl.ColorAlpha(rl.BLACK, 0.5))

	// draw_text_centered(rl.TextFormat("Score: %i", game.score), 0, 8, VIRTUAL_WIDTH, 50, score_color)

	// // border
	// rl.DrawRectangleLinesEx({0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT}, 8, rl.ColorBrightness(rl.DARKGREEN, -0.3))

	// // debug: draw snake path
	// for point in snake.history {
	// 	rl.DrawPixelV({point.x, point.y}, rl.BLACK)
	// }

}

shutdown_gameplay :: proc() {
	delete(game.food)
	delete(snake.history)
	delete(snake.body)
	rl.UnloadTexture(game.grass_a_texture)
	rl.UnloadTexture(game.grass_b_texture)
	rl.UnloadTexture(game.apple_texture)
	game^ = {}
}
