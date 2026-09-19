/datum/ai_action/take_cover
	name = "Take Cover"
	action_flags = ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/cover, /datum/human_ai_module/navigation, /datum/human_ai_module/inventory)

/datum/ai_action/take_cover/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain?.has_valid_tied_human() || !controller) // SS220 EDIT: upstream cover action must not score after modular owner teardown
		return 0

	if(!brain.can_attempt_cover_move(controller, brain.get_gun_data()))
		return 0

	return 15

/datum/ai_action/take_cover/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return ONGOING_ACTION_COMPLETED

	var/turf/current_cover = brain.get_cover_destination()
	if(!current_cover)
		return ONGOING_ACTION_COMPLETED

#if defined(TESTING) || defined(HUMAN_AI_TESTING)
	current_cover.color = "#b80505"
	current_cover.maptext = "[controller.get_real_name()] | [controller.get_distance_from(current_cover)]"
#endif

	if(controller.get_distance_from(current_cover) > 0)
		if(!brain.move_to_turf(current_cover))
			brain.end_cover()
			return ONGOING_ACTION_COMPLETED

		if(!brain.can_continue_runtime_work())
			return ONGOING_ACTION_COMPLETED

		if(controller.get_distance_from(current_cover) > 0)
			return ONGOING_ACTION_UNFINISHED

	brain.enter_cover()
	return ONGOING_ACTION_COMPLETED
