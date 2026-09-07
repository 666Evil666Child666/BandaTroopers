/datum/ai_action/follow_leader
	name = "Follow Leader"
	action_flags = ACTION_USING_LEGS
	var/follow_distance = 1

/datum/ai_action/follow_leader/get_weight(datum/human_ai_brain/brain)
	if(brain.is_in_cover())
		return 0

	if(brain.is_squad_leader())
		return 0

	if(!brain.can_move_for_action())
		return 0

	if(brain.has_pickup_queue())
		return 0

	var/datum/human_ai_squad/squad = brain.get_squad_datum()
	if(!squad)
		return 0

	var/datum/human_tied_controller/squad_leader_controller = squad.squad_leader?.tied_controller
	if(!squad_leader_controller?.has_valid_tied_human())
		return 0

	if(brain.tied_controller.get_distance_to_controller(squad_leader_controller) <= (1 + length(squad.ai_in_squad) / 2))
		return 0

	return 5

/datum/ai_action/follow_leader/Added()
	if(!brain.get_squad_id())
		return

	var/datum/human_ai_squad/squad = brain.get_squad_datum()
	follow_distance = 1 + length(squad.ai_in_squad) / 2

/datum/ai_action/follow_leader/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	if(brain.is_in_combat() || brain.has_pickup_queue())
		return ONGOING_ACTION_COMPLETED

	var/datum/human_ai_squad/squad = brain.get_squad_datum()
	var/datum/human_tied_controller/squad_leader_controller = squad.squad_leader?.tied_controller

	if(brain.tied_controller.get_distance_to_controller(squad_leader_controller) > follow_distance)
		if(!brain.move_to_turf(squad_leader_controller.get_current_turf()))
			return ONGOING_ACTION_COMPLETED

		if(brain.tied_controller.get_distance_to_controller(squad_leader_controller) > follow_distance)
			return ONGOING_ACTION_UNFINISHED

	return ONGOING_ACTION_COMPLETED
