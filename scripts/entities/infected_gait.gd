class_name InfectedGait
extends RefCounted
## How one infected moves. Rolled once from its spawn seed, so the host (who steers it) and every
## client (who animates it) agree without replicating anything extra.
##   runner   - the bulk of a horde: a little sway, drifts off the straight line
##   lurcher  - slow to turn, sways and stumbles, drags a leg
##   sprinter - quick, straight and hunched, surges when it gets close
##   flanker  - swings wide and comes at you from the side

var style := "runner"
var speed := 1.0      # multiplier on the type's base speed
var accel := 30.0     # how hard it can change velocity (lower = more momentum, overshoots corners)
var turn := 10.0      # how fast it swings to face where it's going
var weave := 0.0      # sideways sway, as a fraction of forward motion
var weave_hz := 0.5
var flank := 0.0      # signed angle (radians) it curls in from instead of heading straight in
var surge := 0.0      # chance per second of a short burst of speed
var stumble := 0.0    # chance per second of faltering mid-stride
var lunge := 1.0      # speed multiplier for the last few metres
# Animation only
var cadence := 1.0    # stride rate
var limp := 0.0       # one leg drags
var hunch := 0.0      # extra forward lean
var reach := 0.0      # arms held higher (+) or slacker (-)
var phase := 0.0      # offsets the sway so a horde doesn't sway in step


static func roll(type: String, seed_v: int) -> InfectedGait:
	var g := InfectedGait.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v ^ 0x5eed6a17
	g.phase = rng.randf() * TAU
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	match type:
		"common":
			var r := rng.randf()
			if r < 0.45:
				g.style = "runner"
				g.speed = rng.randf_range(0.92, 1.06)
				g.accel = rng.randf_range(20.0, 28.0)
				g.turn = rng.randf_range(7.0, 10.0)
				g.weave = rng.randf_range(0.12, 0.3)
				g.weave_hz = rng.randf_range(0.35, 0.7)
				g.flank = side * rng.randf_range(0.15, 0.5)
				g.surge = 0.08
				g.stumble = 0.05
				g.lunge = 1.08
				g.cadence = rng.randf_range(0.92, 1.08)
				g.hunch = rng.randf_range(-0.05, 0.1)
				g.reach = rng.randf_range(-0.2, 0.2)
			elif r < 0.7:
				g.style = "lurcher"
				g.speed = rng.randf_range(0.74, 0.88)
				g.accel = rng.randf_range(11.0, 16.0)
				g.turn = rng.randf_range(4.0, 6.0)
				g.weave = rng.randf_range(0.3, 0.5)
				g.weave_hz = rng.randf_range(0.25, 0.45)
				g.flank = side * rng.randf_range(0.0, 0.3)
				g.surge = 0.04
				g.stumble = 0.22
				g.lunge = 1.2
				g.cadence = rng.randf_range(0.75, 0.9)
				g.limp = rng.randf_range(0.45, 0.85)
				g.hunch = rng.randf_range(0.1, 0.25)
				g.reach = rng.randf_range(-0.5, -0.15)
			elif r < 0.85:
				g.style = "sprinter"
				g.speed = rng.randf_range(1.12, 1.22)
				g.accel = rng.randf_range(32.0, 40.0)
				g.turn = rng.randf_range(11.0, 14.0)
				g.weave = rng.randf_range(0.03, 0.1)
				g.weave_hz = rng.randf_range(0.6, 0.9)
				g.flank = side * rng.randf_range(0.05, 0.2)
				g.surge = 0.15
				g.stumble = 0.03
				g.lunge = 1.15
				g.cadence = rng.randf_range(1.1, 1.25)
				g.hunch = rng.randf_range(0.2, 0.35)
				g.reach = rng.randf_range(0.1, 0.35)
			else:
				g.style = "flanker"
				g.speed = rng.randf_range(1.0, 1.1)
				g.accel = rng.randf_range(22.0, 30.0)
				g.turn = rng.randf_range(8.0, 11.0)
				g.weave = rng.randf_range(0.1, 0.2)
				g.weave_hz = rng.randf_range(0.4, 0.6)
				g.flank = side * rng.randf_range(0.75, 1.05)
				g.surge = 0.1
				g.stumble = 0.04
				g.lunge = 1.12
				g.cadence = rng.randf_range(0.95, 1.1)
				g.hunch = rng.randf_range(0.0, 0.15)
				g.reach = rng.randf_range(-0.1, 0.25)
		"hunter":
			# Zig-zags on the approach, the way a Hunter should.
			g.style = "hunter"
			g.accel = 34.0
			g.turn = 12.0
			g.weave = 0.55
			g.weave_hz = 0.9
			g.flank = side * 0.35
		"tank":
			g.style = "tank"
			g.accel = 12.0
			g.turn = 5.0
			g.lunge = 1.1
			g.cadence = 0.9
		"witch":
			g.style = "witch"
			g.accel = 40.0
			g.turn = 14.0
			g.weave = 0.08
			g.weave_hz = 0.8
		_:
			# The other specials keep their pace but don't walk in on rails.
			g.style = "special"
			g.accel = 22.0
			g.turn = 8.0
			g.weave = rng.randf_range(0.1, 0.2)
			g.weave_hz = rng.randf_range(0.3, 0.5)
			g.flank = side * rng.randf_range(0.1, 0.3)
			g.stumble = 0.02
	return g
