// Human AI weapon and ranged-fire API.
// Firing actions still own line checks and firearm handler side effects.

/datum/human_ai_brain/proc/has_tried_reload()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	return guns_module?.has_tried_reload()

/datum/human_ai_brain/proc/mark_tried_reload()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	guns_module?.mark_tried_reload()

/datum/human_ai_brain/proc/set_tried_reload(new_value)
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	if(!guns_module)
		return
	if(new_value)
		guns_module.mark_tried_reload()
	else
		guns_module.clear_tried_reload()

/datum/human_ai_brain/proc/should_reload()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	return guns_module?.should_reload()

/datum/human_ai_brain/proc/can_start_fire()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	if(!guns_module)
		return FALSE
	return COOLDOWN_FINISHED(guns_module, stop_fire_cooldown)

/datum/human_ai_brain/proc/start_stop_fire_cooldown(cooldown)
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	if(!guns_module)
		return
	COOLDOWN_START(guns_module, stop_fire_cooldown, cooldown)

/datum/human_ai_brain/proc/can_continue_fire_burst()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	if(!guns_module)
		return FALSE
	return COOLDOWN_FINISHED(guns_module, fire_overload_cooldown)

/datum/human_ai_brain/proc/start_fire_overload_cooldown()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	if(!guns_module || !profile_module)
		return

	var/short_action_delay = profile_module.get_short_action_delay()
	COOLDOWN_START(guns_module, fire_overload_cooldown, max(short_action_delay, profile_module.get_short_action_delay(TRUE)))

/datum/human_ai_brain/proc/clear_tried_reload()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	guns_module?.clear_tried_reload()

/datum/human_ai_brain/proc/can_use_ranged_weapon()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	return guns_module && !guns_module.has_tried_reload() && (has_primary_weapon() || has_secondary_weapons())

/datum/human_ai_brain/proc/get_ranged_fire_target_turf(datum/human_ai_firearm_profile/gun_data = null)
	RETURN_TYPE(/turf)
	if(has_current_target())
		return get_current_target_turf()

	var/turf/threat_turf = get_recent_projectile_threat_turf()
	if(can_fire_offscreen(threat_turf, gun_data))
		return threat_turf
	return null

/datum/human_ai_brain/proc/can_reach_ranged_fire_target(datum/human_tied_controller/controller, turf/target_turf, maximum_range = null, datum/human_ai_firearm_profile/gun_data = null)
	if(!controller || !target_turf)
		return FALSE
	if(can_fire_offscreen(target_turf, gun_data))
		return TRUE
	if(isnull(maximum_range))
		maximum_range = get_view_distance()
	return controller.get_distance_to(target_turf) <= maximum_range

/datum/human_ai_brain/proc/can_reach_ranged_fire_atom(datum/human_tied_controller/controller, atom/target, maximum_range = null, datum/human_ai_firearm_profile/gun_data = null)
	if(!target)
		return FALSE
	return can_reach_ranged_fire_target(controller, get_turf(target), maximum_range, gun_data)

/datum/human_ai_brain/proc/can_use_ranged_fire_line(datum/human_tied_controller/controller, atom/target, datum/human_ai_firearm_profile/gun_data = null)
	if(!can_continue_runtime_work() || !controller || !target)
		return FALSE

	if(isliving(target) && controller.get_distance_to(target) <= 1)
		return TRUE

	var/list/turf_list = controller.get_line_from_current_turf_to(target)
	for(var/turf/tile in turf_list)
		var/tile_dist = controller.get_distance_to(tile)
		if(tile_dist > get_view_distance())
			continue

		if(tile.density)
			return FALSE

		for(var/obj/thing in tile)
			if(!thing.unacidable || !thing.density)
				continue

			if((tile_dist <= 3) && (thing.projectile_coverage >= PROJECTILE_COVERAGE_HIGH))
				return FALSE
			else if((tile_dist > 3) && thing.projectile_coverage >= PROJECTILE_COVERAGE_MEDIUM)
				return FALSE

	return get_fire_line_safety(target, gun_data) != HUMAN_AI_FIRE_LINE_BLOCKED

/datum/human_ai_brain/proc/get_ranged_fire_aim_target(datum/human_tied_controller/controller, atom/movable/current_target, turf/target_turf, datum/human_ai_firearm_profile/gun_data = null)
	RETURN_TYPE(/atom)
	if(!target_turf)
		return null
	if(!controller || !gun_data?.aim_adjacent_to_human_targets || !ishuman(current_target))
		return current_target || target_turf

	var/roll = rand(1, 100)
	if(roll <= gun_data.direct_human_target_chance)
		return current_target

	var/list/safe_turfs = get_safe_adjacent_human_aim_turfs(controller, target_turf)
	var/list/miss_turfs = get_miss_adjacent_human_aim_turfs(target_turf, safe_turfs)
	var/safe_roll_limit = gun_data.direct_human_target_chance + gun_data.safe_human_adjacent_target_chance
	var/miss_roll_limit = safe_roll_limit + gun_data.miss_human_adjacent_target_chance

	if(roll <= safe_roll_limit)
		if(length(safe_turfs))
			return pick(safe_turfs)
		if(length(miss_turfs))
			return pick(miss_turfs)

	else if(roll <= miss_roll_limit)
		if(length(miss_turfs))
			return pick(miss_turfs)
		if(length(safe_turfs))
			return pick(safe_turfs)

	else
		if(length(safe_turfs))
			return pick(safe_turfs)
		if(length(miss_turfs))
			return pick(miss_turfs)

	return target_turf

/datum/human_ai_brain/proc/get_safe_adjacent_human_aim_turfs(datum/human_tied_controller/controller, turf/target_turf)
	var/list/diagonal_candidates = list()
	var/list/safe_turfs = list()
	if(!controller || !target_turf)
		return safe_turfs

	var/target_distance = controller.get_distance_to(target_turf)
	for(var/direction in list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
		var/turf/candidate = get_step(target_turf, direction)
		if(!candidate || candidate.z != target_turf.z)
			continue
		if(controller.get_distance_to(candidate) >= target_distance)
			continue
		diagonal_candidates += candidate

	while(length(diagonal_candidates) && length(safe_turfs) < 2)
		var/best_index
		var/best_distance = INFINITY
		for(var/i in 1 to length(diagonal_candidates))
			var/turf/candidate = diagonal_candidates[i]
			var/candidate_distance = controller.get_distance_to(candidate)
			if(candidate_distance >= best_distance)
				continue
			best_index = i
			best_distance = candidate_distance
		if(isnull(best_index))
			break
		safe_turfs += diagonal_candidates[best_index]
		diagonal_candidates.Cut(best_index, best_index + 1)

	return safe_turfs

/datum/human_ai_brain/proc/get_miss_adjacent_human_aim_turfs(turf/target_turf, list/safe_turfs)
	var/list/miss_turfs = list()
	if(!target_turf)
		return miss_turfs

	for(var/direction in list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST, NORTH, SOUTH, EAST, WEST))
		var/turf/candidate = get_step(target_turf, direction)
		if(!candidate || candidate.z != target_turf.z)
			continue
		if((candidate in safe_turfs) || (candidate in miss_turfs))
			continue
		miss_turfs += candidate

	return miss_turfs

/datum/human_ai_brain/proc/should_block_ranged_fire_for_throwable()
	return has_active_grenade()

/datum/human_ai_brain/proc/should_defer_ranged_fire_target(atom/threat = null)
	return should_defer_ranged_fire(threat)

/datum/human_ai_brain/proc/should_defer_current_ranged_fire(datum/human_ai_firearm_profile/gun_data = null)
	return should_defer_ranged_fire_target(get_current_target() || get_ranged_fire_target_turf(gun_data))

/datum/human_ai_brain/proc/can_attempt_ranged_fire(datum/human_tied_controller/controller, obj/item/weapon/gun/primary_weapon, datum/human_ai_firearm_profile/gun_data = null, require_combat = TRUE, block_active_grenade = FALSE, check_view_distance = TRUE, check_reload = TRUE, check_tried_reload = TRUE)
	if(!has_valid_tied_human())
		return FALSE
	if(require_combat && !is_in_combat())
		return FALSE
	if(check_tried_reload && has_tried_reload())
		return FALSE
	if(!primary_weapon)
		return FALSE
	if(block_active_grenade && should_block_ranged_fire_for_throwable())
		return FALSE
	if(!can_start_fire())
		return FALSE

	var/turf/target_turf = get_ranged_fire_target_turf(gun_data)
	if(!target_turf)
		return FALSE
	if(check_view_distance && !can_reach_ranged_fire_target(controller, target_turf, get_view_distance(), gun_data))
		return FALSE
	if(should_defer_current_ranged_fire(gun_data))
		return FALSE
	if(check_reload && should_reload())
		return FALSE
	return TRUE
