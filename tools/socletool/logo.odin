package socletool

// logo: socle's mark, drawn by the toolkit's paint package (the same bytes on every system). Three slabs stacked as a
// plinth, seen from above at an angle, in Nix's blues: the widest and darkest at the bottom, the palest on top. They
// are the layers that make a system and the base it stands on. Nix's snowflake lies flat on the top slab, drawn in
// the same projection, so it reads as set on the platform and not pasted over it. Each slab shows its top and its two
// sides, lit from the upper left. Nothing is outlined: the mark reads the same on a light and on a dark background.
// toolbox.write_logo writes assets/logo*.png, socle.ico and .project/image.png from logo_draw.

import "core:math"
import "core:slice"
import paint "gt:paint"
import toolbox "gt:toolbox"

LOGO_DIR       :: "assets"
LOGO_MASTER    :: 1024
LOGO_SIZES     :: [?]int{16, 32, 64, 128, 256}
LOGO_ICO       :: "assets/socle.ico"
// The drawing's own units: a square of LOGO_UNITS, scaled to the canvas.
LOGO_UNITS     :: 512.0
LOGO_DRAW_SIZE :: 512

// The view's slope: a slab's top face is a square turned by 45 degrees, then flattened to this share of its height.
// (close to true isometry: a flatter view squashes the snowflake until it no longer reads)
SLOPE :: 0.6

// A slab: its half width, its thickness, and its top face's centre, in units.
Slab :: struct {
	half, thick:      f32,
	centre:           [2]f32,
	top, left, right: u32,
}

// From the bottom up. A slab's centre is the one below it, raised by its own thickness and a small gap: the gap shows
// that the layers are separate. The mark spans the square's height with the same margin above and below.
SLABS :: [3]Slab{
	{half = 236, thick = 40, centre = {256, 261}, top = 0x5277C3, left = 0x415E9A, right = 0x33497A},
	{half = 203, thick = 38, centre = {256, 215}, top = 0x7EBAE4, left = 0x699AD7, right = 0x4F7FB8},
	{half = 170, thick = 36, centre = {256, 171}, top = 0xEEF4FB, left = 0xC5D7EC, right = 0x9DB8D9},
}

// Nix's snowflake (NixOS artwork, nix-snowflake-colours.svg): one lambda's outline in the artwork's units, the
// flake's centre, and its radius there. The six lambdas are this one turned around the centre.
LAMBDA_START :: [2]f32{309.54892, -710.38827}
@(rodata)
LAMBDA_STEPS := [?][2]f32{
	{122.19683, 211.67512}, {-56.15706, 0.5268}, {-32.6236, -56.8692}, {-32.85645, 56.5653},
	{-27.90237, -0.011}, {-14.29086, -24.6896}, {46.81047, -80.4901}, {-33.22946, -57.8257},
}
FLAKE_CENTRE :: [2]f32{407.3, -715.8}
FLAKE_RADIUS :: 250.0
// The turns of the light and the dark lambdas, in degrees, as the artwork places them.
FLAKE_LIGHT  :: [3]f32{60, -60, 180}
FLAKE_DARK   :: [3]f32{0, 120, -120}
// The flake's turn in the plane of the face. The projection turns the face by 45 degrees: the flake is turned back by
// as much, so it still lies flat but stands upright on the screen, as people know it.
FLAKE_TURN   :: -45.0
// The flake's radius on the top face, as a share of the face's inscribed circle: a clear border of the face stays
// around it, so the flake reads as an object on the platform.
FLAKE_FILL   :: 0.78
// The mark's size in the square: room stays around it, as around the suite's other marks.
MARK_SCALE   :: 0.9
// The flake stands in relief on the platform. The light lambdas rise higher than the dark ones: two heights give the
// flake depth, as the slabs' steps give it to the plinth. The visible walls take the light as the slabs' sides do:
// the walls that face left are lit, the ones that face right are in shade.
Lambda_Look :: struct {
	top, lit, shade: u32,
	height:          f32,   // in units
}

FLAKE_LIGHT_LOOK :: Lambda_Look{top = 0x7EBAE4, lit = 0x5E9CD2, shade = 0x4A80B8, height = 26}
FLAKE_DARK_LOOK  :: Lambda_Look{top = 0x5277C3, lit = 0x415E9A, shade = 0x31487A, height = 12}

@(private = "file")
face :: proc(c: ^paint.Canvas, points: [][2]f32, colour: u32) {
	p: paint.Path
	defer paint.path_destroy(&p)
	paint.polygon(&p, points)
	paint.fill(c, p, paint.solid(paint.hex(colour)))
}

// One lambda turned by `degrees` around the flake's centre, moved to the plane of a top face (its centre at `at`, the
// flake `radius` units wide), then projected as the faces are: its outline at the foot of its relief.
@(private = "file")
lambda_outline :: proc(degrees: f32, at: [2]f32, radius: f32) -> [][2]f32 {
	turn := math.to_radians(degrees + FLAKE_TURN)
	k := radius / FLAKE_RADIUS
	diagonal := math.to_radians(f32(45))
	points := make([dynamic][2]f32, context.temp_allocator)
	p := LAMBDA_START
	project :: proc(p: [2]f32, turn, k, diagonal: f32, at: [2]f32) -> [2]f32 {
		d := p - FLAKE_CENTRE
		r := [2]f32{d.x * math.cos(turn) - d.y * math.sin(turn), d.x * math.sin(turn) + d.y * math.cos(turn)} * k
		q := [2]f32{r.x * math.cos(diagonal) - r.y * math.sin(diagonal), r.x * math.sin(diagonal) + r.y * math.cos(diagonal)}
		return {at.x + q.x, at.y + q.y * SLOPE}
	}
	append(&points, project(p, turn, k, diagonal, at))
	for step in LAMBDA_STEPS {
		p += step
		append(&points, project(p, turn, k, diagonal, at))
	}
	return points[:]
}

// A lambda raised from its foot: the walls that face the viewer, then its top, its height higher on the screen.
@(private = "file")
raised :: proc(c: ^paint.Canvas, foot: [][2]f32, look: Lambda_Look) {
	// (the outline's turn, from the shoelace sum: it says on which side of each edge the outside is; the projection
	// keeps it)
	area: f32
	for a, i in foot {
		b := foot[(i + 1) % len(foot)]
		area += a.x * b.y - b.x * a.y
	}
	up := [2]f32{0, -look.height}
	for a, i in foot {
		b := foot[(i + 1) % len(foot)]
		d := b - a
		outward := area > 0 ? [2]f32{d.y, -d.x} : [2]f32{-d.y, d.x}
		// (a wall whose outside points up the screen is behind its lambda: the top covers it)
		if outward.y <= 0 { continue }
		face(c, {a, b, b + up, a + up}, outward.x < 0 ? look.lit : look.shade)
	}
	top := make([][2]f32, len(foot), context.temp_allocator)
	for p, i in foot { top[i] = p + up }
	face(c, top, look.top)
}

logo_draw :: proc(pixels, _: int) -> paint.Canvas {
	c := paint.canvas_make(pixels, pixels)
	k := f32(pixels) / LOGO_UNITS
	// (a call's step applies before the steps already in the matrix: the mark is shrunk around the square's centre,
	// then scaled to the canvas)
	c.transform = paint.scale(paint.IDENTITY, k, k)
	c.transform = paint.translate(c.transform, LOGO_UNITS / 2, LOGO_UNITS / 2)
	c.transform = paint.scale(c.transform, MARK_SCALE, MARK_SCALE)
	c.transform = paint.translate(c.transform, -LOGO_UNITS / 2, -LOGO_UNITS / 2)
	slabs := SLABS
	for s in slabs {
		x, y := s.centre.x, s.centre.y
		w, h, t := s.half, s.half * SLOPE, s.thick
		// (the sides first: the top face's edge then covers their seam)
		face(&c, {{x - w, y}, {x, y + h}, {x, y + h + t}, {x - w, y + t}}, s.left)
		face(&c, {{x, y + h}, {x + w, y}, {x + w, y + t}, {x, y + h + t}}, s.right)
		face(&c, {{x, y - h}, {x + w, y}, {x, y + h}, {x - w, y}}, s.top)
	}
	// (the top face is a square of half side half/sqrt(2) before the projection: its inscribed circle holds the flake)
	top := slabs[len(slabs) - 1]
	radius := FLAKE_FILL * top.half / math.SQRT_TWO
	Placed :: struct {
		foot:    [][2]f32,
		look:  Lambda_Look,
		front: f32,   // the lowest point on the screen: the nearest to the viewer
	}
	lambdas := make([dynamic]Placed, context.temp_allocator)
	for d in FLAKE_LIGHT { append(&lambdas, Placed{foot = lambda_outline(d, top.centre, radius), look = FLAKE_LIGHT_LOOK}) }
	for d in FLAKE_DARK { append(&lambdas, Placed{foot = lambda_outline(d, top.centre, radius), look = FLAKE_DARK_LOOK}) }
	for &l in lambdas {
		l.front = min(f32)
		for p in l.foot { l.front = max(l.front, p.y) }
	}
	// (the low lambdas first, then the high ones, each group from the back to the front. The lambdas touch without
	// overlapping on the platform, so a high one's walls cover its low neighbours, and a low one never rises in front
	// of a high one's top)
	slice.sort_by(lambdas[:], proc(a, b: Placed) -> bool {
		if a.look.height != b.look.height { return a.look.height < b.look.height }
		return a.front < b.front
	})
	for l in lambdas { raised(&c, l.foot, l.look) }
	return c
}

logo :: proc() -> toolbox.Logo {
	@(static) sizes := LOGO_SIZES
	return {
		draw = proc(pixels, size: int, _: rawptr) -> paint.Canvas { return logo_draw(pixels, size) },
		draw_size = LOGO_DRAW_SIZE, dir = LOGO_DIR, master = LOGO_MASTER, sizes = sizes[:], ico = LOGO_ICO,
		project_image = true,
	}
}
