/datum/ai_action/investigate_lost_target
	name = "Investigate Lost Target"
	action_flags = ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/targeting, /datum/human_ai_module/navigation)
	var/turf/investigation_center
	var/list/investigation_points
	var/current_investigation_point = 1
	var/max_investigation_distance = 20

/datum/ai_action/investigate_lost_target/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return 0

	if(brain.has_current_target() || !brain.has_recent_lost_target())
		return 0

	if(!brain.can_move_for_action())
		return 0

	var/turf/last_known_turf = brain.get_last_known_target_turf()
	if(!last_known_turf || controller.get_distance_from(last_known_turf) > max_investigation_distance)
		return 0

	return 7

/datum/ai_action/investigate_lost_target/get_context_conflicts(datum/human_ai_context/context)
	. = ..()
	. += /datum/ai_action/throw_grenade

/datum/ai_action/investigate_lost_target/Destroy(force, ...)
	investigation_center = null
	investigation_points = null
	current_investigation_point = 1
	return ..()

/datum/ai_action/investigate_lost_target/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return ONGOING_ACTION_COMPLETED

	if(brain.has_current_target())
		return ONGOING_ACTION_COMPLETED

	var/turf/last_known_turf = brain.get_last_known_target_turf()
	if(QDELETED(last_known_turf) || !brain.has_recent_lost_target())
		return ONGOING_ACTION_COMPLETED

	if(investigation_center != last_known_turf)
		build_investigation_points(last_known_turf)

	while(current_investigation_point <= length(investigation_points))
		var/turf/target_turf = investigation_points[current_investigation_point]
		if(QDELETED(target_turf))
			current_investigation_point++
			continue

		if(controller.get_distance_from(target_turf) > 0)
			if(!brain.move_to_turf(target_turf))
				current_investigation_point++
				continue

			if(controller.get_distance_from(target_turf) > 0)
				return ONGOING_ACTION_UNFINISHED

		controller.face_dir(pick(GLOB.cardinals))
		current_investigation_point++
		return ONGOING_ACTION_UNFINISHED

	brain.clear_last_known_target()
	return ONGOING_ACTION_COMPLETED

/datum/ai_action/investigate_lost_target/proc/build_investigation_points(turf/center)
	investigation_center = center
	current_investigation_point = 1
	investigation_points = list(center)

	for(var/direction in GLOB.cardinals)
		var/turf/nearby_turf = get_step(center, direction)
		if(!nearby_turf || (nearby_turf in investigation_points))
			continue

		investigation_points += nearby_turf
