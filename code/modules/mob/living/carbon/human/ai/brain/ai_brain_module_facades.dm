// Human AI module-facing facade procs.
// These wrappers are grouped by the module/theme they expose so callers do not need to know the brain's internal module layout.

// ==================== Modules ====================
// Generic lookup helpers for partial module compositions.
/datum/human_ai_brain/proc/get_module(module_type)
	if(!module_config)
		return null
	return module_config.get_module_by_type(module_type)

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

	var/list/actions_to_cancel = action_runtime_module.ongoing_actions.Copy()
	for(var/datum/ai_action/ongoing_action as anything in actions_to_cancel)
		if(!(ongoing_action in action_runtime_module.ongoing_actions))
			continue
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
	cancel_ongoing_actions_by_type(action_types)

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
	for(var/datum/ai_action/ongoing_action as anything in action_runtime_module.ongoing_actions.Copy())
		if(!(ongoing_action in action_runtime_module.ongoing_actions))
			continue
		if(istype(ongoing_action, /datum/ai_action/throw_grenade))
			var/datum/ai_action/throw_grenade/throw_grenade_action = ongoing_action
			if(throw_grenade_action.mid_throw)
				return TRUE

		if(istype(ongoing_action, /datum/ai_action/throw_back_nade))
			var/datum/ai_action/throw_back_nade/throw_back_action = ongoing_action
			if(throw_back_action.mid_throw)
				return TRUE

	return FALSE

// ==================== Communication ====================
// Voice lines and squad/combat communication hooks.
/datum/human_ai_brain/proc/get_reload_line_chance()
	var/datum/human_ai_module/communication/communication_module = get_communication_module()
	return communication_module?.get_reload_line_chance() || 0

/datum/human_ai_brain/proc/set_reload_line_chance(new_chance)
	var/datum/human_ai_module/communication/communication_module = get_communication_module()
	communication_module?.set_reload_line_chance(new_chance)

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

/datum/human_ai_brain/proc/can_continue_conversation()
	var/datum/human_ai_module/conversation/conversation_module = get_conversation_module()
	return conversation_module?.can_continue()

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
	return guns_module?.has_tried_reload() || should_block_stationary_fire_for_cover() || is_healing_someone()

// ==================== Faction ====================
// Friendly/hostile checks and faction memory.
/datum/human_ai_brain/proc/is_friendly_target(atom/target)
	var/datum/human_ai_module/faction/faction_module = get_faction_module()
	return faction_module?.faction_check(target)

/datum/human_ai_brain/proc/get_previous_faction()
	var/datum/human_ai_module/faction/faction_module = get_faction_module()
	return faction_module?.get_previous_faction()

/datum/human_ai_brain/proc/set_previous_faction(new_faction)
	var/datum/human_ai_module/faction/faction_module = get_faction_module()
	faction_module?.set_previous_faction(new_faction)

// ==================== Health ====================
// Treatment state and self-treatment retry helpers.
/datum/human_ai_brain/proc/is_healing_someone()
	var/datum/human_ai_module/health/health_module = get_health_module()
	return health_module?.is_treating()

/datum/human_ai_brain/proc/can_retry_self_treatment()
	var/datum/human_ai_module/health/health_module = get_health_module()
	return health_module?.can_retry_self_treatment()

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
	navigation_module?.apply_navigation_profile(short_step_range, path_retarget_slack)

// ==================== Orders ====================
// Order-gated movement and quick-approach transient state.
/datum/human_ai_brain/proc/can_move_for_action()
	var/datum/human_ai_module/orders/orders_module = get_orders_module()
	return !orders_module || orders_module.can_move_for_action()

/datum/human_ai_brain/proc/get_quick_approach_turf()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/orders/orders_module = get_orders_module()
	return orders_module?.get_quick_approach()

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
	return profile_module?.get_view_distance() || 0

/datum/human_ai_brain/proc/has_scope_vision()
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	return profile_module?.has_scope_vision()

/datum/human_ai_brain/proc/should_shoot_to_kill()
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	return profile_module?.should_shoot_to_kill()

/datum/human_ai_brain/proc/get_view_distance()
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	return profile_module?.get_view_distance() || 0

/datum/human_ai_brain/proc/set_view_distance(new_view_distance)
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	profile_module?.set_view_distance(new_view_distance)

/datum/human_ai_brain/proc/get_action_delay()
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	return profile_module?.get_action_delay() || 0

/datum/human_ai_brain/proc/get_micro_action_delay()
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	return profile_module?.get_micro_action_delay() || 0

/datum/human_ai_brain/proc/get_short_action_delay(apply_multiplier = FALSE)
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	return profile_module?.get_short_action_delay(apply_multiplier) || 0

/datum/human_ai_brain/proc/get_medium_action_delay(apply_multiplier = FALSE)
	var/datum/human_ai_module/profile/profile_module = get_profile_module()
	return profile_module?.get_medium_action_delay(apply_multiplier) || 0

// ==================== Squad ====================
// Squad membership, leader lookup, and current order glue.
/datum/human_ai_brain/proc/is_squad_leader()
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	return squad_module?.is_leader()

/datum/human_ai_brain/proc/set_squad_leader_status(is_leader)
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	squad_module?.set_leader_status(is_leader)

/datum/human_ai_brain/proc/get_squad_id()
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	return squad_module?.get_squad_id()

/datum/human_ai_brain/proc/has_squad()
	return !!get_squad_id()

/datum/human_ai_brain/proc/set_squad_id(new_squad_id)
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	squad_module?.set_squad_id(new_squad_id)

/datum/human_ai_brain/proc/can_assign_squad()
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	return squad_module?.can_assign()

/datum/human_ai_brain/proc/add_to_squad(new_squad_id)
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	return squad_module?.add_to_squad(new_squad_id)

/datum/human_ai_brain/proc/get_squad_datum()
	RETURN_TYPE(/datum/human_ai_squad)
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	return squad_module?.get_squad_datum()

/datum/human_ai_brain/proc/get_squad_leader()
	RETURN_TYPE(/datum/human_ai_brain)
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	return squad_module?.get_squad_leader()

/datum/human_ai_brain/proc/get_squad_members()
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	return squad_module?.get_squad_members() || list()

/datum/human_ai_brain/proc/get_current_order()
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	return squad_module?.get_current_order()

/datum/human_ai_brain/proc/remove_current_order()
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	squad_module?.remove_current_order()

/datum/human_ai_brain/proc/set_current_order(datum/ai_order/order)
	var/datum/human_ai_module/squad/squad_module = get_squad_module()
	squad_module?.set_current_order(order)
