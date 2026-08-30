/datum/ai_action/sangheili_kick
	name = "Пинок сангхейли"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS

/datum/ai_action/sangheili_kick/Added()
	brain.halo_sangheili_holster_sword()

/datum/ai_action/sangheili_kick/get_weight(datum/human_ai_brain/brain)
	if(!brain.halo_sangheili_runtime)
		return 0

	if(!brain.combat.in_combat || !brain.orders.can_move_for_action() || brain.grenade.active_grenade_found)
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
	if(!brain.halo_sangheili_runtime || !brain.has_valid_tied_human() || !threat || !brain.combat.in_combat)
		return ONGOING_ACTION_COMPLETED

	if(brain.cover.current_cover && !brain.cover.in_cover)
		return ONGOING_ACTION_COMPLETED

	if(brain.halo_sangheili_should_sword_charge(threat))
		return ONGOING_ACTION_COMPLETED

	if(!brain.halo_sangheili_should_unarmed_commit(threat))
		return ONGOING_ACTION_COMPLETED

	if(!brain.halo_sangheili_should_overheat_response(threat) && !brain.halo_sangheili_primary_weapon_unavailable())
		return ONGOING_ACTION_COMPLETED

	brain.tied_controller.set_combat_intent()
	brain.cover.end_cover()
	brain.halo_sangheili_holster_sword()
	brain.halo_covenant_clear_hands()

	if(brain.tied_controller.get_distance_to(threat) <= 1)
		brain.tied_controller.face_atom(threat)
		if(prob(70) && brain.tied_controller.halo_use_sangheili_kick(threat))
			return ONGOING_ACTION_UNFINISHED_BLOCK
		else
			INVOKE_ASYNC(brain.tied_controller, TYPE_PROC_REF(/datum/human_tied_controller, do_click), threat, "", list())
		return ONGOING_ACTION_UNFINISHED_BLOCK

	var/turf/threat_turf = brain.halo_covenant_get_cached_threat_turf()
	if(!threat_turf)
		return ONGOING_ACTION_COMPLETED

	if(!brain.navigation.move_to_next_turf(threat_turf))
		return ONGOING_ACTION_COMPLETED

	brain.tied_controller.face_atom(threat)
	return ONGOING_ACTION_UNFINISHED_BLOCK
