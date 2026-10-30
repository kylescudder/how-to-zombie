class_name EncounterPacing
extends RefCounted
## Pure encounter clock. Only the host Director turns these decisions into spawns.
var phase := "build"
var remaining := 40.0
var elapsed := 0.0
var encounters := 0
var recovery_floor := 0.0

func recover(seconds := 35.0) -> void:
	phase = "recover"
	remaining = seconds
	recovery_floor = minf(seconds, 15.0)

## Pressure: living team health 0..1, incapacitated count, recent damage 0..1, nearby threats.
func tick(delta: float, health: float, downed: int, damage: float, threats: int, boss: bool, escape := false) -> String:
	elapsed += delta
	remaining -= delta
	var overwhelmed := downed > 0 or health < 0.38 or damage > 0.22 or boss
	if overwhelmed and phase != "recover":
		recover(22.0 if escape else 40.0)
		return "recover"
	if phase == "recover":
		recovery_floor = maxf(0, recovery_floor-delta)
		# Existing enemies must be dealt with before another wave can begin.
		if remaining <= 0 and recovery_floor <= 0 and not overwhelmed and threats < 5:
			phase = "build"
			remaining = 12.0 if escape else 25.0
		return ""
	if phase == "surge" and remaining <= 0:
		recover(18.0 if escape else 32.0)
		return "recover"
	if phase == "build" and remaining <= 0 and threats < (16 if escape else 10):
		phase = "surge"
		remaining = 25.0 if escape else 32.0
		encounters += 1
		return "wave"
	return ""
