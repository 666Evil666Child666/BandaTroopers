/datum/ai_action/treat_self
	name = "Treat Self"
	action_flags = ACTION_USING_HANDS

/datum/ai_action/treat_self/get_weight(datum/human_ai_brain/brain)
	if(brain.tied_controller.is_zombie())
		return 0

	if(brain.is_healing_someone())
		return 0

	if(brain.has_current_target() || brain.has_offscreen_fire_target())
		return 0

	if(brain.has_pickup_queue())
		return 0

	if(!brain.has_equipment(HUMAN_AI_HEALTHITEMS))
		return 0

	if(!brain.can_retry_self_treatment())
		return 0

	if(!brain.tied_controller.healing_start_check_self())
		return 0

	return 4

/datum/ai_action/treat_self/Destroy(force, ...)
	brain?.cancel_treatment() // SS220 EDIT: cancel the suspended operation, not just its busy flag
	return ..()

/datum/ai_action/treat_self/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	if(brain.has_current_target())
		return ONGOING_ACTION_COMPLETED

	if(!brain.has_equipment(HUMAN_AI_HEALTHITEMS))
		return ONGOING_ACTION_COMPLETED

	if(brain.tied_controller.is_on_fire())
		return ONGOING_ACTION_COMPLETED

	if(brain.is_healing_someone())
		return ONGOING_ACTION_UNFINISHED

	if(brain.tied_controller.healing_start_check_self())
		if(!brain.tied_controller.start_healing_self())
			brain.increment_treatment_stacks()
		return ONGOING_ACTION_UNFINISHED

	return ONGOING_ACTION_COMPLETED
