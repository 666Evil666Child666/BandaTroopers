/datum/human_ai_module/grenade
	module_id = "grenade"
	required_module_types = list(
		/datum/human_ai_module/action_runtime,
		/datum/human_ai_module/combat,
		/datum/human_ai_module/inventory,
		/datum/human_ai_module/perception,
		/datum/human_ai_module/targeting,
	)
	/// A nearby found active grenade which AI will try and toss back
	var/obj/item/explosive/grenade/active_grenade_found
	/// If TRUE, may enter the grenade throw-back action from nearby live grenades.
	var/can_throw_back_grenades = TRUE // SS220 EDIT: equipment presets can opt weak HumanAI out of grenade throw-back
	/// Range in tiles for friendly proximity check when throwing grenades. Default 3. Override in presets.
	var/friendly_throw_check_range = 3 // SS220 EDIT: configurable friendly check range for grenade throws
	/// If TRUE, the AI will throw grenades at enemies who enter cover
	var/grenading_allowed = TRUE

/datum/human_ai_module/grenade/proc/reset_grenade()
	active_grenade_found = null // SS220 EDIT: reset stale grenade threat state so AI can leave throw-back mode cleanly

/datum/human_ai_module/grenade/reset_module()
	reset_grenade()

/datum/human_ai_module/grenade/suspend_module(clear_inventory = FALSE)
	reset_grenade()

/datum/human_ai_module/grenade/proc/get_active_grenade()
	RETURN_TYPE(/obj/item/explosive/grenade)
	return active_grenade_found

/datum/human_ai_module/grenade/proc/has_active_grenade()
	return active_grenade_found && !QDELETED(active_grenade_found)

/datum/human_ai_module/grenade/proc/set_active_grenade(obj/item/explosive/grenade/grenade)
	active_grenade_found = grenade

/datum/human_ai_module/grenade/proc/clear_active_grenade()
	active_grenade_found = null

/datum/human_ai_module/grenade/proc/can_throw_back()
	return can_throw_back_grenades

/datum/human_ai_module/grenade/proc/can_throw_grenades()
	return grenading_allowed

/datum/human_ai_module/grenade/proc/get_friendly_throw_check_range()
	return friendly_throw_check_range

/datum/human_ai_module/grenade/proc/has_throw_in_progress()
	if(!brain)
		return FALSE

	return brain.has_ongoing_throw_action_in_progress()

/datum/human_ai_module/grenade/proc/set_throwback_enabled(enabled)
	can_throw_back_grenades = enabled
	if(!enabled)
		clear_active_grenade()

/datum/human_ai_module/grenade/proc/set_throwing_enabled(enabled)
	grenading_allowed = enabled

/datum/human_ai_module/grenade/proc/get_grenade_throw_target_turf()
	RETURN_TYPE(/turf)
	return brain.get_shared_combat_target_turf() || brain.get_recent_projectile_threat_turf()

/datum/human_ai_module/grenade/proc/get_grenade_throw_source()
	RETURN_TYPE(/obj/item)
	return brain.find_grenade_for_throw()

/datum/human_ai_module/grenade/proc/can_attempt_grenade_throw(require_combat = TRUE, require_throw_source = TRUE)
	if(!can_throw_grenades())
		return FALSE
	if(require_combat && !brain.is_in_combat())
		return FALSE
	if(!get_grenade_throw_target_turf())
		return FALSE
	if(require_throw_source && !get_grenade_throw_source())
		return FALSE
	return TRUE

/datum/human_ai_module/grenade/proc/get_active_throwback_grenade()
	RETURN_TYPE(/obj/item/explosive/grenade)
	var/obj/item/explosive/grenade/active_grenade = get_active_grenade()
	if(QDELETED(active_grenade))
		return null
	return active_grenade

/datum/human_ai_module/grenade/proc/can_attempt_grenade_throwback(datum/human_tied_controller/controller, max_distance)
	if(!controller)
		return FALSE
	if(!can_throw_back())
		return FALSE
	var/obj/item/explosive/grenade/active_grenade = get_active_throwback_grenade()
	if(!active_grenade)
		return FALSE
	return controller.get_distance_to(active_grenade) <= max_distance
