// Human AI combat-facing API.
// These wrappers keep combat actions independent from the brain's internal module layout.

// ==================== Combat ====================
// Combat state transitions and shared combat state.
/datum/human_ai_brain/proc/is_in_combat()
	var/datum/human_ai_module/combat/combat_module = get_combat_module()
	return combat_module?.in_combat

/datum/human_ai_brain/proc/set_shot_at_turf(turf/target_turf)
	var/datum/human_ai_module/combat/combat_module = get_combat_module()
	if(combat_module)
		combat_module.shot_at = get_turf(target_turf)

/datum/human_ai_brain/proc/enter_combat()
	var/datum/human_ai_module/combat/combat_module = get_combat_module()
	return combat_module?.enter_combat()

/datum/human_ai_brain/proc/exit_combat()
	var/datum/human_ai_module/combat/combat_module = get_combat_module()
	return combat_module?.exit_combat()

// ==================== Cover ====================
// Cover reservation, entry, exit, and cover-search helpers.
/datum/human_ai_brain/proc/has_cover()
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	return cover_module?.has_cover()

/datum/human_ai_brain/proc/is_in_cover()
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	return cover_module?.is_in_cover()

/datum/human_ai_brain/proc/has_pending_cover()
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	if(!cover_module)
		return FALSE
	return cover_module.has_cover() && !cover_module.is_in_cover()

/datum/human_ai_brain/proc/get_current_cover()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	return cover_module?.get_current_cover()

/datum/human_ai_brain/proc/end_cover()
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	cover_module?.end_cover()

/datum/human_ai_brain/proc/enter_cover()
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	cover_module?.enter_cover()

/datum/human_ai_brain/proc/try_cover(angle = null, atom/source = null)
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	cover_module?.try_cover(angle, source)

/datum/human_ai_brain/proc/apply_cover_processing(list/turf_dict, from_squad = FALSE)
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	cover_module?.cover_processing(turf_dict, from_squad)

/datum/human_ai_brain/proc/start_cover_search_cooldown(cooldown)
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	if(!cover_module)
		return
	COOLDOWN_START(cover_module, cover_search_cooldown, cooldown)

/datum/human_ai_brain/proc/get_cover_destination()
	RETURN_TYPE(/turf)
	return get_current_cover()

/datum/human_ai_brain/proc/should_hold_cover_position_against_target(datum/human_tied_controller/controller, datum/human_ai_firearm_profile/gun_data = null)
	if(!is_in_cover())
		return FALSE
	var/atom/movable/current_target = get_current_target()
	if(!current_target || !controller)
		return FALSE
	return !(controller.get_distance_to(current_target) > gun_data?.minimum_range)

/datum/human_ai_brain/proc/can_attempt_cover_move(datum/human_tied_controller/controller, datum/human_ai_firearm_profile/gun_data = null)
	if(!has_valid_tied_human() || !controller)
		return FALSE
	if(!has_cover())
		return FALSE
	if(!can_move_for_action())
		return FALSE
	if(should_hold_cover_position_against_target(controller, gun_data))
		return FALSE
	return TRUE

/datum/human_ai_brain/proc/should_block_movement_for_pending_cover()
	return has_pending_cover()

/datum/human_ai_brain/proc/should_block_stationary_fire_for_cover()
	return has_cover()

// ==================== Grenade ====================
// Grenade capabilities, active live grenade tracking, and throw state.
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

// ==================== Throwables ====================
// Throwable readiness helpers. Throwable handlers still own priming, trajectory, and async throw mechanics.
/datum/human_ai_brain/proc/get_grenade_throw_target_turf()
	RETURN_TYPE(/turf)
	return get_target_turf()

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

// ==================== Melee ====================
// Melee readiness and execution helpers. The melee module still owns target stepping and hit logic.
/datum/human_ai_brain/proc/can_attempt_melee()
	var/datum/human_ai_module/melee/melee_module = get_melee_module()
	return melee_module?.can_try_melee()

/datum/human_ai_brain/proc/get_melee_weight()
	var/datum/human_ai_module/melee/melee_module = get_melee_module()
	return melee_module?.get_melee_weight() || 0

/datum/human_ai_brain/proc/should_continue_melee()
	var/datum/human_ai_module/melee/melee_module = get_melee_module()
	return melee_module?.should_continue_melee()

/datum/human_ai_brain/proc/run_melee_step()
	var/datum/human_ai_module/melee/melee_module = get_melee_module()
	return melee_module?.run_melee_step()

// ==================== Guns ====================
// Ranged weapon reload/fire cooldown state.
/datum/human_ai_brain/proc/has_tried_reload()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	return guns_module?.has_tried_reload()

/datum/human_ai_brain/proc/mark_tried_reload()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	guns_module?.mark_tried_reload()

/datum/human_ai_brain/proc/set_tried_reload(new_value)
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	if(!guns_module)
		return
	if(new_value)
		guns_module.mark_tried_reload()
	else
		guns_module.clear_tried_reload()

/datum/human_ai_brain/proc/should_reload()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	return guns_module?.should_reload()

/datum/human_ai_brain/proc/can_start_fire()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	if(!guns_module)
		return FALSE
	return COOLDOWN_FINISHED(guns_module, stop_fire_cooldown)

/datum/human_ai_brain/proc/start_stop_fire_cooldown(cooldown)
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	if(!guns_module)
		return
	COOLDOWN_START(guns_module, stop_fire_cooldown, cooldown)

/datum/human_ai_brain/proc/can_continue_fire_burst()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	if(!guns_module)
		return FALSE
	return COOLDOWN_FINISHED(guns_module, fire_overload_cooldown)

/datum/human_ai_brain/proc/start_fire_overload_cooldown()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	if(!guns_module || !profile_module)
		return

	var/short_action_delay = profile_module.short_action_delay
	COOLDOWN_START(guns_module, fire_overload_cooldown, max(short_action_delay, short_action_delay * profile_module.action_delay_mult))

/datum/human_ai_brain/proc/clear_tried_reload()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	guns_module?.clear_tried_reload()

/datum/human_ai_brain/proc/can_use_ranged_weapon()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	return guns_module && !guns_module.has_tried_reload() && (has_primary_weapon() || has_secondary_weapons())

// ==================== Ranged Fire ====================
// Higher-level ranged-fire readiness helpers. Firing actions still own line checks and firearm handler side effects.
/datum/human_ai_brain/proc/get_ranged_fire_target_turf(datum/human_ai_firearm_profile/gun_data = null)
	RETURN_TYPE(/turf)
	var/turf/target_turf = get_target_turf()
	if(has_current_target() || can_fire_offscreen(target_turf, gun_data))
		return target_turf
	return null

/datum/human_ai_brain/proc/can_reach_ranged_fire_target(datum/human_tied_controller/controller, turf/target_turf, maximum_range = null, datum/human_ai_firearm_profile/gun_data = null)
	if(!controller || !target_turf)
		return FALSE
	if(can_fire_offscreen(target_turf, gun_data))
		return TRUE
	if(isnull(maximum_range))
		maximum_range = get_view_distance()
	return controller.get_distance_to(target_turf) <= maximum_range

/datum/human_ai_brain/proc/can_reach_ranged_fire_atom(datum/human_tied_controller/controller, atom/target, maximum_range = null, datum/human_ai_firearm_profile/gun_data = null)
	if(!target)
		return FALSE
	return can_reach_ranged_fire_target(controller, get_turf(target), maximum_range, gun_data)

/datum/human_ai_brain/proc/should_block_ranged_fire_for_throwable()
	return has_active_grenade()

/datum/human_ai_brain/proc/should_defer_ranged_fire_target(atom/threat = null)
	return should_defer_ranged_fire(threat)

/datum/human_ai_brain/proc/should_defer_current_ranged_fire()
	return should_defer_ranged_fire_target(get_aim_target())

/datum/human_ai_brain/proc/can_attempt_ranged_fire(datum/human_tied_controller/controller, obj/item/weapon/gun/primary_weapon, datum/human_ai_firearm_profile/gun_data = null, require_combat = TRUE, block_active_grenade = FALSE, check_view_distance = TRUE, check_reload = TRUE, check_tried_reload = TRUE)
	if(!has_valid_tied_human())
		return FALSE
	if(require_combat && !is_in_combat())
		return FALSE
	if(check_tried_reload && has_tried_reload())
		return FALSE
	if(!primary_weapon)
		return FALSE
	if(block_active_grenade && should_block_ranged_fire_for_throwable())
		return FALSE
	if(!can_start_fire())
		return FALSE

	var/turf/target_turf = get_ranged_fire_target_turf(gun_data)
	if(!target_turf)
		return FALSE
	if(check_view_distance && !can_reach_ranged_fire_target(controller, target_turf, get_view_distance(), gun_data))
		return FALSE
	if(should_defer_current_ranged_fire())
		return FALSE
	if(check_reload && should_reload())
		return FALSE
	return TRUE

// ==================== Targeting ====================
// Current target, target turf, aiming, and offscreen-fire targeting state.
/datum/human_ai_brain/proc/get_current_target()
	RETURN_TYPE(/atom/movable)
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.get_current_target()

/datum/human_ai_brain/proc/get_aim_target()
	RETURN_TYPE(/atom)
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.get_aim_target()

/datum/human_ai_brain/proc/has_current_target()
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.has_current_target()

/datum/human_ai_brain/proc/can_target(atom/movable/target)
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.can_target(target)

/datum/human_ai_brain/proc/get_target_turf()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.get_target_turf()

/datum/human_ai_brain/proc/has_target_turf()
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.has_target_turf()

/datum/human_ai_brain/proc/has_offscreen_fire_target()
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.has_target_turf() && !COOLDOWN_FINISHED(targeting_module, fire_offscreen)

/datum/human_ai_brain/proc/can_fire_offscreen(turf/target_turf, datum/human_ai_firearm_profile/gun_data = null)
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	if(!targeting_module || !target_turf || COOLDOWN_FINISHED(targeting_module, fire_offscreen))
		return FALSE
	if(!gun_data)
		return TRUE
	return gun_data.maximum_range > get_view_distance()

/datum/human_ai_brain/proc/lose_target()
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	targeting_module?.lose_target()

/datum/human_ai_brain/proc/clear_target_turf()
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	targeting_module?.clear_target_turf()

/datum/human_ai_brain/proc/set_target_turf_direct(turf/new_target_turf)
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	targeting_module?.set_target_turf_direct(new_target_turf)
