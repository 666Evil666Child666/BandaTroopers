/datum/ai_action/chase_target
	name = "Chase Target"
	action_flags = ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/targeting, /datum/human_ai_module/navigation)

/datum/ai_action/chase_target/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return 0

	if(brain.is_in_cover())
		return 0

	var/turf/target_turf = brain.get_target_turf()
	if(!target_turf)
		return 0

	if(brain.has_current_target())
		return 0

	if(!brain.can_move_for_action())
		return 0

	if(controller.get_distance_from(target_turf) > 20)
		return 0

	return 6

/datum/ai_action/chase_target/get_context_conflicts(datum/human_ai_context/context)
	. = ..()
	. += /datum/ai_action/throw_grenade

/datum/ai_action/chase_target/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return ONGOING_ACTION_COMPLETED

	var/turf/target_turf = brain.get_target_turf()
	if(QDELETED(target_turf) || brain.has_current_target())
		return ONGOING_ACTION_COMPLETED

	if(controller.get_distance_from(target_turf) > 0)
		if(!brain.move_to_turf(target_turf))
			return ONGOING_ACTION_COMPLETED

		if(controller.get_distance_from(target_turf) > 0)
			return ONGOING_ACTION_COMPLETED

	// Turn around as we're seeking for the lost target
	var/direction = turn(controller.get_current_dir(), pick(90,-90))
	controller.face_dir(direction)

	// Scouted, found nothing, discard
	brain.clear_target_turf()
	return ONGOING_ACTION_COMPLETED
