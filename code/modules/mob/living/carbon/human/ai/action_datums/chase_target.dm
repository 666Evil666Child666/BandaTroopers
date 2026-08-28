/datum/ai_action/chase_target
	name = "Chase Target"
	action_flags = ACTION_USING_LEGS

/datum/ai_action/chase_target/get_weight(datum/human_ai_brain/brain)
	if(brain.cover.is_in_cover())
		return 0

	var/turf/target_turf = brain.targeting.get_target_turf()
	if(!target_turf)
		return 0

	if(brain.targeting.has_current_target())
		return 0

	if(!brain.orders.can_move_for_action())
		return 0

	if(brain.tied_controller.get_distance_from(target_turf) > 20)
		return 0

	return 6

/datum/ai_action/chase_target/get_conflicts(datum/human_ai_brain/brain)
	. = ..()
	. += /datum/ai_action/throw_grenade

/datum/ai_action/chase_target/trigger_action()
	. = ..()

	var/turf/target_turf = brain.targeting.get_target_turf()
	if(QDELETED(target_turf) || brain.targeting.has_current_target())
		return ONGOING_ACTION_COMPLETED

	if(brain.tied_controller.get_distance_from(target_turf) > 0)
		if(!brain.navigation.move_to_next_turf(target_turf))
			return ONGOING_ACTION_COMPLETED

		if(brain.tied_controller.get_distance_from(target_turf) > 0)
			return ONGOING_ACTION_COMPLETED

	// Turn around as we're seeking for the lost target
	var/direction = turn(brain.tied_controller.get_current_dir(), pick(90,-90))
	brain.tied_controller.face_dir(direction)

	// Scouted, found nothing, discard
	brain.targeting.clear_target_turf()
	return ONGOING_ACTION_COMPLETED
