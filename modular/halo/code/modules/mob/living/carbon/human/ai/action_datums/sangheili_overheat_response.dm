/datum/ai_action/sangheili_overheat_response
	name = "Реакция сангхейли на перегрев"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS

/datum/ai_action/sangheili_overheat_response/Added()
	brain.halo_sangheili_holster_sword()

/datum/ai_action/sangheili_overheat_response/get_weight(datum/human_ai_brain/brain)
	if(!brain.halo_sangheili_runtime)
		return 0

	if(!brain.combat.in_combat || !brain.orders.can_move_for_action() || brain.grenade.active_grenade_found)
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

	var/atom/threat = brain.halo_covenant_get_threat_atom()
	if(!brain.halo_sangheili_runtime || !brain.has_valid_tied_human() || !threat || !brain.combat.in_combat || !brain.halo_sangheili_should_overheat_response(threat))
		return ONGOING_ACTION_COMPLETED

	brain.tied_controller.set_combat_intent()

	if(brain.halo_sangheili_should_unarmed_commit(threat))
		brain.cover.end_cover()
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
	if(!brain.cover.current_cover)
		brain.cover.try_cover(brain.tied_controller.get_angle_from(threat), threat)

	var/turf/cover_turf = get_turf(brain.cover.current_cover)
	if(!cover_turf)
		return FALSE

	if(brain.tied_controller.get_distance_to(cover_turf) > 0)
		if(!brain.navigation.move_to_next_turf(cover_turf))
			brain.cover.end_cover()
			return FALSE

		return TRUE

	brain.cover.in_cover = TRUE
	brain.tied_controller.face_atom(threat)
	return TRUE

/datum/ai_action/sangheili_overheat_response/proc/step_away_from_threat(atom/threat)
	var/turf/threat_turf = brain.halo_covenant_get_cached_threat_turf()
	if(!brain.has_valid_tied_human() || !threat_turf)
		return FALSE

	var/turf/best_destination
	var/best_score = -INFINITY

	for(var/direction in GLOB.cardinals)
		var/turf/destination = brain.tied_controller.get_step_in_dir(direction)
		if(!destination || destination.density)
			continue

		var/score = get_dist(destination, threat_turf)
		if(score > best_score)
			best_score = score
			best_destination = destination

	if(!best_destination)
		return FALSE

	if(!brain.navigation.move_to_next_turf(best_destination))
		return FALSE

	brain.tied_controller.face_atom(threat)
	return TRUE
