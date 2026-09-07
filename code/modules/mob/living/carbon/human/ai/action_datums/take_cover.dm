/datum/ai_action/take_cover
	name = "Take Cover"
	action_flags = ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/cover, /datum/human_ai_module/navigation, /datum/human_ai_module/orders, /datum/human_ai_module/targeting, /datum/human_ai_module/inventory)

/datum/ai_action/take_cover/get_weight(datum/human_ai_brain/brain)
	if(!brain.has_valid_tied_human()) // SS220 EDIT: upstream cover action must not score after modular owner teardown
		return 0

	if(!brain.has_cover())
		return 0

	if(!brain.can_move_for_action())
		return 0

	if(brain.is_in_cover() && !(brain.tied_controller.get_distance_to(brain.get_current_target()) > brain.get_gun_data()?.minimum_range))
		return 0

	return 15

/datum/ai_action/take_cover/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/turf/current_cover = brain.get_current_cover()
	if(!current_cover)
		return ONGOING_ACTION_COMPLETED

#if defined(TESTING) || defined(HUMAN_AI_TESTING)
	current_cover.color = "#b80505"
	current_cover.maptext = "[brain.tied_controller.get_real_name()] | [brain.tied_controller.get_distance_from(current_cover)]"
#endif

	if(brain.tied_controller.get_distance_from(current_cover) > 0)
		if(!brain.move_to_turf(current_cover))
			brain.end_cover()
			return ONGOING_ACTION_COMPLETED

		if(!brain.can_continue_runtime_work())
			return ONGOING_ACTION_COMPLETED

		if(brain.tied_controller.get_distance_from(current_cover) > 0)
			return ONGOING_ACTION_UNFINISHED

	brain.enter_cover()
	return ONGOING_ACTION_COMPLETED
