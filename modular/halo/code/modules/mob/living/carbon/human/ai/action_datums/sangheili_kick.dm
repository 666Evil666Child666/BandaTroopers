/datum/ai_action/sangheili_kick
	name = "Пинок сангхейли"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/targeting, /datum/human_ai_module/navigation, /datum/human_ai_module/inventory, /datum/human_ai_module/action_runtime)

/datum/ai_action/sangheili_kick/Added()
	brain.halo_sangheili_holster_sword()

/datum/ai_action/sangheili_kick/get_weight(datum/human_ai_brain/brain)
	if(!brain.halo_sangheili_runtime)
		return 0

	if(!brain.halo_covenant_can_run_movement_action(TRUE))
		return 0

	var/atom/threat = brain.halo_covenant_get_threat_atom()
	if(!threat || !brain.has_valid_tied_human())
		return 0

	if(brain.halo_sangheili_should_sword_charge(threat))
		return 0

	if(!brain.halo_sangheili_should_unarmed_commit(threat))
		return 0

	if(!brain.halo_sangheili_should_overheat_response(threat) && !brain.halo_sangheili_primary_weapon_unavailable())
		return 0

	if(brain.tied_controller.get_distance_to(threat) <= 1)
		return 44

	return 18

/datum/ai_action/sangheili_kick/Destroy(force, ...)
	brain?.halo_sangheili_holster_sword()
	return ..()

/datum/ai_action/sangheili_kick/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/atom/threat = brain.halo_covenant_get_threat_atom()
	if(!brain.halo_sangheili_runtime || !brain.has_valid_tied_human() || !threat || !brain.halo_covenant_can_run_movement_action(TRUE))
		return ONGOING_ACTION_COMPLETED

	if(brain.halo_covenant_has_pending_cover())
		return ONGOING_ACTION_COMPLETED

	if(brain.halo_sangheili_should_sword_charge(threat))
		return ONGOING_ACTION_COMPLETED

	if(!brain.halo_sangheili_should_unarmed_commit(threat))
		return ONGOING_ACTION_COMPLETED

	if(!brain.halo_sangheili_should_overheat_response(threat) && !brain.halo_sangheili_primary_weapon_unavailable())
		return ONGOING_ACTION_COMPLETED

	brain.tied_controller.set_combat_intent()
	brain.halo_covenant_end_cover()
	brain.halo_sangheili_holster_sword()
	brain.halo_covenant_clear_hands()

	if(brain.tied_controller.get_distance_to(threat) <= 1)
		brain.tied_controller.face_atom(threat)
		if(prob(70) && brain.tied_controller.halo_use_sangheili_kick(threat))
			return ONGOING_ACTION_UNFINISHED_BLOCK
		else
			INVOKE_ASYNC(brain.tied_controller, TYPE_PROC_REF(/datum/human_tied_controller, do_click), threat, "", list())
		return ONGOING_ACTION_UNFINISHED_BLOCK

	if(!brain.halo_covenant_move_to_threat(threat))
		return ONGOING_ACTION_COMPLETED
	return ONGOING_ACTION_UNFINISHED_BLOCK
