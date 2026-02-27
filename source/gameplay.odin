// EXPLANATION:
// This consists of code for the game itself
//
// See game.odin for the primary game loop

package snake

import rl "vendor:raylib"
// import "core:fmt"
import "core:math"

TICK_RATE :: 1/120.0

SNAKE_COLOR :: rl.DARKPURPLE
SNAKE_SPEED :: 150
SNAKE_LENGTH :: 20
SNAKE_WIDTH :: 20
SNAKE_GAP :: 20

// the history buffer for the snake's trail is shaved by this amount once it gets too long
HISTORY_END_BUFFER :: 128

APPLE_WIDTH :: 20
APPLE_FADE_TIME :: 0.5


Gameplay_State :: struct {
	camera_zoom: f32,
	camera_target: Vec2,

	time_accumulator: f32,
	is_paused: bool,
	is_gameover: bool,
	is_uturning: bool,
	uturn_direction: f32,
	uturn_angle: f32,
	gameover_cooldown: f32,
	snake: Entity_Snake,
	apples: [dynamic]Entity_Apple,
	score: int,

	grass_a_texture,
	grass_b_texture,
	apple_texture: rl.Texture,
	snake_body_texture: rl.RenderTexture,
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
	using position: Vec2,
	angle: f32,
	color: rl.Color,
}

Entity_Apple :: struct {
	using rec_angled: Rectangle_Angled,
	spawn_anim_timer: f32,
}

Input_State :: struct {
	turn_up, turn_down,
	turn_left, turn_right, uturn,
	turn_left_fast, turn_right_fast,
	shift, space: bool,
	mouse_wheel_move: f32,

	mouse_pos_game,
	mouse_pos_ui,
	mouse_delta: Vec2,
}

input: Input_State

get_input :: proc(old_input: Input_State) -> Input_State {
	updated_input := old_input // keep previous input for next tick
	updated_input.shift            ||= rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	updated_input.turn_up          ||= rl.IsKeyDown(.UP)         || rl.IsKeyDown(.W)
	updated_input.turn_down        ||= rl.IsKeyDown(.DOWN)       || rl.IsKeyDown(.S)
	updated_input.uturn            = updated_input.turn_down
	updated_input.turn_left        ||= rl.IsKeyDown(.LEFT)       || rl.IsKeyDown(.A)
	updated_input.turn_right       ||= rl.IsKeyDown(.RIGHT)      || rl.IsKeyDown(.D)
	updated_input.space            ||= rl.IsKeyDown(.SPACE)
	updated_input.mouse_wheel_move +=  rl.GetMouseWheelMove()
	updated_input.mouse_delta      +=  rl.GetMouseDelta()
	updated_input.mouse_pos_game   = rl.GetScreenToWorld2D(rl.GetMousePosition(), g_mem.camera_game)
	updated_input.mouse_pos_ui     = rl.GetScreenToWorld2D(rl.GetMousePosition(), g_mem.camera_ui)

	return updated_input
}

init_gameplay :: proc() {
	game = &g_mem.game
	snake = &g_mem.game.snake

	snake.body = make([dynamic]Snake_Part, 1, 8)
	snake.history = make([dynamic]Snake_History, 0, HISTORY_END_BUFFER)
	snake.speed = SNAKE_SPEED

	head = &game.snake.body[0]
	head.rec = {VIRTUAL_WIDTH/2, VIRTUAL_HEIGHT/2, SNAKE_WIDTH, SNAKE_LENGTH}
	head.origin = {head.width/2, head.height/2}
	game.snake.should_grow = 1

	game.apples = make([dynamic]Entity_Apple)

	game.gameover_cooldown = 1.2

	for _ in 1..=3 {
		apple,_ := make_apple()
		append(&g_mem.game.apples, apple)
	}

	game.grass_a_texture = rl.LoadTexture("assets/grass_a.png")
	game.grass_b_texture = rl.LoadTexture("assets/grass_b.png")
	game.apple_texture = rl.LoadTexture("assets/apple.png")
	game.snake_body_texture = rl.LoadRenderTexture(512, 512)

	rl.BeginTextureMode(game.snake_body_texture)
		rl.DrawRectangleRounded({0, 0, 512, 512}, 0.5, 8, rl.WHITE)
	rl.EndTextureMode()

	// Debug
	// game.score = game.snake.should_grow
}

shutdown_gameplay :: proc() {
	delete(game.apples)
	delete(snake.history)
	delete(snake.body)
	rl.UnloadTexture(game.grass_a_texture)
	rl.UnloadTexture(game.grass_b_texture)
	rl.UnloadTexture(game.apple_texture)
	rl.UnloadRenderTexture(game.snake_body_texture)
	game^ = {}
}

update_gameplay :: proc() {
	if rl.IsKeyPressed(.P) || rl.IsKeyPressed(.ESCAPE) {
		game.is_paused = !game.is_paused
	}

	// if rl.IsKeyPressed(.C) {
	// 	snake.should_grow = 1000
	// }

	if game.is_gameover && timer_countdown(&game.gameover_cooldown) {
		if rl.IsMouseButtonPressed(.LEFT) || rl.GetKeyPressed() != .KEY_NULL {
			shutdown_gameplay()
			init_gameplay()
		}
	}

	// update timers
	timer_countdown(&menu_slider_timer)
	for &apple in game.apples {
		timer_countdown(&apple.spawn_anim_timer)
	}

	input = get_input(input) // accumulates input for next tick

	if !game.is_paused && !game.is_gameover {

		game.time_accumulator += frame_time
		tick_rate: f32 = TICK_RATE

		if rl.IsKeyDown(.PERIOD) { tick_rate /= 2 }
		if rl.IsKeyDown(.COMMA) { tick_rate *= 2 }

		for game.time_accumulator >= tick_rate {
			tick()
			game.time_accumulator -= tick_rate
		}
	}
}

did_tick: bool

tick :: proc() {
	did_tick = true

	track_snake()
	update_snake() // player movement, and snake growth
	update_collision()

	// // camera controls
	// if (input.mouse_wheel_move != 0) {
	// 	game.camera_zoom += input.mouse_wheel_move*0.1
	// 	game.camera_zoom = math.clamp(game.camera_zoom, -0.9, 2)
	// }

	// if (rl.Vector2Length(input.mouse_delta) > 0) && rl.IsMouseButtonDown(.RIGHT) {
	// 	game.camera_target += input.mouse_delta/(g_mem.viewport.scale*g_mem.camera_game.zoom)
	// }
}

color_inc := 1 // used for snake body color pattern
track_snake :: proc() {
	snake.color_mod += color_inc
	if snake.color_mod >= 30 { color_inc = -1 }
	else if snake.color_mod < 1 { color_inc = 1 }
	snake.next_color = rl.ColorBrightness(SNAKE_COLOR, -0.2 + 0.01*f32(snake.color_mod))

	latest: Snake_History = {{head.x, head.y}, head.angle, snake.next_color}
	append(&snake.history, latest)
}

update_snake :: proc() {
	turn_rate: f32 = snake.speed*4
	max_turn_rate := turn_rate*TICK_RATE
	target := Vec2{head.x, head.y}

	// absolute direction keyboard
	if input.space {
		if input.turn_up    { target += {0,  -1} }
		if input.turn_down  { target += {0,  +1} }
		if input.turn_left  { target += {-1, 0}  }
		if input.turn_right { target += {+1, 0}  }
	}

	if rl.IsMouseButtonDown(.LEFT) {
		target = input.mouse_pos_game
	} else { // keyboard input
		if input.uturn {
			if !game.is_uturning {
				if input.turn_left || input.turn_right {
					game.is_uturning = true
					game.uturn_angle = math.mod(head.angle + 180, 360)
				}
				if input.turn_left { game.uturn_direction = -1 }
				if input.turn_right { game.uturn_direction = 1 }

			} else { // is uturning
				angle_diff := game.uturn_angle - head.angle
				for angle_diff < -180 { angle_diff += 360 }
				for angle_diff > 180  { angle_diff -= 360 }

				if abs(angle_diff) > max_turn_rate {
					head.angle += max_turn_rate*game.uturn_direction
				} else {
					head.angle = game.uturn_angle
					game.is_uturning = false
				}
			}
		} else if !input.space { // relative turning
			game.is_uturning = false
			if input.shift { turn_rate *= 2 }
			if input.turn_left { head.angle -= turn_rate/2*TICK_RATE }
			if input.turn_right { head.angle += turn_rate/2*TICK_RATE }
		}
	}

	if target != {head.x, head.y} {
		direction := target - {head.x, head.y}
		target_angle := math.atan2(direction.y, direction.x)*rl.RAD2DEG + 90

		angle_diff := target_angle - head.angle
		for angle_diff < -180 { angle_diff += 360 }
		for angle_diff > 180  { angle_diff -= 360 }

		if abs(angle_diff) > max_turn_rate {
			direction_sign: f32 = (angle_diff > 0)? 1 : -1
			head.angle += max_turn_rate*direction_sign
		} else {
			head.angle = target_angle
		}
	}

	movement: Vec2 = {0, -snake.speed}*TICK_RATE
	movement = rl.Vector2Rotate(movement, head.angle*rl.DEG2RAD)

	// move head
	head.x += movement.x
	head.y += movement.y

	// grow snake if history buffer is long enough
	snake.travel_distance += snake.speed*TICK_RATE
	if snake.travel_distance >= (SNAKE_LENGTH + SNAKE_GAP) {
		snake.spawn_index += 1

		// shave history buffer once it's too long
		if snake.spawn_index >= HISTORY_END_BUFFER {
			remove_range(&snake.history, 0, HISTORY_END_BUFFER)
			snake.spawn_index = 0
			snake.history_offset += HISTORY_END_BUFFER
		}

		if snake.should_grow > 0 {
			snake.should_grow -= 1
			snake.travel_distance = 0
			append(&snake.body, snake_grow())
			head = &snake.body[0] // refresh head pointer
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
}

snake_grow :: proc() -> Snake_Part {
	s: Snake_Part
	s.width = head.width
	s.height = head.height
	s.x = snake.history[snake.spawn_index].x
	s.y = snake.history[snake.spawn_index].y
	s.angle = snake.history[snake.spawn_index].angle
	s.origin = head.origin
	s.history_index = snake.spawn_index

	return s
}

update_collision :: proc() {
	// snake to screen edges
	if head.x < 0 || head.x > VIRTUAL_WIDTH || head.y < 0 || head.y > VIRTUAL_HEIGHT {
		game.is_gameover = true
		return
	}

	// snake self-collision
	head_collide := head.rec_angled
	head_collide.width /= 3 // use a small hitbox to feel more fair
	head_collide.height /= 3
	head_collide.origin /= 3
	for segment,i in snake.body {
		if i > 0 && check_collision(segment, head_collide) {
			game.is_gameover = true
		}
	}

	// apples
	for apple,i in game.apples {
		if check_collision(apple, head) {
			game.score += 1
			snake.should_grow += 1
			unordered_remove(&game.apples, i)
			new_apple, did_spawn := make_apple()
			if did_spawn {
				append(&game.apples, new_apple)
			} else {
				game.is_gameover = true
				game.score += 100 // bonus for filling the screen
			}
		}
	}
}

// - spawn pos is random when unspecified
// - apple needs to be appended to `game.apples` array
make_apple :: proc(spawn_pos: Vec2 = {}) -> (apple: Entity_Apple, could_spawn := true)  {
	spawn_pos := spawn_pos
	apple.width = APPLE_WIDTH
	apple.height = APPLE_WIDTH
	apple.origin = {apple.height/2, apple.width/2}
	apple.spawn_anim_timer = APPLE_FADE_TIME

	check_valid_spawn :: proc(apple: Entity_Apple) -> bool {
		apple := apple
		apple.x -= apple.width*2
		apple.y -= apple.height*2
		apple.width *= 4
		apple.height *= 4
		for segment in snake.body {
			if check_collision(apple, segment) {
				return false
			}
		}
		for a in game.apples {
			if check_collision(apple, a) {
				return false
			}
		}
		return true
	}

	if spawn_pos == {} {
		spawn_pos = {
			f32(rl.GetRandomValue(i32(0+apple.width), i32(VIRTUAL_WIDTH-apple.width))),
			f32(rl.GetRandomValue(i32(0+apple.width), i32(VIRTUAL_HEIGHT-apple.width))),
		}
	}

	apple.x = spawn_pos.x
	apple.y = spawn_pos.y
	for i := 0; check_valid_spawn(apple) == false; i+=1 {
		if i == 1000 { // no place found to spawn
			return apple, false
		}
		apple.x = f32(rl.GetRandomValue(i32(0+apple.width), i32(VIRTUAL_WIDTH-apple.width)))
		apple.y = f32(rl.GetRandomValue(i32(0+apple.width), i32(VIRTUAL_HEIGHT-apple.width)))
	}

	return apple, could_spawn
}

GRASS_TIMER_LENGTH :: 1.5
grass_timer: f32
grass_flag: bool

draw_gameplay :: proc() {
	defer if did_tick {
		input = {} // clear tick input after drawing
		did_tick = false
	}

	rl.ClearBackground(rl.DARKGREEN)

	if timer_countdown(&grass_timer, reset = GRASS_TIMER_LENGTH) {
		grass_flag = !grass_flag
	}

	grass_rec := rl.Rectangle{0, 0, f32(game.grass_a_texture.width), f32(game.grass_a_texture.height)}
	screen_rec := rl.Rectangle{0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT}
	if grass_flag {
		rl.DrawTexturePro(game.grass_a_texture, grass_rec, screen_rec, Vec2(0), 0, rl.WHITE)
	} else {
		rl.DrawTexturePro(game.grass_b_texture, grass_rec, screen_rec, Vec2(0), 0, rl.WHITE)
	}

	// apples with spawn fade-in animation
	apple_texture := rl.Rectangle{0, 0, f32(game.apple_texture.width), f32(game.apple_texture.height)}
	apple_origin := Vec2{f32(game.apple_texture.width/4), f32(game.apple_texture.height/4)}
	apple_origin -= {0.5, 0.5}
	for apple in game.apples {
		apple_rec := apple.rec_angled
		apple_rec.width += apple.width*apple.spawn_anim_timer/APPLE_FADE_TIME
		apple_rec.height += apple.height*apple.spawn_anim_timer/APPLE_FADE_TIME
		apple_rec.origin += apple.origin*apple.spawn_anim_timer/APPLE_FADE_TIME
		apple_trans := 1 - apple.spawn_anim_timer/APPLE_FADE_TIME
		rl.DrawTexturePro(game.apple_texture, apple_texture, apple_rec,
			apple_origin+apple_rec.origin, 0, rl.ColorAlpha(rl.WHITE, apple_trans))
	}

	// line to assist mouse controls
	if rl.IsMouseButtonDown(.LEFT) {
		rl.DrawLineEx({head.x, head.y}, input.mouse_pos_game, 4, rl.ColorAlpha(rl.BLACK, 0.1))
	}

	// Da Snake
	tail_length := 24
	if len(snake.body)-2 < tail_length {
		tail_length = len(snake.body)-2
	}
	tail_i := tail_length

	#reverse for &segment,i in snake.body {
		if i == 0 { continue }

		h_index := segment.history_index

		body_color := snake.history[h_index].color
		draw_rec := segment.rec_angled
		is_tail := i > 1 && i > len(snake.body)-tail_i-tail_length

		if is_tail {
			draw_rec.width /= (f32(tail_i)*0.025 + 1)
			draw_rec.origin.x -= (segment.width-draw_rec.width)/2
			tail_i -= 1
		}

		// rl.DrawRectanglePro(draw_rec, draw_rec.origin, segment.angle, body_color)
		rl.DrawTexturePro(game.snake_body_texture.texture, {0,0,512,512}, draw_rec, draw_rec.origin, segment.angle, body_color)

		copy := segment

		// the actual snake is more like a dotted line,
		// so this fills the empty space with more squares
		for _ in 1..=9 {
			h_index += 3
			if h_index > len(snake.history)-1 {
				continue
			}
			copy.x = snake.history[h_index].x
			copy.y = snake.history[h_index].y
			copy.angle = snake.history[h_index].angle
			copy.color = snake.history[h_index].color
			copy.width = draw_rec.width
			copy.origin = draw_rec.origin

			// rl.DrawRectanglePro(copy, copy.origin, copy.angle, copy.color)
			rl.DrawTexturePro(game.snake_body_texture.texture, {0,0,512,512}, copy, copy.origin, copy.angle, copy.color)
		}
	}

	head_color := rl.ColorBrightness(SNAKE_COLOR, -0.2)
	// rl.DrawRectanglePro(head, head.origin, head.angle, head_color)
	rl.DrawTexturePro(game.snake_body_texture.texture, {0,0,512,512}, head, head.origin, head.angle, head_color)

	if game.is_gameover {
		rl.DrawRectangleRec({0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT}, rl.Color{0, 0, 0, 100})

		text := rl.TextFormat("SCORE: %i", game.score)
		draw_text_centered(text, 0, VIRTUAL_HEIGHT/2-50, VIRTUAL_WIDTH, 60)
		if game.gameover_cooldown == 0 {
			draw_text_centered("TRY AGAIN?", 0, VIRTUAL_HEIGHT/2+30, VIRTUAL_WIDTH, 40)
		}
	}

	// // debug: draw snake path
	if g_mem.is_debug {
		for point in snake.history {
			rl.DrawPixelV({point.x, point.y}, rl.DARKBLUE)
		}
	}
}
