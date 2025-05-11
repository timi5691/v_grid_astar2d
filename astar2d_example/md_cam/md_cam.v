module md_cam

import gg
import md_ex {Vec2, Rect, is_pos_in_rect, is_rect_in_rect, rad_to_deg, deg_to_rad, guipos_to_realpos}

/////////////////////////////////////////////////////////////////////////////////////
/// Camera

pub struct Camera {
pub mut:
	pos Vec2
	size Vec2
	center_pos Vec2
	zoom f32 = 1.0
	vel Vec2
	margin int = 64
	spd f32 = 4.0
	rect Rect
	grid_size Vec2
	mouse_gui_pos Vec2
	delta f32
	ws gg.Size
}

pub fn (mut cam Camera) update() {
	// update pos
	cam.pos = cam.pos.plus(cam.vel)
	if cam.pos.x < 0 {
		cam.pos.x = 0
	} else if cam.pos.x > cam.grid_size.x - cam.ws.width {
		cam.pos.x = cam.grid_size.x - cam.ws.width
	}
	if cam.pos.y < 0 {
		cam.pos.y = 0
	} else if cam.pos.y > cam.grid_size.y - cam.ws.height {
		cam.pos.y = cam.grid_size.y - cam.ws.height
	}

	camspd := cam.spd*cam.delta*100.0
	if cam.mouse_gui_pos.x <= cam.margin {
		cam.vel.x = -camspd
	} else if cam.mouse_gui_pos.x >= cam.ws.width - cam.margin {
		cam.vel.x = camspd
	} else {
		cam.vel.x = 0
	}
	if cam.mouse_gui_pos.y <= cam.margin {
		cam.vel.y = -camspd
	} else if cam.mouse_gui_pos.y >= cam.ws.height - cam.margin {
		cam.vel.y = camspd
	} else {
		cam.vel.y = 0
	}

	cam.size = Vec2{cam.ws.width, cam.ws.height}
	cam.center_pos.x = cam.pos.x + cam.size.x/2
	cam.center_pos.y = cam.pos.y + cam.size.y/2
	cam.rect = Rect{cam.pos, cam.size}
}