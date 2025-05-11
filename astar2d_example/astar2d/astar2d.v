module astar2d

import rand
import rand.seed
import md_ex {Vec2, Rect, is_pos_in_rect, is_rect_in_rect, rad_to_deg, deg_to_rad, guipos_to_realpos}


pub struct GridPos {
pub mut:
	row int
	col int
}

pub struct Cell {
pub mut:
	id         int
	walkable   bool
	gridpos    GridPos
	topleftpos Vec2
	centerpos  Vec2
}

pub struct Grid2d {
pub mut:
	pos Vec2
	cell_size  f32
	rows       int
	cols       int
	cells      map[int]Cell
	astar_chan chan AstarRs
	path_map   map[int]map[int][]Vec2
}

pub struct CostNb {
pub mut:
	nb_to_start_distance  f32
	nb_to_end_distance    f32
	start_to_end_distance f32
}

pub struct AstarRs {
pub mut:
	start_cell int
	dest_cell  int
	path       []Vec2
}

pub fn shuffle(mut id_list []int) {
	rand.shuffle(mut id_list) or { panic(err) }
}

pub fn myabs(a int) int {
	if a < 0 {
		return -a
	}

	return a
}

pub fn create_grid2d(cell_size f32, cols int, rows int) Grid2d {
	mut grid2d := Grid2d{}
	grid2d.cell_size = cell_size
	grid2d.cols = cols
	grid2d.rows = rows
	number_of_cell := cols * rows

	for i in 0 .. number_of_cell {
		grid2d.cells[i] = Cell{
			id:         i
			walkable:   true
			gridpos:    grid2d.id_to_gridpos(i)
			topleftpos: grid2d.id_to_pos(i, false)
			centerpos:  grid2d.id_to_pos(i, true)
		}
	}

	return grid2d
}

pub fn (grid2d Grid2d) get_size() Vec2 {
	return Vec2{
		x: grid2d.cols*grid2d.cell_size
		y: grid2d.rows*grid2d.cell_size
	}
}

pub fn (grid2d Grid2d) get_number_of_cells() int {
	return grid2d.cols*grid2d.rows
}

pub fn (grid2d Grid2d) gridpos_to_id(gridpos GridPos) int {
	return gridpos.row * grid2d.cols + gridpos.col
}

pub fn (grid2d Grid2d) id_to_gridpos(id int) GridPos {
	r := id / grid2d.cols
	return GridPos{
		col: id - r * grid2d.cols
		row: r
	}
}

pub fn (grid2d Grid2d) id_to_rect(id int) Rect {
	cell_pos := grid2d.id_to_pos(id, false)
	cell_size_vec := Vec2{grid2d.cell_size, grid2d.cell_size}
	return Rect{cell_pos, cell_size_vec}
}

pub fn (grid2d Grid2d) gridpos_to_pos(gridpos GridPos, center bool) Vec2 {
	if center {
		return Vec2{
			x: gridpos.col * grid2d.cell_size + grid2d.cell_size / 2
			y: gridpos.row * grid2d.cell_size + grid2d.cell_size / 2
		}
	}

	return Vec2{
		x: gridpos.col * grid2d.cell_size
		y: gridpos.row * grid2d.cell_size
	}
}

pub fn (grid2d Grid2d) pos_to_gridpos(pp Vec2) GridPos {
	return GridPos{
		col: int(pp.x / grid2d.cell_size)
		row: int(pp.y / grid2d.cell_size)
	}
}

pub fn (grid2d Grid2d) pos_to_id(pp Vec2) int {
	return grid2d.gridpos_to_id(grid2d.pos_to_gridpos(pp))
}

pub fn (grid2d Grid2d) id_to_pos(id int, center bool) Vec2 {
	return grid2d.gridpos_to_pos(grid2d.id_to_gridpos(id), center)
}

pub fn calc_steps(gridpos1 GridPos, gridpos2 GridPos) f32 {
	return f32(myabs(gridpos2.row - gridpos1.row) + myabs(gridpos2.col - gridpos1.col))
}

pub fn calc_cost(gridpos1 GridPos, gridpos2 GridPos) f32 {
	dx := myabs(gridpos2.col - gridpos1.col)
	dy := myabs(gridpos2.row - gridpos1.row)
	return f32(dx * dx + dy * dy)
}

pub fn (grid2d Grid2d) get_walkable_cells() []Cell {
	mut walkable_cells := []Cell{}

	for _, cell in grid2d.cells {
		if cell.walkable {
			walkable_cells << cell
		}
	}

	return walkable_cells
}

pub fn (grid2d Grid2d) is_cell_valid(cell_id int) bool {
	if _ := grid2d.cells[cell_id] {
		return true
	}

	return false
}

pub fn (grid2d Grid2d) is_pos_valid(posx f32, posy f32) bool {
	gridpos := grid2d.pos_to_gridpos(Vec2{posx, posy})
	return gridpos.col >= 0 && gridpos.col < grid2d.cols && gridpos.row >= 0
		&& gridpos.row < grid2d.rows
}

pub fn (grid2d Grid2d) is_pos_in_grid(pos Vec2) bool {
	gridpos := grid2d.pos_to_gridpos(pos)
	return gridpos.col >= 0 && gridpos.col < grid2d.cols && gridpos.row >= 0
		&& gridpos.row < grid2d.rows
}

pub fn (mut grid2d Grid2d) set_cell_walkable(cell_id int, walkable bool) {
	if _ := grid2d.cells[cell_id] {
		grid2d.cells[cell_id].walkable = walkable
	}
}

pub fn (mut grid2d Grid2d) set_pos_walkable(posx f32, posy f32, walkable bool) {
	if grid2d.is_pos_valid(posx, posy) {
		cell_id := grid2d.pos_to_id(Vec2{posx, posy})
		grid2d.set_cell_walkable(cell_id, walkable)
	}
}

pub fn cell_get_neighbor_up(cellpos GridPos) GridPos {
	nb_row := cellpos.row - 1
	if nb_row < 0 {
		return cellpos
	}
	return GridPos{
		col: cellpos.col
		row: nb_row
	}
}

pub fn cell_get_neighbor_down(cellpos GridPos, rows int) GridPos {
	nb_row := cellpos.row + 1
	if nb_row >= rows {
		return cellpos
	}
	return GridPos{
		col: cellpos.col
		row: nb_row
	}
}

pub fn cell_get_neighbor_left(cellpos GridPos) GridPos {
	nb_col := cellpos.col - 1
	if nb_col < 0 {
		return cellpos
	}
	return GridPos{cellpos.row, nb_col}
}

pub fn cell_get_neighbor_right(cellpos GridPos, cols int) GridPos {
	nb_col := cellpos.col + 1
	if nb_col >= cols {
		return cellpos
	}
	return GridPos{
		col: nb_col
		row: cellpos.row
	}
}

pub fn cell_get_neighbor_up_left(cellpos GridPos) GridPos {
	nb_row := cellpos.row - 1
	nb_col := cellpos.col - 1
	if nb_col < 0 || nb_row < 0 {
		return cellpos
	}
	return GridPos{
		col: nb_col
		row: nb_row
	}
}

pub fn cell_get_neighbor_up_right(cellpos GridPos, cols int) GridPos {
	nb_row := cellpos.row - 1
	nb_col := cellpos.col + 1
	if nb_col >= cols || nb_row < 0 {
		return cellpos
	}
	return GridPos{
		col: nb_col
		row: nb_row
	}
}

pub fn cell_get_neighbor_down_right(cellpos GridPos, cols int, rows int) GridPos {
	nb_row := cellpos.row + 1
	nb_col := cellpos.col + 1
	if nb_col >= cols || nb_row >= rows {
		return cellpos
	}
	return GridPos{
		col: nb_col
		row: nb_row
	}
}

pub fn cell_get_neighbor_down_left(cellpos GridPos, rows int) GridPos {
	nb_row := cellpos.row + 1
	nb_col := cellpos.col - 1
	if nb_col < 0 || nb_row >= rows {
		return cellpos
	}
	return GridPos{
		col: nb_col
		row: nb_row
	}
}

pub fn (grid2d Grid2d) cell_get_neighbors(cellpos GridPos, cross bool) []int {
	mut rs := []int{}
	left := cell_get_neighbor_left(cellpos)
	leftid := grid2d.gridpos_to_id(left)
	right := cell_get_neighbor_right(cellpos, grid2d.cols)
	rightid := grid2d.gridpos_to_id(right)
	up := cell_get_neighbor_up(cellpos)
	upid := grid2d.gridpos_to_id(up)
	down := cell_get_neighbor_down(cellpos, grid2d.rows)
	downid := grid2d.gridpos_to_id(down)
	if leftid !in rs && left != cellpos && grid2d.cells[leftid].walkable {
		rs << leftid
		{
		}
	}

	if rightid !in rs && right != cellpos && grid2d.cells[rightid].walkable {
		rs << rightid
	}

	if upid !in rs && up != cellpos && grid2d.cells[upid].walkable {
		rs << upid
	}

	if downid !in rs && down != cellpos && grid2d.cells[downid].walkable {
		rs << downid
	}

	if !cross {
		return rs
	}

	up_left := cell_get_neighbor_up_left(cellpos)
	upleftid := grid2d.gridpos_to_id(up_left)
	up_right := cell_get_neighbor_up_right(cellpos, grid2d.cols)
	uprightid := grid2d.gridpos_to_id(up_right)
	down_left := cell_get_neighbor_down_left(cellpos, grid2d.rows)
	downleftid := grid2d.gridpos_to_id(down_left)
	down_right := cell_get_neighbor_down_right(cellpos, grid2d.cols, grid2d.rows)
	downrightid := grid2d.gridpos_to_id(down_right)

	if upleftid !in rs && up_left != cellpos && grid2d.cells[upleftid].walkable && upid in rs
		&& leftid in rs {
		rs << upleftid
	}

	if uprightid !in rs && up_right != cellpos && grid2d.cells[uprightid].walkable && upid in rs
		&& rightid in rs {
		rs << uprightid
	}

	if downleftid !in rs && down_left != cellpos && grid2d.cells[downleftid].walkable
		&& downid in rs && leftid in rs {
		rs << downleftid
	}

	if downrightid !in rs && down_right != cellpos && grid2d.cells[downrightid].walkable
		&& downid in rs && rightid in rs {
		rs << downrightid
	}

	return rs
}

fn get_best_neighbor(open_neighbors_info map[int]CostNb) int {
	mut min_i := open_neighbors_info.keys()[0]
	mut min_f := open_neighbors_info[min_i].start_to_end_distance
	for i, _ in open_neighbors_info {
		f_i := open_neighbors_info[i].start_to_end_distance
		if f_i < min_f {
			min_i = i
			min_f = f_i
		}
	}

	return min_i
}

fn calculate_path(current_checking_cell int, start int, parents map[int]int) []int {
	mut path := []int{}
	mut p := current_checking_cell

	for p != start {
		path << p
		p = parents[p]
	}

	path << p

	return path
}

fn (grid2d Grid2d) calculate_path_pos(current_checking_cell int, start int, parents map[int]int) []Vec2 {
	mut path := []Vec2{}
	mut p := current_checking_cell

	for p != start {
		path << grid2d.id_to_pos(p, true)
		p = parents[p]
	}

	path << grid2d.id_to_pos(p, true)

	return path
}

pub fn (grid2d Grid2d) cell1_to_cell2_get_path(cell_from int, cell_to int, cross bool) []int {
	mut path := []int{}
	mut current_checking_cell := cell_from

	cellfrom_gridpos := grid2d.id_to_gridpos(cell_from)
	cellto_gridpos := grid2d.id_to_gridpos(cell_to)

	if cellfrom_gridpos.col < 0 || cellfrom_gridpos.col > grid2d.cols - 1
		|| cellfrom_gridpos.row < 0 || cellfrom_gridpos.row > grid2d.rows - 1 {
		return []
	}

	if cellto_gridpos.col < 0 || cellto_gridpos.col > grid2d.cols - 1 || cellto_gridpos.row < 0
		|| cellto_gridpos.row > grid2d.rows - 1 {
		return [cell_from]
	}

	cost_from_pos1_to_pos2 := calc_cost(cellfrom_gridpos, cellto_gridpos)
	mut open_neighbors_info := {
		current_checking_cell: CostNb{
			nb_to_start_distance:  f32(0)
			nb_to_end_distance:    cost_from_pos1_to_pos2
			start_to_end_distance: cost_from_pos1_to_pos2
		}
	}
	mut closed_neighbors_info := map[int]CostNb{}
	mut parents := map[int]int{}

	for open_neighbors_info.len != 0 {
		current_checking_cell = get_best_neighbor(open_neighbors_info)
		if current_checking_cell == cell_to {
			path = calculate_path(current_checking_cell, cell_from, parents)
			return path
		}

		current_gridpos := grid2d.id_to_gridpos(current_checking_cell)
		neighbors := grid2d.cell_get_neighbors(current_gridpos, cross)

		for nb in neighbors {
			steps_to_neighbor := open_neighbors_info[current_checking_cell].nb_to_start_distance + 1
			if _ := open_neighbors_info[nb] {
				if open_neighbors_info[nb].nb_to_start_distance > steps_to_neighbor {
					open_neighbors_info[nb].nb_to_start_distance = steps_to_neighbor
					open_neighbors_info[nb].start_to_end_distance = steps_to_neighbor +
						open_neighbors_info[nb].nb_to_end_distance
					parents[nb] = current_checking_cell
				}
			} else if _ := closed_neighbors_info[nb] {
				if closed_neighbors_info[nb].nb_to_start_distance > steps_to_neighbor {
					closed_neighbors_info[nb].nb_to_start_distance = steps_to_neighbor
					closed_neighbors_info[nb].start_to_end_distance = steps_to_neighbor +
						closed_neighbors_info[nb].nb_to_end_distance
					parents[nb] = current_checking_cell
					open_neighbors_info[nb] = closed_neighbors_info[nb]
					closed_neighbors_info.delete(nb)
				}
			} else {
				nb_gridpos := grid2d.id_to_gridpos(nb)
				nb_h := calc_cost(nb_gridpos, cellto_gridpos)
				open_neighbors_info[nb] = CostNb{
					nb_to_start_distance:  steps_to_neighbor
					nb_to_end_distance:    nb_h
					start_to_end_distance: steps_to_neighbor + nb_h
				}
				parents[nb] = current_checking_cell
			}
		}

		closed_neighbors_info[current_checking_cell] = open_neighbors_info[current_checking_cell]
		open_neighbors_info.delete(current_checking_cell)
	}

	if current_checking_cell != cell_to {
		path = [cell_from]
	}

	return path
}

pub fn (grid2d Grid2d) x1y1_to_x2y2_calculate_path(x1 f32, y1 f32, x2 f32, y2 f32, cross bool) []Vec2 {
	cellfrom_gridpos := grid2d.pos_to_gridpos(Vec2{ x: x1, y: y1 })
	cellto_gridpos := grid2d.pos_to_gridpos(Vec2{ x: x2, y: y2 })

	is_pos1_out_side_grid := cellfrom_gridpos.col < 0 || cellfrom_gridpos.col > grid2d.cols - 1
		|| cellfrom_gridpos.row < 0 || cellfrom_gridpos.row > grid2d.rows - 1
	is_pos2_out_side_grid := cellto_gridpos.col < 0 || cellto_gridpos.col > grid2d.cols - 1
		|| cellto_gridpos.row < 0 || cellto_gridpos.row > grid2d.rows - 1

	task1 := {
		'true':  fn () []Vec2 {
			return []Vec2{}
		}
		'false': fn [grid2d, x1, y1, x2, y2, cross] () []Vec2 {
			mut path := []Vec2{}

			cellfrom_gridpos := grid2d.pos_to_gridpos(Vec2{ x: x1, y: y1 })
			cellto_gridpos := grid2d.pos_to_gridpos(Vec2{ x: x2, y: y2 })
			cell_from := grid2d.pos_to_id(Vec2{ x: x1, y: y1 })
			cell_to := grid2d.pos_to_id(Vec2{ x: x2, y: y2 })
			mut current_checking_cell := cell_from

			cost_from_pos1_to_pos2 := calc_cost(cellfrom_gridpos, cellto_gridpos)
			mut open_neighbors_info := {
				current_checking_cell: CostNb{
					nb_to_start_distance:  f32(0)
					nb_to_end_distance:    cost_from_pos1_to_pos2
					start_to_end_distance: cost_from_pos1_to_pos2
				}
			}
			mut closed_neighbors_info := map[int]CostNb{}
			mut parents := map[int]int{}

			for open_neighbors_info.len != 0 {
				current_checking_cell = get_best_neighbor(open_neighbors_info)

				is_cur_check_cell_final := current_checking_cell == cell_to

				if is_cur_check_cell_final {
					path = grid2d.calculate_path_pos(current_checking_cell, cell_from,
						parents)
					return path
				}

				current_gridpos := grid2d.id_to_gridpos(current_checking_cell)
				neighbors := grid2d.cell_get_neighbors(current_gridpos, cross)

				for nb in neighbors {
					steps_to_neighbor :=
						open_neighbors_info[current_checking_cell].nb_to_start_distance + 1

					if _ := open_neighbors_info[nb] {
						// nb was in open
						if open_neighbors_info[nb].nb_to_start_distance > steps_to_neighbor {
							open_neighbors_info[nb].nb_to_start_distance = steps_to_neighbor
							open_neighbors_info[nb].start_to_end_distance = steps_to_neighbor +
								open_neighbors_info[nb].nb_to_end_distance
							parents[nb] = current_checking_cell
						}
						continue
					}
					if _ := closed_neighbors_info[nb] {
						// nb was in closed
						if closed_neighbors_info[nb].nb_to_start_distance > steps_to_neighbor {
							closed_neighbors_info[nb].nb_to_start_distance = steps_to_neighbor
							closed_neighbors_info[nb].start_to_end_distance = steps_to_neighbor +
								closed_neighbors_info[nb].nb_to_end_distance
							parents[nb] = current_checking_cell
							open_neighbors_info[nb] = closed_neighbors_info[nb]
							closed_neighbors_info.delete(nb)
						}
						continue
					}

					// nb was not in open and closed
					nb_gridpos := grid2d.id_to_gridpos(nb)
					nb_h := calc_cost(nb_gridpos, cellto_gridpos)
					open_neighbors_info[nb] = CostNb{
						nb_to_start_distance:  steps_to_neighbor
						nb_to_end_distance:    nb_h
						start_to_end_distance: steps_to_neighbor + nb_h
					}
					parents[nb] = current_checking_cell
				}

				closed_neighbors_info[current_checking_cell] = open_neighbors_info[current_checking_cell]
				open_neighbors_info.delete(current_checking_cell)
			}

			return path
		}
	}

	return task1['${is_pos1_out_side_grid || is_pos2_out_side_grid}']()
}

pub fn (grid2d Grid2d) x1y1_to_x2y2_calculate_path_in_green_thread(x1 f32, y1 f32, x2 f32, y2 f32, cross bool) {
	go fn [grid2d, x1, y1, x2, y2, cross] () {
		grid2d.astar_chan <- AstarRs{
			start_cell: grid2d.pos_to_id(Vec2{x1, y1})
			dest_cell:  grid2d.pos_to_id(Vec2{x2, y2})
			path:       grid2d.x1y1_to_x2y2_calculate_path(x1, y1, x2, y2, cross)
		}
	}()
}

pub fn (grid2d Grid2d) x1y1_to_x2y2_calculate_path_in_thread(x1 f32, y1 f32, x2 f32, y2 f32, cross bool) {
	spawn fn [grid2d, x1, y1, x2, y2, cross] () {
		grid2d.astar_chan <- AstarRs{
			start_cell: grid2d.pos_to_id(Vec2{x1, y1})
			dest_cell:  grid2d.pos_to_id(Vec2{x2, y2})
			path:       grid2d.x1y1_to_x2y2_calculate_path(x1, y1, x2, y2, cross)
		}
	}()
}

pub fn (mut grid2d Grid2d) update() {
	mut astar_rs := AstarRs{}
	// try to get path from thread
	if grid2d.astar_chan.try_pop(mut astar_rs) == .success {
		// get result and save it to grid2d.path_map
		grid2d.path_map[astar_rs.start_cell][astar_rs.dest_cell] = astar_rs.path
	}
}

pub fn (grid2d Grid2d) is_has_path(start_cell int, dest_cell int) bool {
	if _ := grid2d.path_map[start_cell] {
		if _ := grid2d.path_map[start_cell][dest_cell] {
			return true
		}
	}
	return false
}

pub fn (grid2d Grid2d) get_path_result(start_cell int, dest_cell int) []Vec2 {
	return grid2d.path_map[start_cell][dest_cell]
}

pub fn limit_number(number f64, smallest f64, largest f64) f64 {
	if number < smallest {
		return smallest
	}
	if number > largest {
		return largest
	}
	return number
}

pub fn randomize() {
	seed_array := seed.time_seed_array(2)
	rand.seed(seed_array)
}

pub fn rand_int_in_range(a int, b int) int {
	return rand.int_in_range(a, b + 1) or { return a - 1 }
}

pub fn(mut grid2d Grid2d) random_walkable_map(_percent_walkable int) {
	mut percent_walkable := _percent_walkable
	percent_walkable = i32(limit_number(f64(percent_walkable), f64(0), f64(100)))
	ncell := grid2d.cols * grid2d.rows
	mut not_walkable_cell := map[int]bool{}
	ncell_not_walkable := ncell - int(f32(percent_walkable) / 100.0 * f32(ncell))
	mut temp_cells := []int{len: ncell, cap: ncell, init: index}
	for _ in 0 .. ncell_not_walkable {
		nleft := temp_cells.len
		if nleft <= 0 {
			break
		}
		rd_i := rand_int_in_range(0, temp_cells.len - 1)
		cid := temp_cells[rd_i]
		not_walkable_cell[cid] = true
		temp_cells.delete(rd_i)
	}

	for i in 0 .. ncell {
		if _ := not_walkable_cell[i] {
			grid2d.cells[i].walkable = false
		} else {
			grid2d.cells[i].walkable = true
		}
	}
}

pub fn (mut grid2d astar2d.Grid2d) random_walkable(percent_walkable int) {
	for i, _ in grid2d.cells {
		mut walkable := false
		walkable_number := rand.int_in_range(0, 100) or { panic(err) }

		if walkable_number <= percent_walkable {
			walkable = true
		}

		grid2d.cells[i].walkable = walkable
	}
}

pub fn (grid2d Grid2d) snap_pos_to_center_cell(pos Vec2) Vec2 {
	return grid2d.id_to_pos(grid2d.pos_to_id(pos), true)
}