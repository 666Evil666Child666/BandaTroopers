/datum/ai_action/walk_melee
	name = "Walk Melee"
	action_flags = ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/targeting, /datum/human_ai_module/navigation, /datum/human_ai_module/combat, /datum/human_ai_module/inventory, /datum/human_ai_module/guns)

/datum/ai_action/walk_melee/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	if(!brain)
		return 0

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

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return ONGOING_ACTION_COMPLETED

	var/atom/movable/current_target = brain.get_current_target()
	if(!current_target)
		return ONGOING_ACTION_COMPLETED

	if(brain.has_active_grenade())
		return ONGOING_ACTION_COMPLETED

	if(brain.has_pending_cover())
		return ONGOING_ACTION_COMPLETED

	if(brain.can_use_ranged_weapon())
		return ONGOING_ACTION_COMPLETED

	if(controller.get_distance_to(current_target) <= 1)
		var/datum/human_ai_melee_context/melee_context = new(brain, null, current_target)
		GLOB.human_ai_melee_handler.attack(melee_context)
		qdel(melee_context)

	if(!brain.move_to_atom(current_target))
		return ONGOING_ACTION_COMPLETED

	return ONGOING_ACTION_COMPLETED
