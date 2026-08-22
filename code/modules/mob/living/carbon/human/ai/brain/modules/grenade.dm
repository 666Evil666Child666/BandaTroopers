/datum/human_ai_module/grenade
	/// A nearby found active grenade which AI will try and toss back
	var/obj/item/explosive/grenade/active_grenade_found
	/// If TRUE, may enter the grenade throw-back action from nearby live grenades.
	var/can_throw_back_grenades = TRUE // SS220 EDIT: modular HALO presets can opt weak HumanAI out of grenade throw-back
	/// Range in tiles for friendly proximity check when throwing grenades. Default 3. Override in HALO presets.
	var/friendly_throw_check_range = 3 // SS220 EDIT: configurable friendly check range for grenade throws
	/// If TRUE, the AI will throw grenades at enemies who enter cover
	var/grenading_allowed = TRUE

/datum/human_ai_module/grenade/proc/reset_grenade()
	active_grenade_found = null // SS220 EDIT: reset stale grenade threat state so AI can leave throw-back mode cleanly

/datum/human_ai_module/grenade/proc/has_throw_in_progress()
	if(!brain)
		return FALSE

	for(var/datum/ai_action/ongoing_action as anything in brain.action_runtime.ongoing_actions)
		if(istype(ongoing_action, /datum/ai_action/throw_grenade))
			var/datum/ai_action/throw_grenade/throw_grenade_action = ongoing_action
			if(throw_grenade_action.mid_throw)
				return TRUE

		if(istype(ongoing_action, /datum/ai_action/throw_back_nade))
			var/datum/ai_action/throw_back_nade/throw_back_action = ongoing_action
			if(throw_back_action.mid_throw)
				return TRUE

	return FALSE
