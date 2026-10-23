extends RefCounted
class_name ScoringEngine

const MAX_COMBO: int = 5

static func calculate_damage(result: TestResult, challenge: ChallengeResource, elapsed_ms: int, combo: int) -> DamageRoll:
	var roll := DamageRoll.new()
	roll.source_side = "player"
	roll.combo_multiplier = 1.0 + min(combo, MAX_COMBO) * 0.2

	# AST gate: if structural validation failed, no damage regardless of oracle.
	if not result.ast_valid:
		roll.amount = 0
		roll.quality_tier = "D"
		roll.time_factor = 0.1
		return roll

	if result.total == 0 or result.passed == 0:
		roll.amount = 0
		roll.quality_tier = "D"
		roll.time_factor = 0.1
		return roll

	var pass_ratio: float = float(result.passed) / float(result.total)
	var time_factor: float
	if elapsed_ms < 5000:
		time_factor = 1.0
	elif elapsed_ms < 15000:
		time_factor = 0.7
	elif elapsed_ms < 25000:
		time_factor = 0.4
	else:
		time_factor = 0.1

	var diff_mult: float = 0.5 + (float(challenge.difficulty) / 10.0) * 1.5
	var base: float = lerp(float(challenge.base_damage), float(challenge.perfect_damage), pass_ratio)
	# AST quality (0.0..1.0) acts as structural multiplier: rewards good AST even
	# when oracle pass ratio is partial.
	var ast_mult: float = 0.7 + (0.3 * clamp(result.ast_quality, 0.0, 1.0))
	roll.amount = int(base * pass_ratio * time_factor * roll.combo_multiplier * diff_mult * ast_mult)
	roll.time_factor = time_factor

	if pass_ratio >= 1.0 and time_factor >= 0.7 and result.ast_quality >= 0.8:
		roll.quality_tier = "S"
	elif pass_ratio >= 0.8 and result.ast_quality >= 0.6:
		roll.quality_tier = "A"
	elif pass_ratio >= 0.5:
		roll.quality_tier = "B"
	elif pass_ratio > 0.0:
		roll.quality_tier = "C"
	else:
		roll.quality_tier = "D"

	roll.is_crit = (roll.quality_tier == "S" and time_factor >= 1.0)
	if roll.is_crit:
		roll.amount = int(roll.amount * 1.5)
	return roll

# Soft-clamp helper that fits a value into [0.0, 1.0] without referencing
# the engine global (so this can run inside tight numeric pipelines).
static func clamp(v: float, lo: float, hi: float) -> float:
	if v < lo:
		return lo
	if v > hi:
		return hi
	return v
