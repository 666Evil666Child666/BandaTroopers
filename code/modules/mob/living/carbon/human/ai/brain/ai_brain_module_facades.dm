// Human AI module-facing facade procs.
// These wrappers are grouped by the module/theme they expose so callers do not need to know the brain's internal module layout.

// ==================== Modules ====================
// Generic lookup helpers for partial module compositions.
/datum/human_ai_brain/proc/get_module(module_type)
	if(!module_config)
		return null
	return module_config.get_module_by_type(src, module_type)

/datum/human_ai_brain/proc/has_module(module_type)
	return !!get_module(module_type)

/datum/human_ai_brain/proc/get_module_by_id(module_id)
	return module_config?.get_module_by_id(module_id)

/datum/human_ai_brain/proc/create_context()
	return new /datum/human_ai_context(src)

// ==================== Action runtime ====================
// Action queue, action blacklists, and currently running action state.
/datum/human_ai_brain/proc/cancel_ongoing_actions_by_type(list/action_types, datum/ai_action/except_action = null)
	if(!length(action_types) || !action_runtime)
		return

	for(var/datum/ai_action/ongoing_action as anything in action_runtime.ongoing_actions)
		if((ongoing_action != except_action) && (ongoing_action.type in action_types))
			qdel(ongoing_action)

/datum/human_ai_brain/proc/remove_ongoing_action(datum/ai_action/action)
	if(action_runtime)
		action_runtime.ongoing_actions -= action

/datum/human_ai_brain/proc/has_ongoing_action(action_type)
	return action_runtime?.has_ongoing_action(action_type)

/datum/human_ai_brain/proc/add_action_blacklist(list/action_types)
	if(!length(action_types) || !action_runtime)
		return
	if(!action_runtime.action_blacklist)
		action_runtime.action_blacklist = list()
	for(var/action_type as anything in action_types)
		action_runtime.action_blacklist |= action_type

/datum/human_ai_brain/proc/remove_action_blacklist(list/action_types)
	if(!length(action_types) || !action_runtime?.action_blacklist)
		return
	for(var/action_type as anything in action_types)
		action_runtime.action_blacklist -= action_type
	if(!length(action_runtime.action_blacklist))
		action_runtime.action_blacklist = null

/datum/human_ai_brain/proc/has_ongoing_throw_action_in_progress()
	if(!action_runtime)
		return FALSE
	for(var/datum/ai_action/ongoing_action as anything in action_runtime.ongoing_actions)
		if(istype(ongoing_action, /datum/ai_action/throw_grenade))
			var/datum/ai_action/throw_grenade/throw_grenade_action = ongoing_action
			if(throw_grenade_action.mid_throw)
				return TRUE

		if(istype(ongoing_action, /datum/ai_action/throw_back_nade))
			var/datum/ai_action/throw_back_nade/throw_back_action = ongoing_action
			if(throw_back_action.mid_throw)
				return TRUE

	return FALSE

// ==================== Combat ====================
// Combat state transitions and shared combat state.
/datum/human_ai_brain/proc/is_in_combat()
	return combat?.in_combat

/datum/human_ai_brain/proc/set_shot_at_turf(turf/target_turf)
	if(combat)
		combat.shot_at = get_turf(target_turf)

/datum/human_ai_brain/proc/enter_combat()
	return combat?.enter_combat()

/datum/human_ai_brain/proc/exit_combat()
	return combat?.exit_combat()

// ==================== Communication ====================
// Voice lines and squad/combat communication hooks.
/datum/human_ai_brain/proc/get_reload_line_chance()
	return communication?.reload_line_chance || 0

/datum/human_ai_brain/proc/set_reload_line_chance(new_chance)
	if(communication)
		communication.reload_line_chance = new_chance

/datum/human_ai_brain/proc/say_reload_line()
	communication?.say_reload_line()

/datum/human_ai_brain/proc/say_grenade_thrown_line()
	communication?.say_grenade_thrown_line()

/datum/human_ai_brain/proc/on_squad_member_death(mob/living/carbon/human/dead_mob)
	communication?.on_squad_member_death(dead_mob)

// ==================== Conversation ====================
// Idle conversation participation checks.
/datum/human_ai_brain/proc/can_try_start_conversation()
	return conversation?.can_try_start()

/datum/human_ai_brain/proc/can_participate_in_conversation()
	return conversation?.can_participate()

// ==================== Cover ====================
// Cover reservation, entry, exit, and cover-search helpers.
/datum/human_ai_brain/proc/has_cover()
	return cover?.has_cover()

/datum/human_ai_brain/proc/is_in_cover()
	return cover?.is_in_cover()

/datum/human_ai_brain/proc/has_pending_cover()
	if(!cover)
		return FALSE
	return cover.has_cover() && !cover.is_in_cover()

/datum/human_ai_brain/proc/get_current_cover()
	RETURN_TYPE(/turf)
	return cover?.get_current_cover()

/datum/human_ai_brain/proc/end_cover()
	cover?.end_cover()

/datum/human_ai_brain/proc/enter_cover()
	cover?.enter_cover()

/datum/human_ai_brain/proc/try_cover(angle = null, atom/source = null)
	cover?.try_cover(angle, source)

/datum/human_ai_brain/proc/apply_cover_processing(list/turf_dict, from_squad = FALSE)
	cover?.cover_processing(turf_dict, from_squad)

/datum/human_ai_brain/proc/start_cover_search_cooldown(cooldown)
	if(!cover)
		return
	COOLDOWN_START(cover, cover_search_cooldown, cooldown)

// ==================== Emplacement ====================
// Stationary sniper and machinegunner home positions.
/datum/human_ai_brain/proc/has_sniper_home()
	return emplacement?.has_sniper_home()

/datum/human_ai_brain/proc/set_sniper_home(turf/home, new_dir = SOUTH)
	emplacement?.set_sniper_home(home, new_dir)

/datum/human_ai_brain/proc/get_sniper_home()
	RETURN_TYPE(/turf)
	return emplacement?.sniper_home

/datum/human_ai_brain/proc/get_sniper_dir()
	return emplacement?.sniper_dir

/datum/human_ai_brain/proc/has_machinegunner_home()
	return emplacement?.has_machinegunner_home()

/datum/human_ai_brain/proc/set_machinegunner_home(turf/home, new_dir = SOUTH)
	emplacement?.set_machinegunner_home(home, new_dir)

/datum/human_ai_brain/proc/get_machinegunner_home()
	RETURN_TYPE(/turf)
	return emplacement?.machinegunner_home

/datum/human_ai_brain/proc/get_machinegunner_dir()
	return emplacement?.machinegunner_dir

/datum/human_ai_brain/proc/is_stationary_fire_blocked()
	return guns?.has_tried_reload() || cover?.has_cover() || health?.healing_someone

// ==================== Faction ====================
// Friendly/hostile checks and faction memory.
/datum/human_ai_brain/proc/is_friendly_target(atom/target)
	return faction?.faction_check(target)

/datum/human_ai_brain/proc/get_previous_faction()
	return faction?.previous_faction

/datum/human_ai_brain/proc/set_previous_faction(new_faction)
	if(faction)
		faction.previous_faction = new_faction

// ==================== Grenade ====================
// Grenade capabilities, active live grenade tracking, and throw state.
/datum/human_ai_brain/proc/has_active_grenade()
	return grenade?.has_active_grenade()

/datum/human_ai_brain/proc/get_active_grenade()
	RETURN_TYPE(/obj/item/explosive/grenade)
	return grenade?.get_active_grenade()

/datum/human_ai_brain/proc/set_active_grenade(obj/item/explosive/grenade/new_grenade)
	grenade?.set_active_grenade(new_grenade)

/datum/human_ai_brain/proc/clear_active_grenade()
	grenade?.clear_active_grenade()

/datum/human_ai_brain/proc/set_grenade_throwback_enabled(enabled)
	if(!grenade)
		return
	grenade.can_throw_back_grenades = enabled
	if(!enabled)
		grenade.clear_active_grenade()

/datum/human_ai_brain/proc/can_throw_grenades()
	return grenade?.can_throw_grenades()

/datum/human_ai_brain/proc/set_grenade_throwing_enabled(enabled)
	if(!grenade)
		return
	grenade.grenading_allowed = enabled

/datum/human_ai_brain/proc/can_throw_back_grenade()
	return grenade?.can_throw_back()

/datum/human_ai_brain/proc/get_friendly_throw_check_range()
	return grenade?.get_friendly_throw_check_range() || 0

/datum/human_ai_brain/proc/find_grenade_for_throw()
	RETURN_TYPE(/obj/item/explosive/grenade)
	return inventory?.find_grenade_for_throw()

/datum/human_ai_brain/proc/has_throw_in_progress()
	return grenade?.has_throw_in_progress()

// ==================== Guns ====================
// Ranged weapon reload/fire cooldown state.
/datum/human_ai_brain/proc/has_tried_reload()
	return guns?.has_tried_reload()

/datum/human_ai_brain/proc/mark_tried_reload()
	guns?.mark_tried_reload()

/datum/human_ai_brain/proc/set_tried_reload(new_value)
	if(!guns)
		return
	if(new_value)
		guns.mark_tried_reload()
	else
		guns.clear_tried_reload()

/datum/human_ai_brain/proc/should_reload()
	return guns?.should_reload()

/datum/human_ai_brain/proc/can_start_fire()
	if(!guns)
		return FALSE
	return COOLDOWN_FINISHED(guns, stop_fire_cooldown)

/datum/human_ai_brain/proc/start_stop_fire_cooldown(cooldown)
	if(!guns)
		return
	COOLDOWN_START(guns, stop_fire_cooldown, cooldown)

/datum/human_ai_brain/proc/can_continue_fire_burst()
	if(!guns)
		return FALSE
	return COOLDOWN_FINISHED(guns, fire_overload_cooldown)

/datum/human_ai_brain/proc/start_fire_overload_cooldown()
	if(!guns || !profile)
		return

	var/short_action_delay = profile.short_action_delay
	COOLDOWN_START(guns, fire_overload_cooldown, max(short_action_delay, short_action_delay * profile.action_delay_mult))

/datum/human_ai_brain/proc/clear_tried_reload()
	guns?.clear_tried_reload()

/datum/human_ai_brain/proc/can_use_ranged_weapon()
	var/datum/human_ai_context/context = create_context()
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	var/can_use_weapon = guns && !guns.has_tried_reload() && (inventory?.has_primary_weapon() || inventory?.has_secondary_weapons())
	qdel(context)
	return can_use_weapon

// ==================== Health ====================
// Treatment state and self-treatment retry helpers.
/datum/human_ai_brain/proc/is_healing_someone()
	return health?.healing_someone

/datum/human_ai_brain/proc/can_retry_self_treatment()
	return health && (health.cant_be_treated_stacks < health.treatment_stack_threshold)

/datum/human_ai_brain/proc/cancel_treatment()
	health?.cancel_treatment()

/datum/human_ai_brain/proc/increment_treatment_stacks()
	health?.increment_treatment_stacks()

// ==================== Navigation ====================
// Movement requests and pathing profile knobs.
/datum/human_ai_brain/proc/move_to_turf(turf/destination)
	return navigation?.move_to_next_turf(destination)

/datum/human_ai_brain/proc/move_to_atom(atom/target)
	if(!target)
		return FALSE
	return navigation?.move_to_next_turf(get_turf(target))

/datum/human_ai_brain/proc/apply_navigation_profile(short_step_range = 0, path_retarget_slack = 0)
	if(!navigation)
		return
	if(short_step_range > 0)
		navigation.short_step_pathing_range = max(navigation.short_step_pathing_range, short_step_range)
	if(path_retarget_slack > 0)
		navigation.path_target_retarget_slack = max(navigation.path_target_retarget_slack, path_retarget_slack)

// ==================== Orders ====================
// Order-gated movement and quick-approach transient state.
/datum/human_ai_brain/proc/can_move_for_action()
	return !orders || orders.can_move_for_action()

/datum/human_ai_brain/proc/get_quick_approach_turf()
	RETURN_TYPE(/turf)
	return orders?.quick_approach

/datum/human_ai_brain/proc/clear_quick_approach()
	orders?.clear_quick_approach()

/datum/human_ai_brain/proc/set_quick_approach(turf/new_turf)
	orders?.set_quick_approach(new_turf)

/datum/human_ai_brain/proc/set_hold_position(new_value)
	orders?.set_hold_position(new_value)

// ==================== Profile ====================
// Generic timing, vision, and combat profile values.
/datum/human_ai_brain/proc/get_targeting_view_distance()
	return profile?.view_distance || 0

/datum/human_ai_brain/proc/has_scope_vision()
	return profile?.scope_vision

/datum/human_ai_brain/proc/should_shoot_to_kill()
	return profile?.shoot_to_kill

/datum/human_ai_brain/proc/get_view_distance()
	return profile?.view_distance || 0

/datum/human_ai_brain/proc/set_view_distance(new_view_distance)
	if(profile)
		profile.view_distance = new_view_distance

/datum/human_ai_brain/proc/get_action_delay()
	if(!profile)
		return 0
	return profile.short_action_delay * profile.action_delay_mult

/datum/human_ai_brain/proc/get_micro_action_delay()
	if(!profile)
		return 0
	return profile.micro_action_delay * profile.action_delay_mult

// ==================== Squad ====================
// Squad membership, leader lookup, and current order glue.
/datum/human_ai_brain/proc/is_squad_leader()
	return squad?.is_squad_leader

/datum/human_ai_brain/proc/set_squad_leader_status(is_leader)
	if(squad)
		squad.is_squad_leader = is_leader

/datum/human_ai_brain/proc/get_squad_id()
	return squad?.squad_id

/datum/human_ai_brain/proc/has_squad()
	return !!get_squad_id()

/datum/human_ai_brain/proc/set_squad_id(new_squad_id)
	if(squad)
		squad.squad_id = new_squad_id

/datum/human_ai_brain/proc/can_assign_squad()
	return squad?.can_assign_squad

/datum/human_ai_brain/proc/add_to_squad(new_squad_id)
	return squad?.add_to_squad(new_squad_id)

/datum/human_ai_brain/proc/get_squad_datum()
	RETURN_TYPE(/datum/human_ai_squad)
	if(!squad?.squad_id)
		return null
	return SShuman_ai.squad_id_dict["[squad.squad_id]"]

/datum/human_ai_brain/proc/get_squad_leader()
	RETURN_TYPE(/datum/human_ai_brain)
	var/datum/human_ai_squad/squad_datum = get_squad_datum()
	return squad_datum?.squad_leader

/datum/human_ai_brain/proc/get_squad_members()
	var/datum/human_ai_squad/squad_datum = get_squad_datum()
	return squad_datum?.ai_in_squad || list()

/datum/human_ai_brain/proc/get_current_order()
	return squad?.current_order

/datum/human_ai_brain/proc/remove_current_order()
	squad?.remove_current_order()

/datum/human_ai_brain/proc/set_current_order(datum/ai_order/order)
	squad?.set_current_order(order)

// ==================== Targeting ====================
// Current target, target turf, aiming, and offscreen-fire targeting state.
/datum/human_ai_brain/proc/get_current_target()
	RETURN_TYPE(/atom/movable)
	return targeting?.get_current_target()

/datum/human_ai_brain/proc/get_aim_target()
	RETURN_TYPE(/atom)
	return targeting?.get_aim_target()

/datum/human_ai_brain/proc/has_current_target()
	return targeting?.has_current_target()

/datum/human_ai_brain/proc/can_target(atom/movable/target)
	return targeting?.can_target(target)

/datum/human_ai_brain/proc/get_target_turf()
	RETURN_TYPE(/turf)
	return targeting?.get_target_turf()

/datum/human_ai_brain/proc/has_target_turf()
	return targeting?.has_target_turf()

/datum/human_ai_brain/proc/has_offscreen_fire_target()
	return targeting?.has_target_turf() && !COOLDOWN_FINISHED(src, targeting.fire_offscreen)

/datum/human_ai_brain/proc/can_fire_offscreen(turf/target_turf, datum/human_ai_firearm_profile/gun_data = null)
	if(!targeting || !target_turf || COOLDOWN_FINISHED(src, targeting.fire_offscreen))
		return FALSE
	if(!gun_data)
		return TRUE
	return gun_data.maximum_range > get_view_distance()

/datum/human_ai_brain/proc/lose_target()
	targeting?.lose_target()

/datum/human_ai_brain/proc/clear_target_turf()
	targeting?.clear_target_turf()

/datum/human_ai_brain/proc/set_target_turf_direct(turf/new_target_turf)
	targeting?.set_target_turf_direct(new_target_turf)
