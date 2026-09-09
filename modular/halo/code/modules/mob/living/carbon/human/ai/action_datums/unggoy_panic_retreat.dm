/datum/ai_action/unggoy_panic_retreat
	name = "Паническое отступление унггоя"
	action_flags = ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/targeting, /datum/human_ai_module/navigation, /datum/human_ai_module/squad)

/datum/ai_action/unggoy_panic_retreat/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	if(!brain?.halo_unggoy_runtime)
		return 0

	if(!brain.halo_covenant_can_run_movement_action())
		return 0

	if(!brain.halo_unggoy_should_retreat())
		return 0

	if(!brain.halo_covenant_get_threat_atom())
		return 0

	return 25

/datum/ai_action/unggoy_panic_retreat/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	if(!brain || !brain.halo_unggoy_runtime || !brain.halo_covenant_can_run_movement_action() || !brain.halo_unggoy_should_retreat())
		return ONGOING_ACTION_COMPLETED

	var/atom/threat = brain.halo_covenant_get_threat_atom()
	if(!brain.has_valid_tied_human() || !threat)
		return ONGOING_ACTION_COMPLETED

	if(brain.halo_unggoy_should_use_cover_retreat() && try_cover_retreat(threat))
		return ONGOING_ACTION_UNFINISHED_BLOCK

	if(!brain.halo_unggoy_should_use_cover_retreat() && brain.halo_covenant_has_cover())
		brain.halo_covenant_end_cover()

	if(step_away_from_threat(threat))
		return ONGOING_ACTION_UNFINISHED_BLOCK

	return ONGOING_ACTION_COMPLETED

/datum/ai_action/unggoy_panic_retreat/proc/try_cover_retreat(atom/threat)
	var/datum/human_ai_brain/brain = context?.brain
	if(!brain)
		return FALSE

	return brain.halo_covenant_try_cover_retreat(threat)

/datum/ai_action/unggoy_panic_retreat/proc/step_away_from_threat(atom/threat)
	var/datum/human_ai_brain/brain = context?.brain
	if(!brain)
		return FALSE

	var/keep_anchor = !brain.halo_unggoy_should_flee_on_overheat()
	var/turf/anchor = keep_anchor ? brain.halo_unggoy_get_squad_anchor() : null
	return brain.halo_covenant_step_away_from_threat(threat, anchor, 1)
