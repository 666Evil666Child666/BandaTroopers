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

/datum/human_ai_brain/proc/get_action_runtime_module()
	RETURN_TYPE(/datum/human_ai_module/action_runtime)
	return get_module(/datum/human_ai_module/action_runtime)

/datum/human_ai_brain/proc/get_admin_module()
	RETURN_TYPE(/datum/human_ai_module/admin)
	return get_module(/datum/human_ai_module/admin)

/datum/human_ai_brain/proc/get_combat_module()
	RETURN_TYPE(/datum/human_ai_module/combat)
	return get_module(/datum/human_ai_module/combat)

/datum/human_ai_brain/proc/get_communication_module()
	RETURN_TYPE(/datum/human_ai_module/communication)
	return get_module(/datum/human_ai_module/communication)

/datum/human_ai_brain/proc/get_conversation_module()
	RETURN_TYPE(/datum/human_ai_module/conversation)
	return get_module(/datum/human_ai_module/conversation)

/datum/human_ai_brain/proc/get_cover_module()
	RETURN_TYPE(/datum/human_ai_module/cover)
	return get_module(/datum/human_ai_module/cover)

/datum/human_ai_brain/proc/get_emplacement_module()
	RETURN_TYPE(/datum/human_ai_module/emplacement)
	return get_module(/datum/human_ai_module/emplacement)

/datum/human_ai_brain/proc/get_faction_module()
	RETURN_TYPE(/datum/human_ai_module/faction)
	return get_module(/datum/human_ai_module/faction)

/datum/human_ai_brain/proc/get_grenade_module()
	RETURN_TYPE(/datum/human_ai_module/grenade)
	return get_module(/datum/human_ai_module/grenade)

/datum/human_ai_brain/proc/get_guns_module()
	RETURN_TYPE(/datum/human_ai_module/guns)
	return get_module(/datum/human_ai_module/guns)

/datum/human_ai_brain/proc/get_health_module()
	RETURN_TYPE(/datum/human_ai_module/health)
	return get_module(/datum/human_ai_module/health)

/datum/human_ai_brain/proc/get_inventory_module()
	RETURN_TYPE(/datum/human_ai_module/inventory)
	return get_module(/datum/human_ai_module/inventory)

/datum/human_ai_brain/proc/get_melee_module()
	RETURN_TYPE(/datum/human_ai_module/melee)
	return get_module(/datum/human_ai_module/melee)

/datum/human_ai_brain/proc/get_navigation_module()
	RETURN_TYPE(/datum/human_ai_module/navigation)
	return get_module(/datum/human_ai_module/navigation)

/datum/human_ai_brain/proc/get_orders_module()
	RETURN_TYPE(/datum/human_ai_module/orders)
	return get_module(/datum/human_ai_module/orders)

/datum/human_ai_brain/proc/get_perception_module()
	RETURN_TYPE(/datum/human_ai_module/perception)
	return get_module(/datum/human_ai_module/perception)

/datum/human_ai_brain/proc/get_profile_module()
	RETURN_TYPE(/datum/human_ai_module/profile)
	return get_module(/datum/human_ai_module/profile)

/datum/human_ai_brain/proc/get_squad_module()
	RETURN_TYPE(/datum/human_ai_module/squad)
	return get_module(/datum/human_ai_module/squad)

/datum/human_ai_brain/proc/get_targeting_module()
	RETURN_TYPE(/datum/human_ai_module/targeting)
	return get_module(/datum/human_ai_module/targeting)

/datum/human_ai_brain/proc/create_context()
	return new /datum/human_ai_context(src)

// ==================== Action runtime ====================
// Action queue, action blacklists, and currently running action state.
/datum/human_ai_brain/proc/cancel_ongoing_actions_by_type(list/action_types, datum/ai_action/except_action = null)
	var/datum/human_ai_module/action_runtime/action_runtime_module = get_action_runtime_module()
	if(!length(action_types) || !action_runtime_module)
		return

	for(var/datum/ai_action/ongoing_action as anything in action_runtime_module.ongoing_actions)
		if((ongoing_action != except_action) && (ongoing_action.type in action_types))
			qdel(ongoing_action)

/datum/human_ai_brain/proc/remove_ongoing_action(datum/ai_action/action)
	var/datum/human_ai_module/action_runtime/action_runtime_module = get_action_runtime_module()
	if(action_runtime_module)
		action_runtime_module.ongoing_actions -= action

/datum/human_ai_brain/proc/has_ongoing_action(action_type)
	var/datum/human_ai_module/action_runtime/action_runtime_module = get_action_runtime_module()
	return action_runtime_module?.has_ongoing_action(action_type)

/datum/human_ai_brain/proc/add_action_blacklist(list/action_types)
	var/datum/human_ai_module/action_runtime/action_runtime_module = get_action_runtime_module()
	if(!length(action_types) || !action_runtime_module)
		return
	if(!action_runtime_module.action_blacklist)
		action_runtime_module.action_blacklist = list()
	for(var/action_type as anything in action_types)
		action_runtime_module.action_blacklist |= action_type

/datum/human_ai_brain/proc/remove_action_blacklist(list/action_types)
	var/datum/human_ai_module/action_runtime/action_runtime_module = get_action_runtime_module()
	if(!length(action_types) || !action_runtime_module?.action_blacklist)
		return
	for(var/action_type as anything in action_types)
		action_runtime_module.action_blacklist -= action_type
	if(!length(action_runtime_module.action_blacklist))
		action_runtime_module.action_blacklist = null

/datum/human_ai_brain/proc/has_ongoing_throw_action_in_progress()
	var/datum/human_ai_module/action_runtime/action_runtime_module = get_action_runtime_module()
	if(!action_runtime_module)
		return FALSE
	for(var/datum/ai_action/ongoing_action as anything in action_runtime_module.ongoing_actions)
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

// ==================== Communication ====================
// Voice lines and squad/combat communication hooks.
/datum/human_ai_brain/proc/get_reload_line_chance()
	var/datum/human_ai_module/communication/communication_module = get_communication_module()
	return communication_module?.reload_line_chance || 0

/datum/human_ai_brain/proc/set_reload_line_chance(new_chance)
	var/datum/human_ai_module/communication/communication_module = get_communication_module()
	if(communication_module)
		communication_module.reload_line_chance = new_chance

/datum/human_ai_brain/proc/say_reload_line()
	var/datum/human_ai_module/communication/communication_module = get_communication_module()
	communication_module?.say_reload_line()

/datum/human_ai_brain/proc/say_grenade_thrown_line()
	var/datum/human_ai_module/communication/communication_module = get_communication_module()
	communication_module?.say_grenade_thrown_line()

/datum/human_ai_brain/proc/on_squad_member_death(mob/living/carbon/human/dead_mob)
	var/datum/human_ai_module/communication/communication_module = get_communication_module()
	communication_module?.on_squad_member_death(dead_mob)

// ==================== Conversation ====================
// Idle conversation participation checks.
/datum/human_ai_brain/proc/can_try_start_conversation()
	var/datum/human_ai_module/conversation/conversation_module = get_conversation_module()
	return conversation_module?.can_try_start()

/datum/human_ai_brain/proc/can_participate_in_conversation()
	var/datum/human_ai_module/conversation/conversation_module = get_conversation_module()
	return conversation_module?.can_participate()

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

// ==================== Emplacement ====================
// Stationary sniper and machinegunner home positions.
/datum/human_ai_brain/proc/has_sniper_home()
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	return emplacement_module?.has_sniper_home()

/datum/human_ai_brain/proc/set_sniper_home(turf/home, new_dir = SOUTH)
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	emplacement_module?.set_sniper_home(home, new_dir)

/datum/human_ai_brain/proc/get_sniper_home()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	return emplacement_module?.sniper_home

/datum/human_ai_brain/proc/get_sniper_dir()
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	return emplacement_module?.sniper_dir

/datum/human_ai_brain/proc/has_machinegunner_home()
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	return emplacement_module?.has_machinegunner_home()

/datum/human_ai_brain/proc/set_machinegunner_home(turf/home, new_dir = SOUTH)
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	emplacement_module?.set_machinegunner_home(home, new_dir)

/datum/human_ai_brain/proc/get_machinegunner_home()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	return emplacement_module?.machinegunner_home

/datum/human_ai_brain/proc/get_machinegunner_dir()
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	return emplacement_module?.machinegunner_dir

/datum/human_ai_brain/proc/is_stationary_fire_blocked()
	var/datum/human_ai_module/guns/guns_module = get_guns_module()
	var/datum/human_ai_module/cover/cover_module = get_cover_module()
	var/datum/human_ai_module/health/health_module = get_health_module()
	return guns_module?.has_tried_reload() || cover_module?.has_cover() || health_module?.healing_someone

// ==================== Faction ====================
// Friendly/hostile checks and faction memory.
/datum/human_ai_brain/proc/is_friendly_target(atom/target)
	var/datum/human_ai_module/faction/faction_module = get_faction_module()
	return faction_module?.faction_check(target)

/datum/human_ai_brain/proc/get_previous_faction()
	var/datum/human_ai_module/faction/faction_module = get_faction_module()
	return faction_module?.previous_faction

/datum/human_ai_brain/proc/set_previous_faction(new_faction)
	var/datum/human_ai_module/faction/faction_module = get_faction_module()
	if(faction_module)
		faction_module.previous_faction = new_faction

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

/datum/human_ai_brain/proc/find_grenade_for_throw()
	RETURN_TYPE(/obj/item/explosive/grenade)
	var/datum/human_ai_module/inventory/inventory_module = get_inventory_module()
	return inventory_module?.find_grenade_for_throw()

/datum/human_ai_brain/proc/has_throw_in_progress()
	var/datum/human_ai_module/grenade/grenade_module = get_grenade_module()
	return grenade_module?.has_throw_in_progress()

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
	var/datum/human_ai_module/inventory/inventory_module = get_inventory_module()
	return guns_module && !guns_module.has_tried_reload() && (inventory_module?.has_primary_weapon() || inventory_module?.has_secondary_weapons())

// ==================== Health ====================
// Treatment state and self-treatment retry helpers.
/datum/human_ai_brain/proc/is_healing_someone()
	var/datum/human_ai_module/health/health_module = get_health_module()
	return health_module?.healing_someone

/datum/human_ai_brain/proc/can_retry_self_treatment()
	var/datum/human_ai_module/health/health_module = get_health_module()
	return health_module && (health_module.cant_be_treated_stacks < health_module.treatment_stack_threshold)

/datum/human_ai_brain/proc/cancel_treatment()
	var/datum/human_ai_module/health/health_module = get_health_module()
	health_module?.cancel_treatment()

/datum/human_ai_brain/proc/increment_treatment_stacks()
	var/datum/human_ai_module/health/health_module = get_health_module()
	health_module?.increment_treatment_stacks()

// ==================== Navigation ====================
// Movement requests and pathing profile knobs.
/datum/human_ai_brain/proc/move_to_turf(turf/destination)
	var/datum/human_ai_module/navigation/navigation_module = get_navigation_module()
	return navigation_module?.move_to_next_turf(destination)

/datum/human_ai_brain/proc/move_to_atom(atom/target)
	if(!target)
		return FALSE
	var/datum/human_ai_module/navigation/navigation_module = get_navigation_module()
	return navigation_module?.move_to_next_turf(get_turf(target))

/datum/human_ai_brain/proc/apply_navigation_profile(short_step_range = 0, path_retarget_slack = 0)
	var/datum/human_ai_module/navigation/navigation_module = get_navigation_module()
	if(!navigation_module)
		return
	if(short_step_range > 0)
		navigation_module.short_step_pathing_range = max(navigation_module.short_step_pathing_range, short_step_range)
	if(path_retarget_slack > 0)
		navigation_module.path_target_retarget_slack = max(navigation_module.path_target_retarget_slack, path_retarget_slack)

// ==================== Orders ====================
// Order-gated movement and quick-approach transient state.
/datum/human_ai_brain/proc/can_move_for_action()
	var/datum/human_ai_module/orders/orders_module = get_orders_module()
	return !orders_module || orders_module.can_move_for_action()

/datum/human_ai_brain/proc/get_quick_approach_turf()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/orders/orders_module = get_orders_module()
	return orders_module?.quick_approach

/datum/human_ai_brain/proc/clear_quick_approach()
	var/datum/human_ai_module/orders/orders_module = get_orders_module()
	orders_module?.clear_quick_approach()

/datum/human_ai_brain/proc/set_quick_approach(turf/new_turf)
	var/datum/human_ai_module/orders/orders_module = get_orders_module()
	orders_module?.set_quick_approach(new_turf)

/datum/human_ai_brain/proc/set_hold_position(new_value)
	var/datum/human_ai_module/orders/orders_module = get_orders_module()
	orders_module?.set_hold_position(new_value)

// ==================== Profile ====================
// Generic timing, vision, and combat profile values.
/datum/human_ai_brain/proc/get_targeting_view_distance()
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	return profile_module?.view_distance || 0

/datum/human_ai_brain/proc/has_scope_vision()
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	return profile_module?.scope_vision

/datum/human_ai_brain/proc/should_shoot_to_kill()
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	return profile_module?.shoot_to_kill

/datum/human_ai_brain/proc/get_view_distance()
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	return profile_module?.view_distance || 0

/datum/human_ai_brain/proc/set_view_distance(new_view_distance)
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	if(profile_module)
		profile_module.view_distance = new_view_distance

/datum/human_ai_brain/proc/get_action_delay()
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	if(!profile_module)
		return 0
	return profile_module.short_action_delay * profile_module.action_delay_mult

/datum/human_ai_brain/proc/get_micro_action_delay()
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	if(!profile_module)
		return 0
	return profile_module.micro_action_delay * profile_module.action_delay_mult

/datum/human_ai_brain/proc/get_short_action_delay(apply_multiplier = FALSE)
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	if(!profile_module)
		return 0
	if(apply_multiplier)
		return profile_module.short_action_delay * profile_module.action_delay_mult
	return profile_module.short_action_delay

/datum/human_ai_brain/proc/get_medium_action_delay(apply_multiplier = FALSE)
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	if(!profile_module)
		return 0
	if(apply_multiplier)
		return profile_module.medium_action_delay * profile_module.action_delay_mult
	return profile_module.medium_action_delay

// ==================== Squad ====================
// Squad membership, leader lookup, and current order glue.
/datum/human_ai_brain/proc/is_squad_leader()
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	return squad_module?.is_squad_leader

/datum/human_ai_brain/proc/set_squad_leader_status(is_leader)
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	if(squad_module)
		squad_module.is_squad_leader = is_leader

/datum/human_ai_brain/proc/get_squad_id()
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	return squad_module?.squad_id

/datum/human_ai_brain/proc/has_squad()
	return !!get_squad_id()

/datum/human_ai_brain/proc/set_squad_id(new_squad_id)
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	if(squad_module)
		squad_module.squad_id = new_squad_id

/datum/human_ai_brain/proc/can_assign_squad()
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	return squad_module?.can_assign_squad

/datum/human_ai_brain/proc/add_to_squad(new_squad_id)
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	return squad_module?.add_to_squad(new_squad_id)

/datum/human_ai_brain/proc/get_squad_datum()
	RETURN_TYPE(/datum/human_ai_squad)
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	if(!squad_module?.squad_id)
		return null
	return SShuman_ai.squad_id_dict["[squad_module.squad_id]"]

/datum/human_ai_brain/proc/get_squad_leader()
	RETURN_TYPE(/datum/human_ai_brain)
	var/datum/human_ai_squad/squad_datum = get_squad_datum()
	return squad_datum?.squad_leader

/datum/human_ai_brain/proc/get_squad_members()
	var/datum/human_ai_squad/squad_datum = get_squad_datum()
	return squad_datum?.ai_in_squad || list()

/datum/human_ai_brain/proc/get_current_order()
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	return squad_module?.current_order

/datum/human_ai_brain/proc/remove_current_order()
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	squad_module?.remove_current_order()

/datum/human_ai_brain/proc/set_current_order(datum/ai_order/order)
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	squad_module?.set_current_order(order)

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
