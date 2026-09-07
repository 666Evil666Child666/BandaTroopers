/datum/ai_action/sangheili_overheat_response
	name = "Реакция сангхейли на перегрев"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/targeting, /datum/human_ai_module/navigation, /datum/human_ai_module/inventory, /datum/human_ai_module/guns, /datum/human_ai_module/action_runtime)

/datum/ai_action/sangheili_overheat_response/Added()
	brain.halo_sangheili_holster_sword()

/datum/ai_action/sangheili_overheat_response/get_weight(datum/human_ai_brain/brain)
	if(!brain.halo_sangheili_runtime)
		return 0

	if(!brain.halo_covenant_can_run_movement_action(TRUE))
		return 0

	var/atom/threat = brain.halo_covenant_get_threat_atom()
	if(!threat)
		return 0

	if(!brain.halo_sangheili_should_overheat_response(threat))
		return 0

	if(brain.halo_sangheili_should_unarmed_commit(threat))
		return 38

	return 32

/datum/ai_action/sangheili_overheat_response/Destroy(force, ...)
	brain?.halo_sangheili_holster_sword()
	return ..()

/datum/ai_action/sangheili_overheat_response/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/atom/threat = brain.halo_covenant_get_threat_atom()
	if(!brain.halo_sangheili_runtime || !brain.has_valid_tied_human() || !threat || !brain.halo_covenant_can_run_movement_action(TRUE) || !brain.halo_sangheili_should_overheat_response(threat))
		return ONGOING_ACTION_COMPLETED

	brain.tied_controller.set_combat_intent()

	if(brain.halo_sangheili_should_unarmed_commit(threat))
		brain.halo_covenant_end_cover()
		brain.halo_sangheili_holster_sword()
		brain.halo_covenant_clear_hands()
		brain.tied_controller.face_atom(threat)
		INVOKE_ASYNC(brain.tied_controller, TYPE_PROC_REF(/datum/human_tied_controller, do_click), threat, "", list())
		return ONGOING_ACTION_UNFINISHED_BLOCK

	if(try_cover_retreat(threat))
		return ONGOING_ACTION_UNFINISHED_BLOCK

	if(step_away_from_threat(threat))
		return ONGOING_ACTION_UNFINISHED_BLOCK

	return ONGOING_ACTION_COMPLETED

/datum/ai_action/sangheili_overheat_response/proc/try_cover_retreat(atom/threat)
	return brain.halo_covenant_try_cover_retreat(threat)

/datum/ai_action/sangheili_overheat_response/proc/step_away_from_threat(atom/threat)
	return brain.halo_covenant_step_away_from_threat(threat)
