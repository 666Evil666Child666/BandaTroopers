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
	grenade_module?.set_throwback_enabled(enabled)

/datum/human_ai_brain/proc/can_throw_grenades()
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	return grenade_module?.can_throw_grenades()

/datum/human_ai_brain/proc/set_grenade_throwing_enabled(enabled)
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	grenade_module?.set_throwing_enabled(enabled)

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
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	return grenade_module?.get_grenade_throw_target_turf()

/datum/human_ai_brain/proc/get_grenade_throw_source()
	RETURN_TYPE(/obj/item)
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	return grenade_module?.get_grenade_throw_source()

/datum/human_ai_brain/proc/can_attempt_grenade_throw(require_combat = TRUE, require_throw_source = TRUE)
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	if(!grenade_module)
		return FALSE
	return grenade_module.can_attempt_grenade_throw(require_combat, require_throw_source)

/datum/human_ai_brain/proc/get_active_throwback_grenade()
	RETURN_TYPE(/obj/item/explosive/grenade)
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	return grenade_module?.get_active_throwback_grenade()

/datum/human_ai_brain/proc/can_attempt_grenade_throwback(datum/human_tied_controller/controller, max_distance)
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	if(!grenade_module)
		return FALSE
	return grenade_module.can_attempt_grenade_throwback(controller, max_distance)
