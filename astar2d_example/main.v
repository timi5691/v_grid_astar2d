module main


import gg
import gx
import time
import md_ex {Game, Vec2, Rect, is_pos_in_rect, is_rect_in_rect, rad_to_deg, deg_to_rad, guipos_to_realpos}
import astar2d {Grid2d, AstarRs, GridPos, create_grid2d}
import md_cam {Camera}


#flag -D_SGL_DEFAULT_MAX_VERTICES=4194304
#flag -D_SGL_DEFAULT_MAX_COMMANDS=65536


/////////////////////////////////////////////////////////////////////////////////////
// MAIN FUNCTION
fn main() {
	mut data := &Data{}
	mut game := &Game{}
	game.dt_sw = time.new_stopwatch()
	game.dt_sw.start()
	game.ctx = gg.new_context(
		window_title: 'gg template'
		width: 640
		height: 480
		// fullscreen: true
		init_fn: fn [mut data] (mut game Game) {
			game.ws = game.ctx.window_size()
			spawn worker1(mut game, mut data)
		}
		event_fn: fn [mut data] (e &gg.Event, mut game Game) {
			match e.typ {
				.key_down {
					if game.pressing_keys[e.key_code] == false {
						game.pressing_keys[e.key_code] = true
						game.pressed_keys[e.key_code] = true
					}
					if e.key_code == .escape {
						quit(mut game, mut data)
					}
				}
				.key_up {
					if game.pressing_keys[e.key_code] == true {
						game.pressing_keys[e.key_code] = false
						game.released_keys[e.key_code] = true
					}
				}
				.resized, .restored, .resumed {
					
				}
				.touches_began {
					if e.num_touches > 0 {
						t := e.touches[0]
						println('touch begin: x ${t.pos_x} touch y ${t.pos_y}')
					}
				}
				.touches_ended {
					if e.num_touches > 0 {
						t := e.touches[0]
						println('touch end: x ${t.pos_x} y ${t.pos_y}')
					}
				}
				.mouse_down {
					
				}
				.mouse_up {
					
				}
				else {}
			}
		}
		click_fn: fn [mut data] (x f32, y f32, button gg.MouseButton, mut game Game) {
			if button == .left {
				game.left_mouse_down = true
				game.left_mouse_pressed = true
				game.click_count += 1
				game.gui_click_pos = Vec2{x, y}
				game.click_pos = guipos_to_realpos(game.gui_click_pos, data.cam.pos)
			} else if button == .right {
				game.right_mouse_down = true
				game.right_mouse_pressed = true
				game.right_gui_click_pos = Vec2{x, y}
				game.right_click_pos = guipos_to_realpos(game.right_gui_click_pos, data.cam.pos)
			}
		}
		unclick_fn: fn (x f32, y f32, button gg.MouseButton, mut game Game) {
			if button == .left {
				game.left_mouse_down = false
				game.left_mouse_released = true
			} else if button == .right {
				game.right_mouse_down = false
				game.right_mouse_released = true
			}
		}
		frame_fn:     fn [mut data] (mut game Game) {
			game.dt_sw.restart()
			start_frame(mut game, mut data)
			game.ctx.begin()
			game.mouse_gui_pos = Vec2{
				x: game.ctx.mouse_pos_x
				y: game.ctx.mouse_pos_y
			}
			game.mouse_pos = guipos_to_realpos(game.mouse_gui_pos, data.cam.pos)
			if game.click_count > 0 {
				game.click_time += game.delta
			}
			if game.click_time >= 0.5 {
				game.click_count = 0
				game.click_time = 0
			}

			data.cam.grid_size = data.grid2d.get_size()
			data.cam.mouse_gui_pos = game.mouse_gui_pos
			data.cam.ws = game.ws
			data.cam.delta = game.delta
			data.cam.update()

			begin_process(mut game, mut data)
			process(mut game, mut data)
			end_process(mut game, mut data)
			draw(mut game, mut data)
			draw_gui(mut game, mut data)
			game.ctx.end()
			end_frame(mut game, mut data)
			
		}
		resized_fn: fn [mut data] (e &gg.Event, mut game Game) {
			game.ws = game.ctx.window_size()
			on_resized(mut game, mut data)
		}
		quit_fn: fn [mut data] (e &gg.Event, mut game Game) {
			quit(mut game, mut data)
		}
		user_data:    game
	)
	
	load_assets(mut game, mut data)
	ready(mut game, mut data)
	game.ctx.run()
}

fn on_resized(mut game Game, mut data Data) {}

fn start_frame(mut game Game, mut data Data) {}

fn end_frame(mut game Game, mut data Data) {
	game.left_mouse_pressed = false
	game.right_mouse_pressed = false
	game.left_mouse_released = false
	game.right_mouse_released = false
	for i in 0..game.pressed_keys.len {
		game.pressed_keys[i] = false
	}
	for i in 0..game.released_keys.len {
		game.released_keys[i] = false
	}
	game.delta = f32(game.dt_sw.elapsed().seconds())
	game.fps = i32(1.0/game.delta)
	
}

fn quit(mut game Game, mut data Data) {
	game.over = true
	game.ctx.quit()
}

fn worker1(mut game Game, mut data Data) {
	for !game.over {

	}
}

/////////////////////////////////////////////////////////////////////////////////////
//

pub struct Data {
pub mut:
	debug string = 'Hello world'
	cam Camera
	grid2d Grid2d
	incamview_walkable_cells []int
	incamview_notwalkable_cells []int


	// astar path finding test data
	start_point Vec2
	end_point Vec2
	cross bool
	path []Vec2
}

fn load_assets(mut game Game, mut data Data) {
}

fn ready(mut game Game, mut data Data) {
	mut ctx := game.ctx
	ctx.set_bg_color(gx.white)
	grid_inf := struct {
		cell_size: 16.0
		cols: 200
		rows: 200
	}
	data.grid2d = create_grid2d(grid_inf.cell_size, grid_inf.cols, grid_inf.rows)
	data.grid2d.random_walkable(90)
	data.grid2d.set_cell_walkable(0, true)
}

fn begin_process(mut game Game, mut data Data) {
}

fn process(mut game Game, mut data Data) {
	// update grid2d
	data.grid2d.update()

	// find incamview_walkable_cells and incamview_notwalkable_cells
	data.incamview_walkable_cells = []int{}
	data.incamview_notwalkable_cells = []int{}
	ncells := data.grid2d.get_number_of_cells()
	for cell_id in 0..ncells {
		cell_rect := data.grid2d.id_to_rect(cell_id)
		if is_rect_in_rect(cell_rect, data.cam.rect) {
			walkable := data.grid2d.cells[cell_id].walkable
			if !walkable {
				data.incamview_notwalkable_cells << cell_id
			} else {
				data.incamview_walkable_cells << cell_id
			}
		}
	}

	if game.is_key_pressed(.c) {
		data.cross = !data.cross
		data.grid2d.x1y1_to_x2y2_calculate_path_in_green_thread(
			data.start_point.x, 
			data.start_point.y,
			data.end_point.x,
			data.end_point.y,
			data.cross
		)
	}

	// set start point
	if game.left_mouse_pressed {
		click_pos_center := data.grid2d.snap_pos_to_center_cell(game.mouse_pos)
		click_cell := data.grid2d.pos_to_id(click_pos_center)
		if data.grid2d.cells[click_cell].walkable {
			data.start_point = click_pos_center
		}
		data.grid2d.x1y1_to_x2y2_calculate_path_in_green_thread(
			data.start_point.x, 
			data.start_point.y,
			data.end_point.x,
			data.end_point.y,
			data.cross
		)
	}

	// set end point
	if game.right_mouse_pressed {
		click_pos_center := data.grid2d.snap_pos_to_center_cell(game.mouse_pos)
		click_cell := data.grid2d.pos_to_id(click_pos_center)
		if data.grid2d.cells[click_cell].walkable {
			data.end_point = click_pos_center
		}
		data.grid2d.x1y1_to_x2y2_calculate_path_in_green_thread(
			data.start_point.x, 
			data.start_point.y,
			data.end_point.x,
			data.end_point.y,
			data.cross
		)
	}

	// try to get path result
	start_cell := data.grid2d.pos_to_id(data.start_point)
	end_cell := data.grid2d.pos_to_id(data.end_point)
	if data.grid2d.is_has_path(start_cell, end_cell) {
		rs := data.grid2d.get_path_result(start_cell, end_cell)
		data.path = rs.clone()
	}
}

fn end_process(mut game Game, mut data Data) {
}

fn draw(mut game Game, mut data Data) {
	mut ctx := game.ctx

	// draw walls
	for cell_id in data.incamview_notwalkable_cells {
		cell_pos := data.grid2d.id_to_pos(cell_id, false)
		cell_drpos := cell_pos.minus(data.cam.pos)
		ctx.draw_rect_filled(
			cell_drpos.x, 
			cell_drpos.y, 
			data.grid2d.cell_size, 
			data.grid2d.cell_size, 
			gx.black
		)
	}

	// draw path
	npoint := data.path.len
	if npoint >= 2 {
		for i in 0..npoint - 1 {
			p1 := data.grid2d.snap_pos_to_center_cell(data.path[i]).minus(data.cam.pos)
			p2 := data.grid2d.snap_pos_to_center_cell(data.path[i + 1]).minus(data.cam.pos)
			ctx.draw_line(
				p1.x, p1.y, p2.x, p2.y, gx.blue
			)
		}
	}

	// draw start point
	dr_pos := data.start_point.minus(data.cam.pos)
	// ctx.draw_circle_filled(
	// 	dr_pos.x,
	// 	dr_pos.y,
	// 	data.grid2d.cell_size/2,
	// 	gx.blue
	// )
	ctx.draw_text2(gg.DrawTextParams{
		x:              int(dr_pos.x)
		y:              int(dr_pos.y)
		text:           'A'
		color:          gx.green
		align:          .center
		vertical_align: .middle
		size: 24
	})

	// draw end point
	dr_pos2 := data.end_point.minus(data.cam.pos)
	// ctx.draw_circle_filled(
	// 	dr_pos2.x,
	// 	dr_pos2.y,
	// 	data.grid2d.cell_size/2,
	// 	gx.red
	// )
	ctx.draw_text2(gg.DrawTextParams{
		x:              int(dr_pos2.x)
		y:              int(dr_pos2.y)
		text:           'B'
		color:          gx.red
		align:          .center
		vertical_align: .middle
		size: 24
	})

	
}

fn draw_gui(mut game Game, mut data Data) {
	mut ctx := game.ctx
	ws := game.ws
	ctx.draw_text2(gg.DrawTextParams{
		x:              ws.width / 2
		y:              0
		text:           'left mouse: A to mouse pos'
		color:          gx.blue
		align:          .center
		vertical_align: .top
		size: 24
		bold: true
	})
	ctx.draw_text2(gg.DrawTextParams{
		x:              ws.width / 2
		y:              24
		text:           'right mouse: B to mouse pos'
		color:          gx.blue
		align:          .center
		vertical_align: .top
		size: 24
		bold: true
	})
	ctx.draw_text2(gg.DrawTextParams{
		x:              ws.width / 2
		y:              48
		text:           'C key: switch cross to true or false'
		color:          gx.blue
		align:          .center
		vertical_align: .top
		size: 24
		bold: true
	})
	ctx.show_fps()
}
