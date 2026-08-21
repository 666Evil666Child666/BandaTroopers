/datum/ai_action/sangheili_kick
	name = "Пинок сангхейли"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS

/datum/ai_action/sangheili_kick/Added()
	brain.halo_sangheili_holster_sword()

/datum/ai_action/sangheili_kick/get_weight(datum/human_ai_brain/brain)
	if(!brain.halo_sangheili_runtime)
		return 0

	if(!brain.in_combat || brain.hold_position || brain.active_grenade_found)
		return 0

	var/atom/threat = brain.halo_covenant_get_threat_atom()
	if(!threat || !brain.tied_human)
		return 0

	if(brain.halo_sangheili_should_sword_charge(threat))
		return 0

	if(!brain.halo_sangheili_should_unarmed_commit(threat))
		return 0

	if(!brain.halo_sangheili_should_overheat_response(threat) && !brain.halo_sangheili_primary_weapon_unavailable())
		return 0

	if(get_dist(brain.tied_human, threat) <= 1)
		return 44

	return 18

/datum/ai_action/sangheili_kick/Destroy(force, ...)
	brain?.halo_sangheili_holster_sword()
	return ..()

/datum/ai_action/sangheili_kick/trigger_action()
	. = ..()

	var/mob/living/carbon/human/tied_human = brain.tied_human
	var/atom/threat = brain.halo_covenant_get_threat_atom()
	if(!brain.halo_sangheili_runtime || !tied_human || !threat || !brain.in_combat)
		return ONGOING_ACTION_COMPLETED

	if(brain.cover.current_cover && !brain.cover.in_cover)
		return ONGOING_ACTION_COMPLETED

	if(brain.halo_sangheili_should_sword_charge(threat))
		return ONGOING_ACTION_COMPLETED

	if(!brain.halo_sangheili_should_unarmed_commit(threat))
		return ONGOING_ACTION_COMPLETED

	if(!brain.halo_sangheili_should_overheat_response(threat) && !brain.halo_sangheili_primary_weapon_unavailable())
		return ONGOING_ACTION_COMPLETED

	tied_human.a_intent_change(INTENT_HARM)
	brain.cover.end_cover()
	brain.halo_sangheili_holster_sword()
	brain.halo_covenant_clear_hands()

	if(get_dist(tied_human, threat) <= 1)
		var/datum/action/human_action/activable/covenant/sangheili_kick/kick_action = locate(/datum/action/human_action/activable/covenant/sangheili_kick) in tied_human.actions
		tied_human.face_atom(threat)
		if(kick_action && prob(70))
			INVOKE_ASYNC(kick_action, TYPE_PROC_REF(/datum/action/human_action/activable/covenant/sangheili_kick, use_ability), threat, tied_human)
		else
			INVOKE_ASYNC(tied_human, TYPE_PROC_REF(/mob, do_click), threat, "", list())
		return ONGOING_ACTION_UNFINISHED_BLOCK

	var/turf/threat_turf = brain.halo_covenant_get_cached_threat_turf()
	if(!threat_turf)
		return ONGOING_ACTION_COMPLETED

	if(!brain.move_to_next_turf(threat_turf))
		return ONGOING_ACTION_COMPLETED

	tied_human.face_atom(threat)
	return ONGOING_ACTION_UNFINISHED_BLOCK
