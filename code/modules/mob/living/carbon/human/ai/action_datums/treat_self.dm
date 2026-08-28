/datum/ai_action/treat_self
	name = "Treat Self"
	action_flags = ACTION_USING_HANDS

/datum/ai_action/treat_self/get_weight(datum/human_ai_brain/brain)
	if(brain.tied_controller.is_zombie())
		return 0

	if(brain.health.healing_someone)
		return 0

	var/should_fire_offscreen = (brain.targeting.has_target_turf() && !COOLDOWN_FINISHED(brain, targeting.fire_offscreen))
	if(brain.targeting.has_current_target() || should_fire_offscreen)
		return 0

	if(brain.inventory.has_pickup_queue())
		return 0

	if(!brain.inventory.has_equipment(HUMAN_AI_HEALTHITEMS))
		return 0

	if(brain.health.cant_be_treated_stacks >= brain.health.treatment_stack_threshold)
		return 0

	if(!brain.tied_controller.healing_start_check_self())
		return 0

	return 4

/datum/ai_action/treat_self/Destroy(force, ...)
	brain.health.healing_someone = FALSE
	return ..()

/datum/ai_action/treat_self/trigger_action()
	. = ..()

	if(brain.targeting.has_current_target())
		return ONGOING_ACTION_COMPLETED

	if(!brain.inventory.has_equipment(HUMAN_AI_HEALTHITEMS))
		return ONGOING_ACTION_COMPLETED

	if(brain.tied_controller.is_on_fire())
		return ONGOING_ACTION_COMPLETED

	if(brain.health.healing_someone)
		return ONGOING_ACTION_UNFINISHED

	if(brain.tied_controller.healing_start_check_self())
		if(!brain.tied_controller.start_healing_self())
			brain.health.cant_be_treated_stacks++
		return ONGOING_ACTION_UNFINISHED

	return ONGOING_ACTION_COMPLETED
