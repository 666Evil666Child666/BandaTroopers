/datum/ai_action/take_cover
	name = "Take Cover"
	action_flags = ACTION_USING_LEGS

/datum/ai_action/take_cover/get_weight(datum/human_ai_brain/brain)
	if(!brain.has_valid_tied_human()) // SS220 EDIT: upstream cover action must not score after modular owner teardown
		return 0

	if(!brain.cover.has_cover())
		return 0

	if(!brain.orders.can_move_for_action())
		return 0

	if(brain.cover.is_in_cover() && !(brain.tied_controller.get_distance_to(brain.targeting.get_current_target()) > brain?.inventory?.get_gun_data()?.minimum_range))
		return 0

	return 15

/datum/ai_action/take_cover/trigger_action()
	. = ..()
	if(!brain || !brain.has_valid_tied_human()) // SS220 EDIT: cover movement exits cleanly if the modular AI owner vanishes mid-action
		return ONGOING_ACTION_COMPLETED

	var/turf/current_cover = brain.cover.get_current_cover()
	if(!current_cover)
		return ONGOING_ACTION_COMPLETED

#if defined(TESTING) || defined(HUMAN_AI_TESTING)
	current_cover.color = "#b80505"
	current_cover.maptext = "[brain.tied_controller.get_real_name()] | [brain.tied_controller.get_distance_from(current_cover)]"
#endif

	if(brain.tied_controller.get_distance_from(current_cover) > 0)
		if(!brain.navigation.move_to_next_turf(current_cover))
			brain.cover.end_cover()
			return ONGOING_ACTION_COMPLETED

		if(!brain || !brain.has_valid_tied_human())
			return ONGOING_ACTION_COMPLETED

		if(brain.tied_controller.get_distance_from(current_cover) > 0)
			return ONGOING_ACTION_UNFINISHED

	brain.cover.enter_cover()
	return ONGOING_ACTION_COMPLETED
