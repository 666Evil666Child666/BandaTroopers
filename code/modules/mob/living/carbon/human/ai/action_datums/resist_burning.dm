/datum/ai_action/resist_burning
	name = "Resist Burning"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS | ACTION_USING_MOUTH
	required_ai_modules = list(/datum/human_ai_module/cover)

/datum/ai_action/resist_burning/get_context_weight(datum/human_ai_context/context)
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller?.is_on_fire() || controller.is_zombie())
		return 0

	return 14

/datum/ai_action/resist_burning/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return ONGOING_ACTION_COMPLETED

	if(!controller.is_on_fire())
		return ONGOING_ACTION_COMPLETED

	if(locate(/obj/flamer_fire) in controller.get_current_turf())
		brain.try_cover()
		return ONGOING_ACTION_COMPLETED

	controller.resist()
	return ONGOING_ACTION_UNFINISHED
