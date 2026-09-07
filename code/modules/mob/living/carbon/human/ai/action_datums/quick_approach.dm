/datum/ai_action/quick_approach
	name = "Quick Approach"
	action_flags = ACTION_USING_LEGS

/datum/ai_action/quick_approach/get_weight(datum/human_ai_brain/brain)
	if(!brain.get_quick_approach_turf())
		return 0

	if(!brain.can_move_for_action())
		return 0

	return INFINITY

/datum/ai_action/quick_approach/Destroy(force, ...)
	brain.clear_quick_approach()
	return ..()

/datum/ai_action/quick_approach/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/turf/approach_turf = brain.get_quick_approach_turf()
	if(QDELETED(approach_turf))
		return ONGOING_ACTION_COMPLETED

	if(brain.tied_controller.get_distance_from(approach_turf) > 0)
		if(!brain.move_to_turf(approach_turf))
			return ONGOING_ACTION_UNFINISHED

		if(brain.tied_controller.get_distance_from(approach_turf) > 0)
			return ONGOING_ACTION_UNFINISHED

	return ONGOING_ACTION_COMPLETED
