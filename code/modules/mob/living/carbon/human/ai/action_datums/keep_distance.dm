/datum/ai_action/keep_distance
	name = "Keep Distance"
	action_flags = ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/targeting, /datum/human_ai_module/navigation, /datum/human_ai_module/inventory, /datum/human_ai_module/guns)

/datum/ai_action/keep_distance/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return 0

	var/atom/movable/current_target = brain.get_current_target()
	if(!current_target)
		return 0

	if(!brain.has_primary_weapon() || brain.has_tried_reload() || !brain.can_move_for_action())
		return 0

	var/distance = controller.get_distance_to(current_target)
	var/datum/human_ai_firearm_profile/gun_data = brain.get_gun_data()

	if(ismob(current_target) && current_target?:is_mob_incapacitated())
		if(distance != gun_data.minimum_range)
			return 10

	else if(brain.is_in_cover())
		if(!brain.can_use_ranged_fire_line(controller, current_target, gun_data))
			return 10
		if(distance < gun_data.minimum_range)
			return 10

	else if(distance != gun_data.optimal_range)
		return 10

	return 0

/datum/ai_action/keep_distance/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	if(!brain)
		return ONGOING_ACTION_COMPLETED

	if(!brain.has_current_target())
		return ONGOING_ACTION_COMPLETED

	if(!brain.has_primary_weapon())
		return ONGOING_ACTION_COMPLETED

	if(brain.has_active_grenade())
		return ONGOING_ACTION_COMPLETED

	if(brain.should_block_movement_for_pending_cover())
		return ONGOING_ACTION_COMPLETED

	return approach() || back_up() || ONGOING_ACTION_COMPLETED

/datum/ai_action/keep_distance/proc/approach()
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return ONGOING_ACTION_COMPLETED

	var/atom/movable/current_target = brain.get_current_target()
	var/datum/human_ai_firearm_profile/gun_data = brain.get_gun_data()
	var/range
	if(ismob(current_target))
		var/mob/current_mob_target = current_target
		if(current_mob_target.is_mob_incapacitated())
			range = gun_data.minimum_range
		else
			range = gun_data.optimal_range
	else
		range = gun_data.optimal_range

	var/can_fire_from_position = brain.can_use_ranged_fire_line(controller, current_target, gun_data)
	if(controller.get_distance_to(current_target) <= range)
		if(!brain.is_in_cover() || can_fire_from_position)
			return

	if(brain.is_in_cover())
		if(can_fire_from_position)
			return ONGOING_ACTION_UNFINISHED
		brain.end_cover()

	if(!brain.move_to_atom(current_target))
		return ONGOING_ACTION_COMPLETED

	return ONGOING_ACTION_UNFINISHED

/datum/ai_action/keep_distance/proc/back_up()
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return ONGOING_ACTION_COMPLETED

	var/atom/movable/current_target = brain.get_current_target()
	var/datum/human_ai_firearm_profile/gun_data = brain.get_gun_data()
	var/range
	var/is_incap = FALSE
	if(ismob(current_target))
		var/mob/current_mob_target = current_target
		is_incap = current_mob_target.is_mob_incapacitated()

	if(brain.is_in_cover() || is_incap)
		range = gun_data.minimum_range
	else
		range = gun_data.optimal_range

	if(controller.get_distance_to(current_target) >= range)
		return

	var/moved = FALSE
	var/relative_dir = controller.get_compass_dir_from(current_target)
	for(var/direction in list(relative_dir, turn(relative_dir, 90), turn(relative_dir, -90)))
		var/turf/destination = controller.get_step_in_dir(direction)
		if(brain.move_to_turf(destination))
			moved = TRUE
			break

	if(!moved)
		return ONGOING_ACTION_COMPLETED

	return ONGOING_ACTION_UNFINISHED
