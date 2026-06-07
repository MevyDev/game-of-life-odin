package main

import "core:fmt"
import "core:math/rand"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

Tile :: enum {
	Empty,
	Full,
}


Window :: struct {
	width:  i32,
	height: i32,
	title:  string,
	fps:    i32,
}


Board :: struct {
	width:  i32,
	height: i32,
	data:   []Tile,
}


Offset :: struct {
	x: i32,
	y: i32,
}


Pos :: struct {
	x: i32,
	y: i32,
}


Input :: struct {
	mouse_tile_pos:     Pos,
	left_mouse_button:  bool,
	right_mouse_button: bool,
	toggle_pause:       bool,
	should_exit:        bool,
}


Game :: struct {
	board:     Board,
	window:    Window,
	tick_rate: time.Duration,
	last_tick: time.Time,
	colors:    [Tile]rl.Color,
	paused:    bool,
}


game_render :: proc(game: ^Game) {
	for x in 0 ..< game.board.width {
		for y in 0 ..< game.board.height {
			idx := pos_to_idx(game.board, Pos{x, y})

			tile := game.board.data[idx]
			color := game.colors[tile]

			rect: rl.Rectangle = {
				x      = f32(x) * (f32(game.window.width) / f32(game.board.width)),
				y      = f32(y) * (f32(game.window.height) / f32(game.board.height)),
				width  = (f32(game.window.width) / f32(game.board.width)),
				height = (f32(game.window.height) / f32(game.board.height)),
			}

			rl.DrawRectangleRec(rect, color)
		}
	}
}


update_board :: proc(old_board: Board, new_board: Board) {
	width := old_board.width
	height := old_board.height
	for x in 0 ..< width {
		for y in 0 ..< height {
			idx := pos_to_idx(old_board, Pos{x, y})

			switch neighbor_count(old_board, Pos{x, y}) {
			case 2:
				new_board.data[idx] = old_board.data[idx]
			case 3:
				new_board.data[idx] = .Full
			case:
				new_board.data[idx] = .Empty
			}
		}
	}
}


pos_to_idx :: proc(board: Board, pos: Pos) -> i32 {
	return pos.x + pos.y * board.width
}


tile_at_pos :: proc(board: Board, pos: Pos) -> Tile {
	return board.data[pos_to_idx(board, pos)]
}


apply_offset :: proc(board: Board, pos: Pos, offset: Offset) -> Pos {
	n_x := (pos.x + offset.x) %% board.width
	n_y := (pos.y + offset.y) %% board.height
	assert(n_x >= 0 && n_x <= board.width)
	assert(n_y >= 0 && n_y <= board.height)
	return Pos{n_x, n_y}

}


neighbor_count :: proc(board: Board, pos: Pos) -> i32 {
	assert(pos.x < board.width)
	assert(pos.y < board.height)
	assert(min(pos.x, pos.y) >= 0)

	count: i32 = 0

	offsets: [8]Offset = {{-1, -1}, {-1, 0}, {-1, 1}, {0, -1}, {0, 1}, {1, -1}, {1, 0}, {1, -1}}

	for offset in offsets {
		offset_pos := apply_offset(board, pos, offset)
		if tile_at_pos(board, offset_pos) != .Empty {
			count += 1
		}
	}

	return count
}


input_processing :: proc(input: ^Input, game: ^Game) {
	m_x_fl := f32(rl.GetMouseX())
	m_y_fl := f32(rl.GetMouseY())
	mouse_tile_x := i32(m_x_fl / f32(game.window.width) * f32(game.board.width))
	mouse_tile_y := i32(m_y_fl / f32(game.window.height) * f32(game.board.height))
	input.mouse_tile_pos = Pos{mouse_tile_x, mouse_tile_y}
	input.left_mouse_button = rl.IsMouseButtonDown(.LEFT)
	input.right_mouse_button = rl.IsMouseButtonDown(.RIGHT)
	input.toggle_pause = rl.IsKeyPressed(.SPACE)
	input.should_exit = rl.IsKeyPressed(.ESCAPE)
}

cursor_render :: proc(game: ^Game, pos: Pos, color: rl.Color) {
	rect: rl.Rectangle = {
		x      = f32(pos.x) * (f32(game.window.width) / f32(game.board.width)),
		y      = f32(pos.y) * (f32(game.window.height) / f32(game.board.height)),
		width  = (f32(game.window.width) / f32(game.board.width)),
		height = (f32(game.window.height) / f32(game.board.height)),
	}

	rl.DrawRectangleRec(rect, color)
}

main :: proc() {
	game := Game {
		board = Board{60, 60, make([]Tile, 60 * 60)},
		window = Window{width = 720, height = 720, title = "Odin Game of Life", fps = 60},
		tick_rate = 250 * time.Millisecond,
		last_tick = time.now(),
		colors = {.Empty = rl.PINK, .Full = rl.SKYBLUE},
		paused = true,
	}

	rl.InitWindow(
		game.window.height,
		game.window.width,
		strings.clone_to_cstring(game.window.title),
	)
	rl.SetTargetFPS(game.window.fps)

	input: Input

	new_board := Board{60, 60, make([]Tile, 60 * 60)}


	for !rl.WindowShouldClose() {

		input_processing(&input, &game)

		if (input.left_mouse_button) {
			game.board.data[pos_to_idx(game.board, input.mouse_tile_pos)] = .Full
		}
		if (input.right_mouse_button) {
			game.board.data[pos_to_idx(game.board, input.mouse_tile_pos)] = .Empty
		}
		if (input.toggle_pause) {
			game.paused = !game.paused
		}

		if !game.paused && time.since(game.last_tick) >= game.tick_rate {
			game.last_tick = time.now()
			update_board(game.board, new_board)

			game.board, new_board = new_board, game.board
		}


		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.BLUE)
		game_render(&game)
		cursor_render(&game, input.mouse_tile_pos, rl.WHITE)
	}
}
