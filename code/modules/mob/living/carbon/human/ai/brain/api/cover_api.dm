// Human AI cover API.
// Cover state, movement gating, and cover-search helpers.

/datum/human_ai_brain/proc/has_cover()
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	return cover_module?.has_cover()

/datum/human_ai_brain/proc/is_in_cover()
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	return cover_module?.is_in_cover()

/datum/human_ai_brain/proc/has_pending_cover()
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	if(!cover_module)
		return FALSE
	return cover_module.has_cover() && !cover_module.is_in_cover()

/datum/human_ai_brain/proc/get_current_cover()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	return cover_module?.get_current_cover()

/datum/human_ai_brain/proc/end_cover()
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	cover_module?.end_cover()

/datum/human_ai_brain/proc/enter_cover()
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	cover_module?.enter_cover()

/datum/human_ai_brain/proc/try_cover(angle = null, atom/source = null)
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	cover_module?.try_cover(angle, source)

/datum/human_ai_brain/proc/apply_cover_processing(list/turf_dict, from_squad = FALSE)
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	cover_module?.cover_processing(turf_dict, from_squad)

/datum/human_ai_brain/proc/start_cover_search_cooldown(cooldown)
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	if(!cover_module)
		return
	COOLDOWN_START(cover_module, cover_search_cooldown, cooldown)

/datum/human_ai_brain/proc/get_cover_destination()
	RETURN_TYPE(/turf)
	return get_current_cover()

/datum/human_ai_brain/proc/should_hold_cover_position_against_target(datum/human_tied_controller/controller, datum/human_ai_firearm_profile/gun_data = null)
	if(!is_in_cover())
		return FALSE
	var/atom/movable/current_target = get_current_target()
	if(!current_target || !controller)
		return FALSE
	return !(controller.get_distance_to(current_target) > gun_data?.minimum_range)

/datum/human_ai_brain/proc/can_attempt_cover_move(datum/human_tied_controller/controller, datum/human_ai_firearm_profile/gun_data = null)
	if(!has_valid_tied_human() || !controller)
		return FALSE
	if(!has_cover())
		return FALSE
	if(!can_move_for_action())
		return FALSE
	if(should_hold_cover_position_against_target(controller, gun_data))
		return FALSE
	return TRUE

/datum/human_ai_brain/proc/should_block_movement_for_pending_cover()
	return has_pending_cover()

/datum/human_ai_brain/proc/should_block_stationary_fire_for_cover()
	return has_cover()
