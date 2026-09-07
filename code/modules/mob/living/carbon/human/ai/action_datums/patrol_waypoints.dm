/datum/ai_action/patrol_waypoints
	name = "Patrol Waypoints"
	action_flags = ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/navigation, /datum/human_ai_module/squad, /datum/human_ai_module/combat, /datum/human_ai_module/inventory)

/datum/ai_action/patrol_waypoints/get_weight(datum/human_ai_brain/brain)
	if(brain.is_in_combat())
		return 0

	var/datum/ai_order/patrol/current_order = brain.get_current_order()
	if(!istype(current_order))
		return 0

	if(brain.has_pickup_queue())
		return 0

	if(current_order.waiting)
		return 0

	if(!brain.is_squad_leader())
		if(brain.tied_controller.get_distance_to(current_order.current_waypoint) <= 1)
			return 0

	return 4

/datum/ai_action/patrol_waypoints/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/ai_order/patrol/current_order = brain.get_current_order()
	if(current_order.waiting || QDELETED(current_order) || !istype(current_order) || brain.has_pickup_queue() || brain.is_in_combat())
		return ONGOING_ACTION_COMPLETED

	var/turf/current_waypoint = current_order.current_waypoint
	if(QDELETED(current_waypoint))
		var/datum/human_ai_squad/squad = brain.get_squad_datum()
		if(squad)
			squad.remove_current_order() // Our brain is included
		else
			brain.remove_current_order()
		return ONGOING_ACTION_COMPLETED

	if(brain.tied_controller.get_distance_from(current_waypoint) > 1)
		if(!brain.move_to_turf(current_waypoint))
			return ONGOING_ACTION_COMPLETED

		if(brain.tied_controller.get_distance_from(current_waypoint) > 1)
			return ONGOING_ACTION_UNFINISHED

	if(brain.is_squad_leader())
		current_order.waiting = TRUE
		addtimer(CALLBACK(current_order, TYPE_PROC_REF(/datum/ai_order/patrol, set_next_waypoint)), current_order.time_at_waypoint)

	return ONGOING_ACTION_COMPLETED
