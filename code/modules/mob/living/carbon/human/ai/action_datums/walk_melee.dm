/datum/ai_action/walk_melee
	name = "Walk Melee"
	action_flags = ACTION_USING_LEGS

/datum/ai_action/walk_melee/get_weight(datum/human_ai_brain/brain)
	if(!brain.targeting.current_target)
		return 0

	if(!brain.orders.can_move_for_action())
		return 0

	if(brain.sniper_home)
		return 0

	if(!brain.guns.tried_reload && (brain.inventory.primary_weapon || length(brain.inventory.secondary_weapons)))
		return 0

	return 3

/datum/ai_action/walk_melee/trigger_action()
	. = ..()

	if(!brain.targeting.current_target)
		return ONGOING_ACTION_COMPLETED

	if(brain.grenade.active_grenade_found)
		return ONGOING_ACTION_COMPLETED

	if(brain.cover.current_cover && !brain.cover.in_cover)
		return ONGOING_ACTION_COMPLETED

	if(!brain.guns.tried_reload && (brain.inventory.primary_weapon || length(brain.inventory.secondary_weapons)))
		return ONGOING_ACTION_COMPLETED

	var/mob/tied_human = brain.tied_human
	if(get_dist(tied_human, brain.targeting.current_target) <= 1)
		tied_human.a_intent_change(INTENT_HARM)
		brain.inventory.unholster_any_weapon()
		INVOKE_ASYNC(tied_human, TYPE_PROC_REF(/mob, do_click), brain.targeting.current_target, "", list())
		tied_human.face_atom(brain.targeting.current_target)

	if(!brain.navigation.move_to_next_turf(get_turf(brain.targeting.current_target)))
		return ONGOING_ACTION_COMPLETED

	return ONGOING_ACTION_COMPLETED
