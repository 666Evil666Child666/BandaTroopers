// Human AI grenade and throwable API.
// Throwable handlers still own priming, trajectory, and async throw mechanics.

/datum/human_ai_brain/proc/has_active_grenade()
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	return grenade_module?.has_active_grenade()

/datum/human_ai_brain/proc/get_active_grenade()
	RETURN_TYPE(/obj/item/explosive/grenade)
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	return grenade_module?.get_active_grenade()

/datum/human_ai_brain/proc/set_active_grenade(obj/item/explosive/grenade/new_grenade)
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	grenade_module?.set_active_grenade(new_grenade)

/datum/human_ai_brain/proc/clear_active_grenade()
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	grenade_module?.clear_active_grenade()

/datum/human_ai_brain/proc/set_grenade_throwback_enabled(enabled)
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	if(!grenade_module)
		return
	grenade_module.can_throw_back_grenades = enabled
	if(!enabled)
		grenade_module.clear_active_grenade()

/datum/human_ai_brain/proc/can_throw_grenades()
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	return grenade_module?.can_throw_grenades()

/datum/human_ai_brain/proc/set_grenade_throwing_enabled(enabled)
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	if(!grenade_module)
		return
	grenade_module.grenading_allowed = enabled

/datum/human_ai_brain/proc/can_throw_back_grenade()
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	return grenade_module?.can_throw_back()

/datum/human_ai_brain/proc/get_friendly_throw_check_range()
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	return grenade_module?.get_friendly_throw_check_range() || 0

/datum/human_ai_brain/proc/has_throw_in_progress()
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	return grenade_module?.has_throw_in_progress()

/datum/human_ai_brain/proc/get_grenade_throw_target_turf()
	RETURN_TYPE(/turf)
	return get_shared_combat_target_turf() || get_recent_projectile_threat_turf()

/datum/human_ai_brain/proc/get_grenade_throw_source()
	RETURN_TYPE(/obj/item)
	return find_grenade_for_throw()

/datum/human_ai_brain/proc/can_attempt_grenade_throw(require_combat = TRUE, require_throw_source = TRUE)
	if(!can_throw_grenades())
		return FALSE
	if(require_combat && !is_in_combat())
		return FALSE
	if(!get_grenade_throw_target_turf())
		return FALSE
	if(require_throw_source && !get_grenade_throw_source())
		return FALSE
	return TRUE

/datum/human_ai_brain/proc/get_active_throwback_grenade()
	RETURN_TYPE(/obj/item/explosive/grenade)
	var/obj/item/explosive/grenade/active_grenade = get_active_grenade()
	if(QDELETED(active_grenade))
		return null
	return active_grenade

/datum/human_ai_brain/proc/can_attempt_grenade_throwback(datum/human_tied_controller/controller, max_distance)
	if(!controller)
		return FALSE
	if(!can_throw_back_grenade())
		return FALSE
	var/obj/item/explosive/grenade/active_grenade = get_active_throwback_grenade()
	if(!active_grenade)
		return FALSE
	return controller.get_distance_to(active_grenade) <= max_distance
