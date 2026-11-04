class_name Economy
extends RefCounted

## All reward formulas from the spec. Integer marks; no premium currency.

static func underdog_bonus(deck_power: int, recommended_power: int) -> float:
	if recommended_power <= 0:
		return 0.0
	var gap := float(maxi(0, recommended_power - deck_power)) / float(recommended_power)
	return minf(0.60, gap)

static func win_marks(floor_number: int, current_streak: int, underdog: float, boss: bool = false) -> int:
	var base := 10.0 + 3.0 * float(floor_number)
	var streak_mult := 1.0 + 0.1 * float(mini(current_streak, 10))
	var total := base * streak_mult * (1.0 + underdog)
	if boss:
		total *= 4.0
	return int(floor(total))

static func perfect_clear_marks(floor_number: int, current_streak: int, underdog: float) -> int:
	## First clear adds +200% to the win payout.
	return int(floor(win_marks(floor_number, current_streak, underdog) * 3.0))

static func performance(stats: Dictionary, floors_cleared: int, best_streak: int) -> Dictionary:
	var damage_dealt := int(stats.get("damage_dealt", 0))
	var damage_healed := int(stats.get("damage_healed", 0))
	var cards_played := int(stats.get("cards_played", 0))
	var flawless := int(stats.get("flawless_duels", 0))
	var floor_points := 20 * floors_cleared
	var streak_points := 5 * mini(best_streak, 10)
	var flawless_points := 25 * flawless
	var damage_points := mini(40, damage_dealt / 500)
	var heal_points := mini(20, damage_healed / 500)
	var play_points := mini(20, cards_played / 5)
	var total := floor_points + streak_points + flawless_points + damage_points + heal_points + play_points
	return {
		"floors_cleared": floors_cleared,
		"floor_points": floor_points,
		"streak_points": streak_points,
		"flawless_points": flawless_points,
		"damage_points": damage_points,
		"heal_points": heal_points,
		"cards_points": play_points,
		"total": total,
	}

static func loss_marks(performance_total: int, underdog: float) -> int:
	return int(floor(float(25 + performance_total) * (1.0 + underdog)))

static func recall_marks(floors_cleared: int, underdog: float) -> int:
	return int(floor(float(10 + 10 * floors_cleared) * (1.0 + underdog)))

static func print_cost(rarity: String) -> int:
	return {"common": 20, "uncommon": 80, "rare": 300, "legendary": 2000}.get(rarity, 20)

static func dissolve_value(rarity: String) -> int:
	return {"common": 5, "uncommon": 15, "rare": 50, "legendary": 200}.get(rarity, 5)

static func xp_for_win(floor_number: int, first_clear: bool = false) -> int:
	return (10 + floor_number) + (25 if first_clear else 0)

static func xp_for_loss(floor_number: int, floors_cleared: int) -> int:
	return 5 + floor_number + 2 * floors_cleared

static func mastery_level_for_xp(xp: int) -> int:
	var thresholds := [0, 10, 25, 50, 100, 200, 400, 800, 1600, 3200]
	var level := 1
	for i in range(1, thresholds.size()):
		if xp >= int(thresholds[i]):
			level = i + 1
	return mini(level, 10)

static func mastery_xp_for_next(xp: int) -> int:
	var thresholds := [0, 10, 25, 50, 100, 200, 400, 800, 1600, 3200]
	for threshold in thresholds:
		if xp < int(threshold):
			return int(threshold) - xp
	return 0
