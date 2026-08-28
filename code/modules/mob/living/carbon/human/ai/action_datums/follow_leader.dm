/datum/ai_action/follow_leader
	name = "Follow Leader"
	action_flags = ACTION_USING_LEGS
	var/follow_distance = 1

/datum/ai_action/follow_leader/get_weight(datum/human_ai_brain/brain)
	if(brain.cover.is_in_cover())
		return 0

	if(brain.squad.is_squad_leader)
		return 0

	if(!brain.orders.can_move_for_action())
		return 0

	if(brain.inventory.has_pickup_queue())
		return 0

	var/datum/human_ai_squad/squad = SShuman_ai.squad_id_dict["[brain.squad.squad_id]"]
	if(!squad)
		return 0

	var/datum/human_tied_controller/squad_leader_controller = squad.squad_leader?.tied_controller
	if(!squad_leader_controller?.has_valid_tied_human())
		return 0

	if(brain.tied_controller.get_distance_to_controller(squad_leader_controller) <= (1 + length(squad.ai_in_squad) / 2))
		return 0

	return 5

/datum/ai_action/follow_leader/Added()
	if(!brain.squad.squad_id)
		return

	var/datum/human_ai_squad/squad = SShuman_ai.squad_id_dict["[brain.squad.squad_id]"]
	follow_distance = 1 + length(squad.ai_in_squad) / 2

/datum/ai_action/follow_leader/trigger_action()
	. = ..()

	if(brain.combat.in_combat || brain.inventory.has_pickup_queue())
		return ONGOING_ACTION_COMPLETED

	var/datum/human_ai_squad/squad = SShuman_ai.squad_id_dict["[brain.squad.squad_id]"]
	var/datum/human_tied_controller/squad_leader_controller = squad.squad_leader?.tied_controller

	if(brain.tied_controller.get_distance_to_controller(squad_leader_controller) > follow_distance)
		if(!brain.navigation.move_to_next_turf(squad_leader_controller.get_current_turf()))
			return ONGOING_ACTION_COMPLETED

		if(brain.tied_controller.get_distance_to_controller(squad_leader_controller) > follow_distance)
			return ONGOING_ACTION_UNFINISHED

	return ONGOING_ACTION_COMPLETED
