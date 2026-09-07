GLOBAL_LIST_EMPTY(human_ai_brains)

/datum/human_ai_brain
	/// API facade for reading and controlling the tied human puppet.
	var/datum/human_tied_controller/tied_controller

	var/datum/human_ai_module/targeting/targeting
	var/datum/human_ai_module/perception/perception
	var/datum/human_ai_module/cover/cover
	var/datum/human_ai_module/faction/faction
	var/datum/human_ai_module/inventory/inventory
	var/datum/human_ai_module/grenade/grenade
	var/datum/human_ai_module/health/health
	var/datum/human_ai_module/communication/communication
	var/datum/human_ai_module/guns/guns
	var/datum/human_ai_module/navigation/navigation
	var/datum/human_ai_module/squad/squad
	var/datum/human_ai_module/action_runtime/action_runtime
	var/datum/human_ai_module/combat/combat
	var/datum/human_ai_module/conversation/conversation
	var/datum/human_ai_module/orders/orders
	var/datum/human_ai_module/profile/profile
	var/datum/human_ai_module/emplacement/emplacement

	var/list/datum/human_ai_module/reset_modules_before_wake_clear
	var/list/datum/human_ai_module/reset_modules_after_wake_clear
	var/list/datum/human_ai_module/suspend_modules_before_wake_clear
	var/list/datum/human_ai_module/suspend_modules_after_wake_clear
	var/list/datum/human_ai_module/resume_modules
	var/list/datum/human_ai_module/process_modules_before_posture
	var/list/datum/human_ai_module/process_modules_after_posture
	var/list/datum/human_ai_module/target_change_modules
	var/list/datum/human_ai_module/projectile_threat_modules
	var/list/datum/human_ai_module/combat_entered_modules
	var/list/datum/human_ai_module/combat_exit_started_modules
	var/list/datum/human_ai_module/combat_exit_finished_modules
	var/list/datum/human_ai_module/combat_exit_force_clear_modules
	var/list/datum/human_ai_module/target_vision_modules
	var/list/datum/human_ai_module/extension_modules

	var/wake_rethink_queued_at = -1 // SS220 EDIT: wake-up signal should only queue one immediate rethink per tick
	var/last_process_tick = -1 // SS220 EDIT: prevent signal-driven wake rethinks from re-entering the scheduler in the same tick
	var/lifecycle_state = HUMAN_AI_LIFECYCLE_ACTIVE // SS220 EDIT: brain owns active/suspended runtime admission
	var/runtime_shutdown_started = FALSE // SS220 EDIT: component-owned lifetime teardown may race brain delete signals

/datum/human_ai_brain/New(mob/living/carbon/human/new_human)
	. = ..()
	tied_controller = new(src, new_human)
	faction = new(src)
	targeting = new(src)
	cover = new(src)
	grenade = new(src)
	health = new(src)
	communication = new(src)
	guns = new(src)
	navigation = new(src)
	squad = new(src)
	action_runtime = new(src)
	combat = new(src)
	conversation = new(src)
	orders = new(src)
	profile = new(src)
	emplacement = new(src)
	perception = new(src)
	perception.register_signals()
	perception.setup_detection_radius()
	inventory = new(src)
	inventory.register_signals()
	setup_lifecycle_modules()
	tied_controller.register_signal_for(src, COMSIG_PARENT_QDELETING, PROC_REF(on_human_delete))
	tied_controller.register_signal_for(src, COMSIG_MOB_DEATH, PROC_REF(on_human_death)) // SS220 EDIT: HALO death guard should tear down AI and force corpses prone immediately
	tied_controller.register_signal_for(src, COMSIG_MOVABLE_MOVED, PROC_REF(on_move))
	tied_controller.register_signal_for(src, COMSIG_HUMAN_HANDCUFFED, PROC_REF(on_handcuffed))
	tied_controller.register_signal_for(src, COMSIG_HUMAN_GET_AI_BRAIN, PROC_REF(get_ai_brain))
	tied_controller.register_signal_for(src, COMSIG_HUMAN_SET_SPECIES, PROC_REF(on_species_change))
	tied_controller.register_signal_for(src, COMSIG_LIVING_SET_BODY_POSITION, PROC_REF(on_body_position_change)) // SS220 EDIT: standing back up should wake shared human AI immediately
	GLOB.human_ai_brains += src
	inventory.appraise_inventory()
	tied_controller.set_safe_intent()

/datum/human_ai_brain/Destroy(force, ...)
	GLOB.human_ai_brains -= src
	shutdown_runtime()
	reset_modules_before_wake_clear = null
	reset_modules_after_wake_clear = null
	suspend_modules_before_wake_clear = null
	suspend_modules_after_wake_clear = null
	resume_modules = null
	process_modules_before_posture = null
	process_modules_after_posture = null
	target_change_modules = null
	projectile_threat_modules = null
	combat_entered_modules = null
	combat_exit_started_modules = null
	combat_exit_finished_modules = null
	combat_exit_force_clear_modules = null
	target_vision_modules = null
	QDEL_LIST(extension_modules)
	extension_modules = null
	QDEL_NULL(targeting)
	QDEL_NULL(perception)
	QDEL_NULL(cover)
	QDEL_NULL(faction)
	QDEL_NULL(inventory)
	QDEL_NULL(grenade)
	QDEL_NULL(health)
	QDEL_NULL(communication)
	QDEL_NULL(guns)
	QDEL_NULL(navigation)
	QDEL_NULL(squad)
	QDEL_NULL(action_runtime)
	QDEL_NULL(combat)
	QDEL_NULL(conversation)
	QDEL_NULL(orders)
	QDEL_NULL(profile)
	QDEL_NULL(emplacement)
	QDEL_NULL(tied_controller)

	return ..()

/datum/human_ai_brain/proc/has_valid_tied_human()
	return tied_controller?.has_valid_tied_human()

/datum/human_ai_brain/proc/setup_lifecycle_modules()
	setup_lifecycle_module_lists()
	configure_lifecycle_module_lists()
	setup_process_module_lists()
	configure_process_module_lists()
	setup_event_module_lists()
	configure_event_module_lists()
	setup_query_module_lists()
	configure_query_module_lists()

/datum/human_ai_brain/proc/setup_lifecycle_module_lists()
	reset_modules_before_wake_clear = list(
		health,
		navigation,
		cover,
		perception,
	)

	reset_modules_after_wake_clear = list(
		combat,
		grenade,
		targeting,
		inventory,
		action_runtime,
	)

	suspend_modules_before_wake_clear = list(
		navigation,
		cover,
		perception,
	)

	suspend_modules_after_wake_clear = list(
		combat,
		grenade,
		targeting,
		health,
		action_runtime,
		inventory,
	)

	resume_modules = list(
		inventory,
		guns,
	)

/datum/human_ai_brain/proc/setup_process_module_lists()
	process_modules_before_posture = list(
		perception,
	)

	process_modules_after_posture = list(
		targeting,
		combat,
		inventory,
		action_runtime,
	)

/datum/human_ai_brain/proc/setup_event_module_lists()
	target_change_modules = list(
		inventory,
	)

	projectile_threat_modules = list(
		combat,
		faction,
		targeting,
		cover,
	)

	combat_entered_modules = list(
		squad,
		communication,
		cover,
	)

	combat_exit_started_modules = list(
		targeting,
		communication,
		inventory,
	)

	combat_exit_finished_modules = list(
		cover,
		targeting,
	)

	combat_exit_force_clear_modules = list(
		targeting,
		cover,
	)

/datum/human_ai_brain/proc/setup_query_module_lists()
	target_vision_modules = list(
		inventory,
	)

/datum/human_ai_brain/proc/configure_lifecycle_module_lists()
	return

/datum/human_ai_brain/proc/configure_process_module_lists()
	return

/datum/human_ai_brain/proc/configure_event_module_lists()
	return

/datum/human_ai_brain/proc/configure_query_module_lists()
	return

/datum/human_ai_brain/proc/register_extension_module(datum/human_ai_module/module)
	if(!module)
		return null

	LAZYOR(extension_modules, module)
	return module

/datum/human_ai_brain/proc/reset_ai()
	for(var/datum/human_ai_module/module as anything in reset_modules_before_wake_clear)
		module.reset_module()
	wake_rethink_queued_at = -1 // SS220 EDIT: reset must always cancel deferred wake-up recovery before owner teardown finishes
	for(var/datum/human_ai_module/module as anything in reset_modules_after_wake_clear)
		module.reset_module()

/datum/human_ai_brain/proc/shutdown_runtime()
	if(runtime_shutdown_started)
		return FALSE

	runtime_shutdown_started = TRUE
	lifecycle_state = HUMAN_AI_LIFECYCLE_INVALID
	reset_ai()
	return TRUE

/datum/human_ai_brain/proc/can_continue_runtime_work()
	if(QDELETED(src) || runtime_shutdown_started)
		return FALSE
	if(lifecycle_state != HUMAN_AI_LIFECYCLE_ACTIVE)
		return FALSE
	return get_lifecycle_state() == HUMAN_AI_LIFECYCLE_ACTIVE

/datum/human_ai_brain/process(delta_time)
	last_process_tick = world.time // SS220 EDIT: track scheduler entry to guard same-tick wake rethinks
	wake_rethink_queued_at = -1 // SS220 EDIT: any queued wake rethink has been serviced once processing starts

	var/new_lifecycle_state = get_lifecycle_state()
	if(new_lifecycle_state != HUMAN_AI_LIFECYCLE_ACTIVE)
		handle_suspended_lifecycle_state(new_lifecycle_state)
		lifecycle_state = new_lifecycle_state
		return

	if(lifecycle_state != HUMAN_AI_LIFECYCLE_ACTIVE)
		resume_from_lifecycle_suspension(lifecycle_state)
	lifecycle_state = HUMAN_AI_LIFECYCLE_ACTIVE

	process_active_ai(delta_time)

/datum/human_ai_brain/proc/get_lifecycle_state()
	if(!has_valid_tied_human())
		return HUMAN_AI_LIFECYCLE_INVALID
	if(tied_controller.is_dead())
		return HUMAN_AI_LIFECYCLE_DEAD
	if(tied_controller.can_player_takeover_block_ai())
		return HUMAN_AI_LIFECYCLE_PLAYER_CONTROLLED
	if(should_force_hardcrit_resting())
		return HUMAN_AI_LIFECYCLE_HARDCRIT
	if(tied_controller.is_incapacitated())
		return HUMAN_AI_LIFECYCLE_INCAPACITATED
	return HUMAN_AI_LIFECYCLE_ACTIVE

/datum/human_ai_brain/proc/handle_suspended_lifecycle_state(new_lifecycle_state)
	switch(new_lifecycle_state)
		if(HUMAN_AI_LIFECYCLE_INVALID)
			reset_ai()
		if(HUMAN_AI_LIFECYCLE_DEAD)
			suspend_for_death()
		if(HUMAN_AI_LIFECYCLE_PLAYER_CONTROLLED)
			suspend_for_player_control()
		if(HUMAN_AI_LIFECYCLE_HARDCRIT)
			suspend_for_hardcrit()
		if(HUMAN_AI_LIFECYCLE_INCAPACITATED)
			suspend_for_incapacitated()

/datum/human_ai_brain/proc/suspend_runtime(clear_inventory = FALSE)
	for(var/datum/human_ai_module/module as anything in suspend_modules_before_wake_clear)
		module.suspend_module(clear_inventory)
	wake_rethink_queued_at = -1
	for(var/datum/human_ai_module/module as anything in suspend_modules_after_wake_clear)
		module.suspend_module(clear_inventory)

/datum/human_ai_brain/proc/suspend_for_death()
	suspend_runtime()
	if(!has_valid_tied_human() || !tied_controller.is_dead())
		return
	if(tied_controller.is_buckled()) // SS220 EDIT: death suspension releases forced-standing buckle state without deleting revive-capable brain
		tied_controller.unbuckle()
	tied_controller.force_prone()

/datum/human_ai_brain/proc/suspend_for_player_control()
	if(lifecycle_state == HUMAN_AI_LIFECYCLE_PLAYER_CONTROLLED)
		return
	suspend_runtime()

/datum/human_ai_brain/proc/suspend_for_incapacitated()
	suspend_runtime()

/datum/human_ai_brain/proc/suspend_for_hardcrit()
	suspend_runtime()
	if(!has_valid_tied_human())
		return
	tied_controller.force_prone()
	inventory.clear_pickup_queue()
	inventory.invalidate_nearby_item_search()

/datum/human_ai_brain/proc/resume_from_lifecycle_suspension(previous_lifecycle_state)
	if(!has_valid_tied_human() || tied_controller.can_player_takeover_block_ai())
		return FALSE

	if(previous_lifecycle_state == HUMAN_AI_LIFECYCLE_INVALID)
		return FALSE

	for(var/datum/human_ai_module/module as anything in resume_modules)
		module.resume_module(previous_lifecycle_state)
	brain_resume_modular_runtime()
	return TRUE

/datum/human_ai_brain/proc/brain_resume_modular_runtime()
	invalidate_halo_runtime_caches()

/datum/human_ai_brain/proc/should_force_hardcrit_resting()
	return (tied_controller.has_effect(/datum/effects/crit) && tied_controller.has_status_flag(CANKNOCKOUT))

/datum/human_ai_brain/proc/process_active_ai(delta_time)

	if(process_active_module_list(process_modules_before_posture, delta_time))
		return

	// SS220 EDIT - START: hardcrit AIs should keep resting until the crit loop and knockdown pressure are truly gone
	if((tied_controller.get_stat() == CONSCIOUS) && tied_controller.is_resting() && !tied_controller.has_trait(TRAIT_FLOORED))
		// SS220 EDIT - START: final stand-up gate must stay exactly aligned with the existing wake rethink eligibility rules
		tied_controller.try_stand_up()
		// SS220 EDIT - END
	// SS220 EDIT - END

	if(tied_controller.is_buckled())
		tied_controller.clear_buckle_state() // AI never buckle themselves into chairs at the moment, change if this becomes the case

	if(process_active_module_list(process_modules_after_posture, delta_time))
		return

/datum/human_ai_brain/proc/process_active_module_list(list/datum/human_ai_module/module_list, delta_time)
	for(var/datum/human_ai_module/module as anything in module_list)
		if(module.process_module(delta_time))
			return TRUE
	return FALSE

/datum/human_ai_brain/proc/on_target_changed(atom/movable/old_target, atom/movable/new_target)
	if(!target_change_modules)
		return

	for(var/datum/human_ai_module/module as anything in target_change_modules)
		module.on_target_changed(old_target, new_target)

/datum/human_ai_brain/proc/on_projectile_threat(obj/projectile/bullet, from_direct_hit = FALSE)
	if(!projectile_threat_modules)
		return

	for(var/datum/human_ai_module/module as anything in projectile_threat_modules)
		module.on_projectile_threat(bullet, from_direct_hit)

/datum/human_ai_brain/proc/on_combat_entered(was_in_combat)
	if(!combat_entered_modules)
		return

	for(var/datum/human_ai_module/module as anything in combat_entered_modules)
		module.on_combat_entered(was_in_combat)

/datum/human_ai_brain/proc/on_combat_exit_started()
	if(!combat_exit_started_modules)
		return

	tied_controller.set_safe_intent()
	var/should_holster_primary = !emplacement.has_sniper_home()
	for(var/datum/human_ai_module/module as anything in combat_exit_started_modules)
		module.on_combat_exit_started(should_holster_primary)

/datum/human_ai_brain/proc/on_combat_exit_finished()
	if(!combat_exit_finished_modules)
		return

	var/list/combat_exit_context = list("clear_target_turf" = FALSE)
	for(var/datum/human_ai_module/module as anything in combat_exit_finished_modules)
		module.on_combat_exit_finished(combat_exit_context)

/datum/human_ai_brain/proc/on_combat_exit_force_cleared()
	if(!combat_exit_force_clear_modules)
		return

	var/list/combat_exit_context = list(
		"clear_target_turf" = TRUE,
		"force_clear" = TRUE,
	)
	for(var/datum/human_ai_module/module as anything in combat_exit_force_clear_modules)
		module.on_combat_exit_finished(combat_exit_context)

/datum/human_ai_brain/proc/can_ignore_target_darkness()
	if(!target_vision_modules)
		return FALSE

	for(var/datum/human_ai_module/module as anything in target_vision_modules)
		if(module.can_ignore_target_darkness())
			return TRUE
	return FALSE

// Combat facade
/datum/human_ai_brain/proc/is_in_combat()
	return combat.in_combat

/datum/human_ai_brain/proc/set_shot_at_turf(turf/target_turf)
	combat.shot_at = get_turf(target_turf)

// Orders facade
/datum/human_ai_brain/proc/can_move_for_action()
	return orders.can_move_for_action()

/datum/human_ai_brain/proc/get_quick_approach_turf()
	RETURN_TYPE(/turf)
	return orders.quick_approach

/datum/human_ai_brain/proc/clear_quick_approach()
	orders.clear_quick_approach()

// Grenade facade
/datum/human_ai_brain/proc/has_active_grenade()
	return grenade.has_active_grenade()

/datum/human_ai_brain/proc/get_active_grenade()
	RETURN_TYPE(/obj/item/explosive/grenade)
	return grenade.get_active_grenade()

/datum/human_ai_brain/proc/set_active_grenade(obj/item/explosive/grenade/new_grenade)
	grenade.set_active_grenade(new_grenade)

/datum/human_ai_brain/proc/clear_active_grenade()
	grenade.clear_active_grenade()

/datum/human_ai_brain/proc/can_throw_grenades()
	return grenade.can_throw_grenades()

/datum/human_ai_brain/proc/can_throw_back_grenade()
	return grenade.can_throw_back()

/datum/human_ai_brain/proc/find_grenade_for_throw()
	RETURN_TYPE(/obj/item/explosive/grenade)
	return inventory.find_grenade_for_throw()

/datum/human_ai_brain/proc/has_throw_in_progress()
	return grenade.has_throw_in_progress()

// Inventory facade
/datum/human_ai_brain/proc/get_equipment_summary(equipment_type)
	return inventory.get_equipment_summary(equipment_type)

/datum/human_ai_brain/proc/has_equipment(equipment_type)
	return inventory.has_equipment(equipment_type)

/datum/human_ai_brain/proc/has_pickup_queue()
	return inventory.has_pickup_queue()

/datum/human_ai_brain/proc/get_next_pickup()
	RETURN_TYPE(/obj/item)
	return inventory.get_next_pickup()

/datum/human_ai_brain/proc/unqueue_pickup(obj/item/item)
	inventory.unqueue_pickup(item)

/datum/human_ai_brain/proc/is_looting_disabled()
	return inventory.is_looting_disabled()

/datum/human_ai_brain/proc/has_primary_weapon()
	return inventory.has_primary_weapon()

/datum/human_ai_brain/proc/set_primary_weapon(obj/item/weapon/gun/new_primary_weapon)
	inventory.set_primary_weapon(new_primary_weapon)

/datum/human_ai_brain/proc/drop_primary_weapon()
	var/obj/item/weapon/gun/primary_weapon = inventory.get_primary_weapon()
	if(primary_weapon)
		tied_controller.drop_held_item(primary_weapon)
	inventory.set_primary_weapon(null)

/datum/human_ai_brain/proc/unholster_primary()
	return inventory.unholster_primary()

/datum/human_ai_brain/proc/ensure_primary_hand(obj/item/weapon/gun/primary_weapon)
	return inventory.ensure_primary_hand(primary_weapon)

/datum/human_ai_brain/proc/wield_primary()
	return inventory.wield_primary()

/datum/human_ai_brain/proc/has_secondary_weapons()
	return inventory.has_secondary_weapons()

/datum/human_ai_brain/proc/get_next_secondary_weapon()
	RETURN_TYPE(/obj/item/weapon/gun)
	return inventory.get_next_secondary_weapon()

/datum/human_ai_brain/proc/add_secondary_weapon(obj/item/weapon/gun/weapon)
	return inventory.add_secondary_weapon(weapon)

/datum/human_ai_brain/proc/get_primary_weapon()
	RETURN_TYPE(/obj/item/weapon/gun)
	return inventory.get_primary_weapon()

/datum/human_ai_brain/proc/get_gun_data()
	RETURN_TYPE(/datum/human_ai_firearm_profile)
	return inventory.get_gun_data()

/datum/human_ai_brain/proc/has_gun_data()
	return inventory.has_gun_data()

/datum/human_ai_brain/proc/storage_has_room(obj/item/item)
	return inventory.storage_has_room(item)

/datum/human_ai_brain/proc/has_container_ref(container_id)
	return inventory.has_container_ref(container_id)

/datum/human_ai_brain/proc/get_pickup_storage_equipment_types(obj/item/item)
	return inventory.get_pickup_storage_equipment_types(item)

/datum/human_ai_brain/proc/store_item_as_types(obj/item/item, storage_spot, list/equipment_types)
	return inventory.store_item_as_types(item, storage_spot, equipment_types)

/datum/human_ai_brain/proc/store_item(obj/item/item, storage_spot, equipment_type = null)
	return inventory.store_item(item, storage_spot, equipment_type)

/datum/human_ai_brain/proc/prepare_primary_for_fire(obj/item/weapon/gun/primary_weapon)
	if(!primary_weapon)
		return FALSE
	unholster_primary()
	ensure_primary_hand(primary_weapon)
	wield_primary()
	return TRUE

/datum/human_ai_brain/proc/clear_main_hand()
	inventory.clear_main_hand()

/datum/human_ai_brain/proc/equip_item_from_equipment_map(equipment_type, obj/item/item)
	return inventory.equip_item_from_equipment_map(equipment_type, item)

/datum/human_ai_brain/proc/find_usable_equipment_by_type_list(list/item_types, equipment_type, mob/living/carbon/human/target = null)
	RETURN_TYPE(/obj/item)
	return inventory.find_usable_equipment_by_type_list(item_types, equipment_type, target)

// Guns facade
/datum/human_ai_brain/proc/has_tried_reload()
	return guns.has_tried_reload()

/datum/human_ai_brain/proc/mark_tried_reload()
	guns.mark_tried_reload()

/datum/human_ai_brain/proc/should_reload()
	return guns.should_reload()

/datum/human_ai_brain/proc/can_start_fire()
	return COOLDOWN_FINISHED(guns, stop_fire_cooldown)

/datum/human_ai_brain/proc/start_stop_fire_cooldown(cooldown)
	COOLDOWN_START(guns, stop_fire_cooldown, cooldown)

/datum/human_ai_brain/proc/can_continue_fire_burst()
	return COOLDOWN_FINISHED(guns, fire_overload_cooldown)

/datum/human_ai_brain/proc/start_fire_overload_cooldown()
	var/short_action_delay = profile.short_action_delay
	COOLDOWN_START(guns, fire_overload_cooldown, max(short_action_delay, short_action_delay * profile.action_delay_mult))

/datum/human_ai_brain/proc/clear_tried_reload()
	guns.clear_tried_reload()

/datum/human_ai_brain/proc/can_use_ranged_weapon()
	return !guns.has_tried_reload() && (inventory.has_primary_weapon() || inventory.has_secondary_weapons())

// Action runtime facade
/datum/human_ai_brain/proc/cancel_ongoing_actions_by_type(list/action_types, datum/ai_action/except_action = null)
	if(!length(action_types))
		return

	for(var/datum/ai_action/ongoing_action as anything in action_runtime.ongoing_actions)
		if((ongoing_action != except_action) && (ongoing_action.type in action_types))
			qdel(ongoing_action)

/datum/human_ai_brain/proc/remove_ongoing_action(datum/ai_action/action)
	action_runtime.ongoing_actions -= action

/datum/human_ai_brain/proc/has_ongoing_action(action_type)
	return action_runtime.has_ongoing_action(action_type)

/datum/human_ai_brain/proc/has_ongoing_throw_action_in_progress()
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

// Targeting facade
/datum/human_ai_brain/proc/get_current_target()
	RETURN_TYPE(/atom/movable)
	return targeting.get_current_target()

/datum/human_ai_brain/proc/get_aim_target()
	RETURN_TYPE(/atom)
	return targeting.get_aim_target()

/datum/human_ai_brain/proc/has_current_target()
	return targeting.has_current_target()

/datum/human_ai_brain/proc/can_target(atom/movable/target)
	return targeting.can_target(target)

/datum/human_ai_brain/proc/get_target_turf()
	RETURN_TYPE(/turf)
	return targeting.get_target_turf()

/datum/human_ai_brain/proc/has_target_turf()
	return targeting.has_target_turf()

/datum/human_ai_brain/proc/has_offscreen_fire_target()
	return targeting.has_target_turf() && !COOLDOWN_FINISHED(src, targeting.fire_offscreen)

/datum/human_ai_brain/proc/can_fire_offscreen(turf/target_turf, datum/human_ai_firearm_profile/gun_data = null)
	if(!target_turf || COOLDOWN_FINISHED(src, targeting.fire_offscreen))
		return FALSE
	if(!gun_data)
		return TRUE
	return gun_data.maximum_range > profile.view_distance

/datum/human_ai_brain/proc/lose_target()
	targeting.lose_target()

/datum/human_ai_brain/proc/clear_target_turf()
	targeting.clear_target_turf()

/datum/human_ai_brain/proc/set_target_turf_direct(turf/new_target_turf)
	targeting.set_target_turf_direct(new_target_turf)

// Cover facade
/datum/human_ai_brain/proc/has_cover()
	return cover.has_cover()

/datum/human_ai_brain/proc/is_in_cover()
	return cover.is_in_cover()

/datum/human_ai_brain/proc/has_pending_cover()
	return cover.has_cover() && !cover.is_in_cover()

/datum/human_ai_brain/proc/get_current_cover()
	RETURN_TYPE(/turf)
	return cover.get_current_cover()

/datum/human_ai_brain/proc/end_cover()
	cover.end_cover()

/datum/human_ai_brain/proc/enter_cover()
	cover.enter_cover()

/datum/human_ai_brain/proc/try_cover(angle = null, atom/source = null)
	cover.try_cover(angle, source)

/datum/human_ai_brain/proc/apply_cover_processing(list/turf_dict, from_squad = FALSE)
	cover.cover_processing(turf_dict, from_squad)

/datum/human_ai_brain/proc/start_cover_search_cooldown(cooldown)
	COOLDOWN_START(cover, cover_search_cooldown, cooldown)

// Navigation facade
/datum/human_ai_brain/proc/move_to_turf(turf/destination)
	return navigation.move_to_next_turf(destination)

/datum/human_ai_brain/proc/move_to_atom(atom/target)
	if(!target)
		return FALSE
	return navigation.move_to_next_turf(get_turf(target))

// Squad facade
/datum/human_ai_brain/proc/is_squad_leader()
	return squad.is_squad_leader

/datum/human_ai_brain/proc/set_squad_leader_status(is_leader)
	squad.is_squad_leader = is_leader

/datum/human_ai_brain/proc/get_squad_id()
	return squad.squad_id

/datum/human_ai_brain/proc/set_squad_id(new_squad_id)
	squad.squad_id = new_squad_id

/datum/human_ai_brain/proc/get_squad_datum()
	if(!squad.squad_id)
		return null
	return SShuman_ai.squad_id_dict["[squad.squad_id]"]

/datum/human_ai_brain/proc/get_current_order()
	return squad.current_order

/datum/human_ai_brain/proc/remove_current_order()
	squad.remove_current_order()

/datum/human_ai_brain/proc/set_current_order(datum/ai_order/order)
	squad.set_current_order(order)

/datum/human_ai_brain/proc/on_squad_member_death(mob/living/carbon/human/dead_mob)
	communication.on_squad_member_death(dead_mob)

// Emplacement facade
/datum/human_ai_brain/proc/has_sniper_home()
	return emplacement.has_sniper_home()

/datum/human_ai_brain/proc/set_sniper_home(turf/home, new_dir = SOUTH)
	emplacement.set_sniper_home(home, new_dir)

/datum/human_ai_brain/proc/get_sniper_home()
	RETURN_TYPE(/turf)
	return emplacement.sniper_home

/datum/human_ai_brain/proc/get_sniper_dir()
	return emplacement.sniper_dir

/datum/human_ai_brain/proc/has_machinegunner_home()
	return emplacement.has_machinegunner_home()

/datum/human_ai_brain/proc/set_machinegunner_home(turf/home, new_dir = SOUTH)
	emplacement.set_machinegunner_home(home, new_dir)

/datum/human_ai_brain/proc/get_machinegunner_home()
	RETURN_TYPE(/turf)
	return emplacement.machinegunner_home

/datum/human_ai_brain/proc/get_machinegunner_dir()
	return emplacement.machinegunner_dir

/datum/human_ai_brain/proc/is_stationary_fire_blocked()
	return guns.has_tried_reload() || cover.has_cover() || health.healing_someone

// Faction facade
/datum/human_ai_brain/proc/is_friendly_target(atom/target)
	return faction.faction_check(target)

/datum/human_ai_brain/proc/get_previous_faction()
	return faction.previous_faction

/datum/human_ai_brain/proc/set_previous_faction(new_faction)
	faction.previous_faction = new_faction

// Profile facade
/datum/human_ai_brain/proc/get_targeting_view_distance()
	return profile.view_distance

/datum/human_ai_brain/proc/has_scope_vision()
	return profile.scope_vision

/datum/human_ai_brain/proc/should_shoot_to_kill()
	return profile.shoot_to_kill

/datum/human_ai_brain/proc/get_view_distance()
	return profile.view_distance

/datum/human_ai_brain/proc/set_view_distance(new_view_distance)
	profile.view_distance = new_view_distance

/datum/human_ai_brain/proc/get_action_delay()
	return profile.short_action_delay * profile.action_delay_mult

// Communication facade
/datum/human_ai_brain/proc/get_reload_line_chance()
	return communication.reload_line_chance

/datum/human_ai_brain/proc/set_reload_line_chance(new_chance)
	communication.reload_line_chance = new_chance

/datum/human_ai_brain/proc/say_reload_line()
	communication.say_reload_line()

// Health facade
/datum/human_ai_brain/proc/is_healing_someone()
	return health.healing_someone

/datum/human_ai_brain/proc/can_retry_self_treatment()
	return health.cant_be_treated_stacks < health.treatment_stack_threshold

/datum/human_ai_brain/proc/cancel_treatment()
	health.cancel_treatment()

/datum/human_ai_brain/proc/increment_treatment_stacks()
	health.increment_treatment_stacks()

/datum/human_ai_brain/proc/on_human_delete(datum/source, force)
	SIGNAL_HANDLER
	perception.clear_detection_radius() // SS220 EDIT: aggressively tear down brain state before component qdel catches up
	shutdown_runtime()
	wake_rethink_queued_at = -1 // SS220 EDIT: owner delete must not leave a queued wake rethink pointing at a null tied human
	tied_controller?.set_tied_human(null)

/datum/human_ai_brain/proc/on_human_death(datum/source)
	SIGNAL_HANDLER
	suspend_for_death()
	lifecycle_state = HUMAN_AI_LIFECYCLE_DEAD

/datum/human_ai_brain/proc/on_species_change(datum/source, new_species)
	SIGNAL_HANDLER
	if((new_species == SPECIES_YAUTJA) || (new_species == SPECIES_ZOMBIE))
		inventory.set_looting_disabled(TRUE)
	else
		inventory.set_looting_disabled(FALSE)

/datum/human_ai_brain/proc/on_body_position_change(datum/source, new_position, old_position)
	SIGNAL_HANDLER
	if((new_position != STANDING_UP) || (old_position != LYING_DOWN))
		return

	if(!tied_controller.can_stand_up())
		return

	inventory.invalidate_nearby_item_search() // SS220 EDIT: wake-up should immediately invalidate idle pickup/grenade scan throttles
	if(targeting.has_current_target())
		targeting.update_target_pos() // SS220 EDIT: refresh transient combat targeting state after knockdown recovery

	if((last_process_tick == world.time) || (wake_rethink_queued_at == world.time))
		return

	wake_rethink_queued_at = world.time
	INVOKE_ASYNC(src, PROC_REF(run_wake_rethink), world.time) // SS220 EDIT: queue exactly one no-sleep rethink outside the signal stack

/datum/human_ai_brain/proc/run_wake_rethink(queued_tick)
	if(QDELETED(src) || (wake_rethink_queued_at != queued_tick))
		return

	wake_rethink_queued_at = -1
	if(!tied_controller.can_stand_up())
		return

	if((last_process_tick == queued_tick) || (last_process_tick == world.time))
		return

	process(0) // SS220 EDIT: reuse the existing shared AI loop instead of inventing a separate wake-up behavior



/datum/human_ai_brain/proc/on_move(atom/oldloc, direction, forced)
	if(!has_valid_tied_human())
		return

	perception.setup_detection_radius()

	if(cover.is_in_cover() && (tied_controller.get_distance_to(cover.get_current_cover()) > inventory.get_gun_data()?.minimum_range))
		cover.end_cover()

	targeting.update_target_pos()

/datum/human_ai_brain/proc/enter_combat()
	return combat.enter_combat()

/datum/human_ai_brain/proc/exit_combat()
	return combat.exit_combat()
