package snake

import rl "vendor:raylib"
import "core:math"
import "core:fmt"
import "core:strings"

ODIN_BUILD_WEB :: ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32

Vec2 :: rl.Vector2 // lazy shorthand

// updates a timer,
// returns true when timer runs out
timer_countdown :: proc(timer: ^f32, reset: f32 = 0, frametime: f32 = 0) -> bool {
    if timer^ > 0 {
        frametime := frametime
        if frametime == 0 { frametime = rl.GetFrameTime() }
        timer^ -= frametime
        return false
    } else {
        timer^ = reset
        return true
    }
}

// Rotated rectangle collision using SAT method
Rectangle_Angled :: struct {
	using rec: rl.Rectangle,
	angle: f32,
	origin: Vec2,
}

get_vertices :: proc(ra: Rectangle_Angled) -> [4]Vec2 {
    rad := ra.angle*(math.PI/180.0)
    cos_a := math.cos(rad)
    sin_a := math.sin(rad)

    corners := [4]Vec2{
        Vec2{0,        0}         - ra.origin,
        Vec2{ra.width, 0}         - ra.origin,
        Vec2{ra.width, ra.height} - ra.origin,
        Vec2{0,        ra.height} - ra.origin,
    }

    world_verts: [4]Vec2
    for i in 0..<4 {
        world_verts[i] = {
            ra.x + (corners[i].x*cos_a - corners[i].y*sin_a),
            ra.y + (corners[i].x*sin_a + corners[i].y*cos_a),
        }
    }
    return world_verts
}

check_collision :: proc(a, b: Rectangle_Angled) -> bool {
    v_a := get_vertices(a)
    v_b := get_vertices(b)

    edge_a0 := v_a[1] - v_a[0]
    edge_a1 := v_a[3] - v_a[0]
    edge_b0 := v_b[1] - v_b[0]
    edge_b1 := v_b[3] - v_b[0]

    axes := [4]Vec2{
        rl.Vector2Normalize(Vec2{-edge_a0.y, edge_a0.x}),
        rl.Vector2Normalize(Vec2{-edge_a1.y, edge_a1.x}),
        rl.Vector2Normalize(Vec2{-edge_b0.y, edge_b0.x}),
        rl.Vector2Normalize(Vec2{-edge_b1.y, edge_b1.x}),
    }

    for axis in axes {
        min_a, max_a, min_b, max_b: f32

        min_a = rl.Vector2DotProduct(v_a[0], axis)
        max_a = min_a
        for i in 1..<4 {
            p := rl.Vector2DotProduct(v_a[i], axis)
            min_a = math.min(min_a, p); max_a = math.max(max_a, p)
        }

        min_b = rl.Vector2DotProduct(v_b[0], axis)
        max_b = min_b
        for i in 1..<4 {
            p := rl.Vector2DotProduct(v_b[i], axis)
            min_b = math.min(min_b, p); max_b = math.max(max_b, p)
        }

        if max_a < min_b || max_b < min_a do return false
    }
    return true
}
