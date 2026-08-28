/datum/ai_action/keep_distance
	name = "Keep Distance"
	action_flags = ACTION_USING_LEGS

/datum/ai_action/keep_distance/get_weight(datum/human_ai_brain/brain)
	var/atom/movable/current_target = brain.targeting.get_current_target()
	if(!current_target)
		return 0

	if(!brain.inventory.has_primary_weapon() || brain.guns.has_tried_reload() || !brain.orders.can_move_for_action())
		return 0

	var/distance = brain.tied_controller.get_distance_to(current_target)
	var/datum/firearm_appraisal/gun_data = brain.inventory.get_gun_data()

	if(ismob(current_target) && current_target?:is_mob_incapacitated())
		if(distance != gun_data.minimum_range)
			return 10

	else if(brain.cover.is_in_cover())
		if(distance < gun_data.minimum_range)
			return 10

	else if(distance != gun_data.optimal_range)
		return 10

	return 0

/datum/ai_action/keep_distance/trigger_action()
	. = ..()

	if(!brain.targeting.has_current_target())
		return ONGOING_ACTION_COMPLETED

	if(!brain.inventory.has_primary_weapon())
		return ONGOING_ACTION_COMPLETED

	if(brain.grenade.has_active_grenade())
		return ONGOING_ACTION_COMPLETED

	if(brain.cover.has_cover() && !brain.cover.is_in_cover())
		return ONGOING_ACTION_COMPLETED

	return approach() || back_up() || ONGOING_ACTION_COMPLETED

/datum/ai_action/keep_distance/proc/approach()
	var/atom/movable/current_target = brain.targeting.get_current_target()
	var/datum/firearm_appraisal/gun_data = brain.inventory.get_gun_data()
	var/range
	if(ismob(current_target))
		var/mob/current_mob_target = current_target
		if(current_mob_target.is_mob_incapacitated())
			range = gun_data.minimum_range
		else
			range = gun_data.optimal_range
	else
		range = gun_data.optimal_range

	if(brain.tied_controller.get_distance_to(current_target) <= range)
		return

	if(brain.cover.is_in_cover())
		return ONGOING_ACTION_UNFINISHED

	if(!brain.navigation.move_to_next_turf(get_turf(current_target)))
		return ONGOING_ACTION_COMPLETED

	return ONGOING_ACTION_UNFINISHED

/datum/ai_action/keep_distance/proc/back_up()
	var/atom/movable/current_target = brain.targeting.get_current_target()
	var/datum/firearm_appraisal/gun_data = brain.inventory.get_gun_data()
	var/range
	var/is_incap = FALSE
	if(ismob(current_target))
		var/mob/current_mob_target = current_target
		is_incap = current_mob_target.is_mob_incapacitated()

	if(brain.cover.is_in_cover() || is_incap)
		range = gun_data.minimum_range
	else
		range = gun_data.optimal_range

	if(brain.tied_controller.get_distance_to(current_target) >= range)
		return

	var/moved = FALSE
	var/relative_dir = brain.tied_controller.get_compass_dir_from(current_target)
	for(var/direction in list(relative_dir, turn(relative_dir, 90), turn(relative_dir, -90)))
		var/turf/destination = brain.tied_controller.get_step_in_dir(direction)
		if(brain.navigation.move_to_next_turf(destination))
			moved = TRUE
			break

	if(!moved)
		return ONGOING_ACTION_COMPLETED

	return ONGOING_ACTION_UNFINISHED
