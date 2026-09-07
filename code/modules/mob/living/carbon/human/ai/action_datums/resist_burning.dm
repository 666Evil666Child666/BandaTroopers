/datum/ai_action/resist_burning
	name = "Resist Burning"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS | ACTION_USING_MOUTH

/datum/ai_action/resist_burning/get_weight(datum/human_ai_brain/brain)
	if(!brain.tied_controller.is_on_fire() || brain.tied_controller.is_zombie())
		return 0

	return 14

/datum/ai_action/resist_burning/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	if(!brain.tied_controller.is_on_fire())
		return ONGOING_ACTION_COMPLETED

	if(locate(/obj/flamer_fire) in brain.tied_controller.get_current_turf())
		brain.try_cover()
		return ONGOING_ACTION_COMPLETED

	brain.tied_controller.resist()
	return ONGOING_ACTION_UNFINISHED
