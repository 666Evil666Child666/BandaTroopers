/datum/ai_action/walk_melee
	name = "Walk Melee"
	action_flags = ACTION_USING_LEGS

/datum/ai_action/walk_melee/get_weight(datum/human_ai_brain/brain)
	if(!brain.has_current_target())
		return 0

	if(!brain.can_move_for_action())
		return 0

	if(brain.has_sniper_home())
		return 0

	if(brain.can_use_ranged_weapon())
		return 0

	return 3

/datum/ai_action/walk_melee/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/atom/movable/current_target = brain.get_current_target()
	if(!current_target)
		return ONGOING_ACTION_COMPLETED

	if(brain.has_active_grenade())
		return ONGOING_ACTION_COMPLETED

	if(brain.has_pending_cover())
		return ONGOING_ACTION_COMPLETED

	if(brain.can_use_ranged_weapon())
		return ONGOING_ACTION_COMPLETED

	if(brain.tied_controller.get_distance_to(current_target) <= 1)
		var/datum/human_ai_melee_context/context = new(brain, null, current_target)
		GLOB.human_ai_melee_handler.attack(context)
		qdel(context)

	if(!brain.move_to_atom(current_target))
		return ONGOING_ACTION_COMPLETED

	return ONGOING_ACTION_COMPLETED
