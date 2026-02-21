package snake

import rl "vendor:raylib"

Viewport_Rectangle :: struct {
	x, y, width, height: f32,
	scale, render_scale: f32,
	render: rl.RenderTexture,
}

init_viewport_render_texture :: proc() {
	if rl.IsRenderTextureValid(g_mem.viewport.render) {
		rl.UnloadRenderTexture(g_mem.viewport.render)
	}

	render_width := f32(VIRTUAL_WIDTH)*g_mem.viewport.render_scale
	render_height := f32(VIRTUAL_WIDTH/ASPECT_RATIO)*g_mem.viewport.render_scale

	g_mem.viewport.render = rl.LoadRenderTexture(i32(render_width), i32(render_height))
	rl.SetTextureFilter(g_mem.viewport.render.texture, .BILINEAR)
}

// Updates viewport and mouse offset/scaling for aspect ratio
update_aspect_ratio :: proc() {
	win_width := f32(rl.GetRenderWidth())
	win_height := f32(rl.GetRenderHeight())
	aspect_ratio := win_width/win_height

	g_mem.viewport.width = win_width
	g_mem.viewport.height = win_height
	if (aspect_ratio > ASPECT_RATIO) {
		// Window too wide → pillarbox
		g_mem.viewport.width = (win_height*ASPECT_RATIO)
		g_mem.viewport.x = (win_width - g_mem.viewport.width)/2
		g_mem.viewport.y = 0
	} else {
		// Window too tall → letterbox
		g_mem.viewport.height = (win_width/ASPECT_RATIO)
		g_mem.viewport.x = 0
		g_mem.viewport.y = (win_height - g_mem.viewport.height)/2
	}

	tex_width := f32(g_mem.viewport.render.texture.width)
	tex_height := f32(g_mem.viewport.render.texture.height)
	g_mem.viewport.scale = min(win_width/tex_width, win_height/tex_height)
	rl.SetMouseOffset(
		i32(-(win_width - tex_width*g_mem.viewport.scale)/2),
		i32(-(win_height - tex_height*g_mem.viewport.scale)/2),
	)
	rl.SetMouseScale(1/g_mem.viewport.scale, 1/g_mem.viewport.scale)
}
