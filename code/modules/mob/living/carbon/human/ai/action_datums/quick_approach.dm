/datum/ai_action/quick_approach
	name = "Quick Approach"
	action_flags = ACTION_USING_LEGS

/datum/ai_action/quick_approach/get_weight(datum/human_ai_brain/brain)
	if(!brain.orders.quick_approach)
		return 0

	if(!brain.orders.can_move_for_action())
		return 0

	return INFINITY

/datum/ai_action/quick_approach/Destroy(force, ...)
	brain.orders.clear_quick_approach()
	return ..()

/datum/ai_action/quick_approach/trigger_action()
	. = ..()

	var/turf/approach_turf = brain.orders.quick_approach
	if(QDELETED(approach_turf))
		return ONGOING_ACTION_COMPLETED

	var/mob/tied_human = brain.tied_human
	if(get_dist(approach_turf, tied_human) > 0)
		if(!brain.navigation.move_to_next_turf(approach_turf))
			return ONGOING_ACTION_UNFINISHED

		if(get_dist(approach_turf, tied_human) > 0)
			return ONGOING_ACTION_UNFINISHED

	return ONGOING_ACTION_COMPLETED
