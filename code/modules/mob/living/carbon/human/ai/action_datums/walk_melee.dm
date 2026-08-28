/datum/ai_action/walk_melee
	name = "Walk Melee"
	action_flags = ACTION_USING_LEGS

/datum/ai_action/walk_melee/get_weight(datum/human_ai_brain/brain)
	if(!brain.targeting.has_current_target())
		return 0

	if(!brain.orders.can_move_for_action())
		return 0

	if(brain.emplacement.has_sniper_home())
		return 0

	if(!brain.guns.has_tried_reload() && (brain.inventory.has_primary_weapon() || brain.inventory.has_secondary_weapons()))
		return 0

	return 3

/datum/ai_action/walk_melee/trigger_action()
	. = ..()

	var/atom/movable/current_target = brain.targeting.get_current_target()
	if(!current_target)
		return ONGOING_ACTION_COMPLETED

	if(brain.grenade.has_active_grenade())
		return ONGOING_ACTION_COMPLETED

	if(brain.cover.has_cover() && !brain.cover.is_in_cover())
		return ONGOING_ACTION_COMPLETED

	if(!brain.guns.has_tried_reload() && (brain.inventory.has_primary_weapon() || brain.inventory.has_secondary_weapons()))
		return ONGOING_ACTION_COMPLETED

	if(brain.tied_controller.get_distance_to(current_target) <= 1)
		brain.tied_controller.set_combat_intent()
		brain.inventory.unholster_any_weapon()
		INVOKE_ASYNC(brain.tied_controller, TYPE_PROC_REF(/datum/human_tied_controller, do_click), current_target, "", list())
		brain.tied_controller.face_atom(current_target)

	if(!brain.navigation.move_to_next_turf(get_turf(current_target)))
		return ONGOING_ACTION_COMPLETED

	return ONGOING_ACTION_COMPLETED
