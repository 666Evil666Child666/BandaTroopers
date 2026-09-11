/datum/human_ai_brain
	var/halo_sangheili_runtime = FALSE
	var/halo_unggoy_runtime = FALSE
	var/halo_unggoy_role
	var/halo_unggoy_panic_health_pct = 0
	var/halo_unggoy_panics_without_leader = FALSE
	var/halo_unggoy_ignore_panic = FALSE
	var/halo_unggoy_overheat_retreat = TRUE

	var/halo_sangheili_has_sword = FALSE
	var/halo_sangheili_sword_only = FALSE
	var/halo_sangheili_sword_charge_range = 5
	var/halo_sangheili_unarmed_commit_range = 2
	var/obj/item/weapon/covenant/energy_sword/halo_sangheili_drawn_sword
	var/halo_sangheili_sword_storage_loc
	var/halo_sangheili_melee_committed = FALSE
	var/obj/item/weapon/gun/halo_sangheili_committed_primary_weapon
	var/halo_sangheili_committed_tried_reload = FALSE
	var/halo_sangheili_committed_ignore_looting = FALSE
	var/halo_cached_ranged_fallback_time = -1
	var/halo_cached_ranged_fallback_available
	var/halo_cached_squad_anchor_time = -1
	var/turf/halo_cached_squad_anchor
	var/halo_cached_threat_turf_time = -1
	var/atom/halo_cached_threat_atom
	var/turf/halo_cached_threat_turf
	var/halo_ranged_fire_backoff_until = 0

/datum/human_ai_module/halo_covenant
	module_id = "halo_covenant"

/datum/human_ai_module_config/get_supported_module_types()
	. = ..()
	if(!(/datum/human_ai_module/halo_covenant in .))
		. += /datum/human_ai_module/halo_covenant

/datum/human_ai_brain/proc/halo_get_controller()
	RETURN_TYPE(/datum/human_tied_controller)
	var/datum/human_ai_context/context = create_context()
	var/datum/human_tied_controller/controller = context?.controller
	qdel(context)
	return controller

/datum/human_ai_brain/proc/halo_finalize_human_ai_brain(mob/living/carbon/human/new_human)
	if(!halo_runtime_uses_projectile_pressure_controls())
		return

	var/datum/human_ai_module/halo_covenant/halo_covenant_module = get_module(/datum/human_ai_module/halo_covenant)
	if(!halo_covenant_module)
		halo_covenant_module = module_config?.setup_module_by_type(src, /datum/human_ai_module/halo_covenant)
	halo_configure_covenant_module_lists(halo_covenant_module)

/datum/human_ai_brain/proc/halo_configure_covenant_module_lists(datum/human_ai_module/halo_covenant/halo_covenant_module)
	if(!halo_covenant_module)
		return

	register_ai_event_subscriber(HUMAN_AI_EVENT_RESET_AFTER_WAKE_CLEAR, halo_covenant_module)
	register_ai_event_subscriber(HUMAN_AI_EVENT_COMBAT_EXIT_FINISHED, halo_covenant_module)
	register_ai_event_subscriber(HUMAN_AI_EVENT_COMBAT_EXIT_FORCE_CLEARED, halo_covenant_module)

/datum/human_ai_module/halo_covenant/reset_module()
	brain.invalidate_halo_runtime_caches()
	brain.halo_sangheili_clear_melee_commit(FALSE)

/datum/human_ai_module/halo_covenant/on_ai_event(datum/human_ai_event/event)
	switch(event.event_type)
		if(HUMAN_AI_EVENT_RESET_AFTER_WAKE_CLEAR)
			on_reset()
		if(HUMAN_AI_EVENT_COMBAT_EXIT_FINISHED, HUMAN_AI_EVENT_COMBAT_EXIT_FORCE_CLEARED)
			on_combat_exit_finished(event.data?["combat_exit_context"])

/datum/human_ai_module/halo_covenant/on_combat_exit_finished(list/combat_exit_context)
	if(brain.halo_sangheili_should_preserve_drawn_sword())
		brain.halo_sangheili_clear_melee_commit(FALSE)
		return
	if(brain.halo_sangheili_melee_committed || brain.halo_sangheili_drawn_sword)
		brain.halo_sangheili_holster_sword()

/datum/human_ai_brain/proc/halo_covenant_can_run_movement_action(block_active_grenade = FALSE)
	if(!is_in_combat() || !can_move_for_action())
		return FALSE
	if(block_active_grenade && has_active_grenade())
		return FALSE
	return TRUE

/datum/human_ai_brain/proc/halo_covenant_has_pending_cover()
	return has_pending_cover()

/datum/human_ai_brain/proc/halo_covenant_has_cover()
	return has_cover()

/datum/human_ai_brain/proc/halo_covenant_end_cover()
	end_cover()

/datum/human_ai_brain/proc/halo_covenant_try_cover_retreat(atom/threat)
	if(!get_cover_module())
		return FALSE
	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller)
		return FALSE

	if(!get_current_cover())
		try_cover(controller.get_angle_from(threat), threat)

	var/turf/cover_turf = get_turf(get_current_cover())
	if(!cover_turf)
		return FALSE

	if(controller.get_distance_to(cover_turf) > 0)
		if(!move_to_turf(cover_turf))
			end_cover()
			return FALSE

		return TRUE

	enter_cover()
	controller.face_atom(threat)
	return TRUE

/datum/human_ai_brain/proc/halo_covenant_step_away_from_threat(atom/threat, turf/anchor = null, anchor_weight = 0)
	var/turf/threat_turf = halo_covenant_get_cached_threat_turf()
	if(!has_valid_tied_human() || !threat_turf)
		return FALSE
	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller)
		return FALSE

	var/turf/best_destination
	var/best_score = -INFINITY

	for(var/direction in GLOB.cardinals)
		var/turf/destination = controller.get_step_in_dir(direction)
		if(!destination || destination.density)
			continue

		var/score = get_dist(destination, threat_turf) * 3
		if(anchor)
			score -= get_dist(destination, anchor) * anchor_weight

		if(score > best_score)
			best_score = score
			best_destination = destination

	if(!best_destination && anchor && (controller.get_distance_to(anchor) > 0))
		best_destination = anchor

	if(!best_destination)
		return FALSE

	if(!move_to_turf(best_destination))
		return FALSE

	controller.face_atom(threat)
	return TRUE

/datum/human_ai_brain/proc/halo_covenant_move_to_threat(atom/threat)
	var/turf/threat_turf = halo_covenant_get_cached_threat_turf()
	if(!threat_turf)
		return FALSE

	if(!move_to_turf(threat_turf))
		return FALSE

	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller)
		return FALSE
	controller.face_atom(threat)
	return TRUE

/datum/human_ai_brain/proc/halo_covenant_move_to_atom(atom/target, use_cached_threat_turf = FALSE)
	if(!has_valid_tied_human() || !target)
		return FALSE

	var/turf/target_turf = use_cached_threat_turf ? halo_covenant_get_cached_threat_turf() : get_turf(target)
	if(!target_turf)
		return FALSE

	if(!move_to_turf(target_turf))
		return FALSE

	if(!has_valid_tied_human())
		return FALSE

	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller)
		return FALSE
	controller.face_atom(target)
	return TRUE

/datum/human_ai_brain/proc/halo_get_inventory()
	RETURN_TYPE(/datum/human_ai_module/inventory)
	var/datum/human_ai_context/context = create_context()
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	qdel(context)
	return inventory

/datum/human_ai_brain/proc/halo_covenant_has_grenade_equipment()
	return halo_get_inventory()?.has_equipment(HUMAN_AI_GRENADES)

/datum/human_ai_brain/proc/halo_covenant_get_stored_grenade(obj/item/explosive/grenade/excluding = null)
	return halo_get_inventory()?.get_first_equipment_item(HUMAN_AI_GRENADES, excluding)

/datum/human_ai_brain/proc/halo_covenant_clear_both_hands()
	if(!has_valid_tied_human())
		return

	var/datum/human_ai_module/inventory/inventory = halo_get_inventory()
	inventory?.clear_main_hand()
	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller)
		return
	controller.swap_hand()
	inventory?.clear_main_hand()
	controller.swap_hand()

/datum/human_ai_brain/proc/halo_covenant_equip_grenade(obj/item/explosive/grenade/grenade_item)
	return halo_get_inventory()?.equip_item_from_equipment_map(HUMAN_AI_GRENADES, grenade_item)

/datum/human_ai_brain/proc/halo_covenant_get_threat_atom()
	return get_current_target() || get_target_turf()

/datum/human_ai_brain/proc/halo_covenant_get_cached_threat_turf(cache_duration = 0.5 SECONDS)
	var/atom/threat = halo_covenant_get_threat_atom()
	if(!threat)
		halo_cached_threat_turf_time = -1
		halo_cached_threat_atom = null
		halo_cached_threat_turf = null
		return null

	if(halo_cached_threat_atom == threat && halo_cached_threat_turf_time >= (world.time - cache_duration))
		return halo_cached_threat_turf

	halo_cached_threat_atom = threat
	halo_cached_threat_turf = get_turf(threat)
	halo_cached_threat_turf_time = world.time
	return halo_cached_threat_turf

/datum/human_ai_brain/proc/invalidate_halo_runtime_caches()
	halo_cached_ranged_fallback_time = -1
	halo_cached_ranged_fallback_available = null
	halo_cached_squad_anchor_time = -1
	halo_cached_squad_anchor = null
	halo_cached_threat_turf_time = -1
	halo_cached_threat_atom = null
	halo_cached_threat_turf = null
	halo_ranged_fire_backoff_until = 0

/datum/human_ai_brain/proc/halo_runtime_uses_projectile_pressure_controls()
	return halo_unggoy_runtime || halo_sangheili_runtime

/datum/human_ai_brain/proc/halo_apply_navigation_profile(short_step_range = 0, path_retarget_slack = 0, nearby_item_interval = 1 SECONDS)
	apply_navigation_profile(short_step_range, path_retarget_slack)
	var/datum/human_ai_module/inventory/inventory = halo_get_inventory()
	if(inventory)
		inventory.nearby_item_search_interval = nearby_item_interval
		inventory.invalidate_nearby_item_search()

/datum/human_ai_brain/proc/halo_should_suspend_nearby_item_search(queued_projectiles_override = null)
	if(!halo_runtime_uses_projectile_pressure_controls() || !is_in_combat())
		return FALSE

	return halo_is_projectile_queue_soft_limited(queued_projectiles_override)

/datum/human_ai_brain/proc/halo_should_disable_cover_retreat(queued_projectiles_override = null)
	if(!halo_runtime_uses_projectile_pressure_controls() || !is_in_combat())
		return FALSE

	return halo_is_projectile_queue_hard_limited(queued_projectiles_override)

/datum/human_ai_brain/proc/halo_should_defer_ranged_fire(atom/threat = null, queued_projectiles_override = null)
	if(!halo_runtime_uses_projectile_pressure_controls())
		return FALSE

	if(halo_ranged_fire_backoff_until > world.time)
		return TRUE

	if(!threat)
		threat = halo_covenant_get_threat_atom()

	var/datum/human_ai_module/inventory/inventory = halo_get_inventory()
	var/obj/item/weapon/gun/primary_weapon = inventory?.get_primary_weapon()
	if(!has_valid_tied_human() || !primary_weapon || !threat)
		return FALSE

	var/datum/ammo/gun_ammo = halo_get_gun_combat_ammo(primary_weapon)
	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller)
		return FALSE
	if(controller.halo_should_backpressure_projectile_fire(threat, gun_ammo, queued_projectiles_override))
		halo_ranged_fire_backoff_until = world.time + 0.6 SECONDS
		halo_perf_bump_projectile_throttles()
		return TRUE

	// When the AI has only a remembered threat turf, still shed ranged pressure for HALO runtime loops.
	if(!isturf(threat) || !controller.halo_is_ai_only_human() || !halo_is_projectile_pressure_relevant_ammo(gun_ammo))
		return FALSE

	if(!halo_is_projectile_queue_soft_limited(queued_projectiles_override))
		return FALSE

	halo_ranged_fire_backoff_until = world.time + 0.6 SECONDS
	halo_perf_bump_projectile_throttles()
	return TRUE

/datum/human_ai_brain/proc/halo_covenant_weapon_is_cooling(obj/item/weapon/gun/gun = null)
	if(!gun)
		gun = halo_get_inventory()?.get_primary_weapon()

	if(!istype(gun, /obj/item/weapon/gun/energy/plasma))
		return FALSE

	var/obj/item/weapon/gun/energy/plasma/plasma_gun = gun
	return !COOLDOWN_FINISHED(plasma_gun, cooldown) || !COOLDOWN_FINISHED(plasma_gun, manual_cooldown)

/datum/human_ai_brain/proc/halo_covenant_clear_hands()
	if(!has_valid_tied_human())
		return FALSE
	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller)
		return FALSE

	if(!controller.get_active_hand())
		return TRUE

	if(!controller.get_inactive_hand())
		controller.swap_hand()
		return !controller.get_active_hand()

	var/datum/human_ai_module/inventory/inventory = halo_get_inventory()
	inventory?.clear_main_hand()
	if(!controller.get_active_hand())
		return TRUE

	controller.swap_hand()
	if(!controller.get_active_hand())
		return TRUE

	inventory?.clear_main_hand()
	if(!controller.get_active_hand())
		return TRUE

	return FALSE

/datum/human_ai_brain/proc/halo_unggoy_get_squad()
	return get_squad_datum()

/datum/human_ai_brain/proc/halo_unggoy_get_squad_leader()
	return get_squad_leader()

/datum/human_ai_brain/proc/halo_unggoy_has_active_squad_leader()
	var/datum/human_ai_brain/leader = halo_unggoy_get_squad_leader()
	if(!leader)
		return FALSE
	if(leader == src)
		return TRUE
	if(!leader.has_valid_tied_human())
		return FALSE
	var/datum/human_tied_controller/leader_controller = leader.halo_get_controller()
	if(!leader_controller)
		return FALSE
	if(leader_controller.is_dead())
		return FALSE
	if(leader_controller.is_incapacitated())
		return FALSE
	return TRUE

/datum/human_ai_brain/proc/halo_unggoy_get_squad_anchor()
	if(!halo_unggoy_runtime)
		return null

	if(halo_cached_squad_anchor_time == world.time)
		return halo_cached_squad_anchor

	var/datum/human_ai_brain/leader = halo_unggoy_get_squad_leader()
	var/datum/human_tied_controller/leader_controller = leader?.halo_get_controller()
	var/turf/anchor = leader_controller?.get_current_turf()
	if(anchor)
		halo_cached_squad_anchor_time = world.time
		halo_cached_squad_anchor = anchor
		return anchor

	var/list/squad_members = get_squad_members()
	if(!length(squad_members))
		halo_cached_squad_anchor_time = world.time
		halo_cached_squad_anchor = null
		return null

	var/anchor_x = 0
	var/anchor_y = 0
	var/anchor_z = 0
	var/valid_members = 0
	for(var/datum/human_ai_brain/member as anything in squad_members)
		if(!member?.has_valid_tied_human())
			continue
		var/datum/human_tied_controller/member_controller = member.halo_get_controller()
		if(!member_controller)
			continue

		var/turf/member_turf = member_controller.get_current_turf()
		if(!member_turf)
			continue

		if(member_controller.is_dead() || member_controller.is_incapacitated())
			continue

		anchor_x += member_turf.x
		anchor_y += member_turf.y
		anchor_z = member_turf.z
		valid_members++

	if(!valid_members)
		halo_cached_squad_anchor_time = world.time
		halo_cached_squad_anchor = null
		return null

	halo_cached_squad_anchor_time = world.time
	halo_cached_squad_anchor = locate(round(anchor_x / valid_members), round(anchor_y / valid_members), anchor_z)
	return halo_cached_squad_anchor

/datum/human_ai_brain/proc/halo_unggoy_get_health_pct()
	if(!has_valid_tied_human())
		return 1
	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller)
		return 1
	return controller.get_health_ratio()

/datum/human_ai_brain/proc/halo_unggoy_should_panic()
	if(!halo_unggoy_runtime || halo_unggoy_ignore_panic || !has_valid_tied_human())
		return FALSE

	if((halo_unggoy_panic_health_pct > 0) && (halo_unggoy_get_health_pct() <= halo_unggoy_panic_health_pct))
		return TRUE

	if(!halo_unggoy_panics_without_leader || !has_squad() || is_squad_leader())
		return FALSE

	return !halo_unggoy_has_active_squad_leader()

/datum/human_ai_brain/proc/halo_unggoy_should_retreat_on_overheat()
	if(!halo_unggoy_runtime || !halo_unggoy_overheat_retreat || !has_valid_tied_human())
		return FALSE

	if(!halo_covenant_get_threat_atom())
		return FALSE

	return halo_covenant_weapon_is_cooling(halo_get_inventory()?.get_primary_weapon())

/datum/human_ai_brain/proc/halo_unggoy_should_hold_anchor_on_overheat()
	if(!halo_unggoy_should_retreat_on_overheat())
		return FALSE

	return halo_unggoy_has_active_squad_leader()

/datum/human_ai_brain/proc/halo_unggoy_should_flee_on_overheat()
	if(!halo_unggoy_should_retreat_on_overheat())
		return FALSE

	return !halo_unggoy_has_active_squad_leader()

/datum/human_ai_brain/proc/halo_unggoy_should_use_cover_retreat()
	if(halo_should_disable_cover_retreat())
		return FALSE

	return halo_unggoy_should_panic() || halo_unggoy_should_hold_anchor_on_overheat()

/datum/human_ai_brain/proc/halo_unggoy_should_retreat()
	return halo_unggoy_should_panic() || halo_unggoy_should_retreat_on_overheat()

/datum/human_ai_brain/proc/halo_sangheili_find_sword()
	if(QDELETED(halo_sangheili_drawn_sword))
		halo_sangheili_drawn_sword = null
		halo_sangheili_sword_storage_loc = null

	if(istype(halo_sangheili_drawn_sword))
		return halo_sangheili_drawn_sword
	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller)
		return null

	if(istype(controller.get_l_hand(), /obj/item/weapon/covenant/energy_sword))
		return controller.get_l_hand()

	if(istype(controller.get_r_hand(), /obj/item/weapon/covenant/energy_sword))
		return controller.get_r_hand()

	if(istype(controller.get_s_store(), /obj/item/weapon/covenant/energy_sword))
		return controller.get_s_store()

	if(istype(controller.get_belt(), /obj/item/storage))
		return locate(/obj/item/weapon/covenant/energy_sword) in controller.get_belt()

	if(halo_sangheili_melee_committed)
		halo_sangheili_clear_melee_commit()

/datum/human_ai_brain/proc/halo_sangheili_primary_weapon_unavailable()
	if(!has_valid_tied_human())
		return TRUE

	var/datum/human_ai_module/inventory/inventory = halo_get_inventory()
	var/obj/item/weapon/gun/primary_weapon = inventory?.get_primary_weapon()
	if(!primary_weapon)
		return TRUE

	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller || !controller.can_ai_use_weapon(primary_weapon))
		return TRUE

	if(halo_covenant_weapon_is_cooling(primary_weapon))
		return TRUE

	return should_reload()

/datum/human_ai_brain/proc/halo_sangheili_has_usable_ranged_fallback()
	if(!halo_sangheili_runtime)
		return FALSE

	if(halo_cached_ranged_fallback_time == world.time)
		return halo_cached_ranged_fallback_available

	var/datum/human_ai_module/inventory/inventory = halo_get_inventory()
	var/obj/item/weapon/gun/fallback_weapon = halo_sangheili_committed_primary_weapon || inventory?.get_primary_weapon()
	if(!has_valid_tied_human() || !fallback_weapon || QDELETED(fallback_weapon))
		halo_cached_ranged_fallback_time = world.time
		halo_cached_ranged_fallback_available = FALSE
		return FALSE

	if(!halo_sangheili_owns_item(fallback_weapon))
		halo_cached_ranged_fallback_time = world.time
		halo_cached_ranged_fallback_available = FALSE
		return FALSE

	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller || !controller.can_ai_use_weapon(fallback_weapon))
		halo_cached_ranged_fallback_time = world.time
		halo_cached_ranged_fallback_available = FALSE
		return FALSE

	if(fallback_weapon.has_ammunition())
		halo_cached_ranged_fallback_time = world.time
		halo_cached_ranged_fallback_available = TRUE
		return TRUE

	halo_cached_ranged_fallback_time = world.time
	halo_cached_ranged_fallback_available = !isnull(inventory?.find_ammo_for_weapon(fallback_weapon))
	return halo_cached_ranged_fallback_available

/datum/human_ai_brain/proc/halo_sangheili_should_preserve_drawn_sword()
	if(!halo_sangheili_find_sword())
		return FALSE

	if(halo_sangheili_sword_only)
		return TRUE

	return !halo_sangheili_has_usable_ranged_fallback()

/datum/human_ai_brain/proc/halo_sangheili_should_use_sword_mode(atom/threat = null)
	if(!halo_sangheili_runtime)
		return FALSE

	if(!threat)
		threat = halo_covenant_get_threat_atom()

	if(!has_valid_tied_human() || !threat)
		return FALSE

	if(!halo_sangheili_has_sword && !halo_sangheili_sword_only)
		return FALSE

	if(!halo_sangheili_find_sword())
		return FALSE

	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller)
		return FALSE
	var/distance_to_threat = controller.get_distance_to(threat)
	if(distance_to_threat > halo_sangheili_sword_charge_range)
		return FALSE

	if(halo_sangheili_sword_only)
		return TRUE

	if(distance_to_threat <= halo_sangheili_unarmed_commit_range)
		return TRUE

	return halo_sangheili_primary_weapon_unavailable()

/datum/human_ai_brain/proc/halo_sangheili_should_sword_charge(atom/charge_target = null)
	return halo_sangheili_should_use_sword_mode(charge_target)

/datum/human_ai_brain/proc/halo_sangheili_should_overheat_response(atom/threat = null)
	if(!halo_sangheili_runtime)
		return FALSE

	if(!threat)
		threat = halo_covenant_get_threat_atom()

	if(!has_valid_tied_human() || !threat)
		return FALSE

	if(!halo_covenant_weapon_is_cooling(halo_get_inventory()?.get_primary_weapon()))
		return FALSE

	if(halo_sangheili_should_sword_charge(threat))
		return FALSE

	return TRUE

/datum/human_ai_brain/proc/halo_sangheili_should_unarmed_commit(atom/threat = null)
	if(!halo_sangheili_runtime)
		return FALSE

	if(!threat)
		threat = halo_covenant_get_threat_atom()

	if(!has_valid_tied_human() || !threat)
		return FALSE

	var/datum/human_tied_controller/controller = halo_get_controller()
	return controller && (controller.get_distance_to(threat) <= halo_sangheili_unarmed_commit_range)

/datum/human_ai_brain/proc/on_halo_sangheili_sword_dropped()
	SIGNAL_HANDLER

	if(halo_sangheili_drawn_sword)
		UnregisterSignal(halo_sangheili_drawn_sword, COMSIG_ITEM_DROPPED)

	invalidate_halo_runtime_caches()
	halo_sangheili_drawn_sword = null
	halo_sangheili_sword_storage_loc = null
	halo_sangheili_clear_melee_commit()

/datum/human_ai_brain/proc/halo_sangheili_get_commit_action_blacklist()
	var/static/list/commit_action_blacklist = list(
		/datum/ai_action/fire_at_target,
		/datum/ai_action/keep_distance,
		/datum/ai_action/reload,
		/datum/ai_action/select_primary,
		/datum/ai_action/machinegunner_nest,
		/datum/ai_action/sniper_nest,
	)
	return commit_action_blacklist

/datum/human_ai_brain/proc/halo_sangheili_cancel_committed_actions()
	cancel_ongoing_actions_by_type(halo_sangheili_get_commit_action_blacklist())

/datum/human_ai_brain/proc/halo_sangheili_owns_item(obj/item/item)
	var/datum/human_tied_controller/controller = halo_get_controller()
	return controller?.is_item_equipped_or_in_direct_storage(item)

/datum/human_ai_brain/proc/halo_sangheili_begin_melee_commit(obj/item/weapon/covenant/energy_sword/sword)
	if(halo_sangheili_melee_committed)
		return TRUE

	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!has_valid_tied_human() || !sword || !controller?.is_item_equipped_or_held(sword))
		return FALSE

	halo_sangheili_melee_committed = TRUE
	var/datum/human_ai_module/inventory/inventory = halo_get_inventory()
	halo_sangheili_committed_primary_weapon = inventory?.get_primary_weapon()
	halo_sangheili_committed_tried_reload = has_tried_reload()
	halo_sangheili_committed_ignore_looting = inventory?.is_looting_disabled()
	invalidate_halo_runtime_caches()

	if(inventory?.get_primary_weapon())
		inventory.set_primary_weapon(null)

	mark_tried_reload()
	inventory?.set_looting_disabled(TRUE)

	var/list/commit_action_blacklist = halo_sangheili_get_commit_action_blacklist()
	add_action_blacklist(commit_action_blacklist)

	halo_sangheili_cancel_committed_actions()
	return TRUE

/datum/human_ai_brain/proc/halo_sangheili_restore_ranged_state(atom/threat = null)
	if(halo_sangheili_sword_only || !halo_sangheili_melee_committed)
		return FALSE

	if(!halo_sangheili_has_usable_ranged_fallback())
		return FALSE

	if(halo_sangheili_should_use_sword_mode(threat))
		return FALSE

	if(halo_sangheili_holster_sword())
		return TRUE

	halo_sangheili_clear_melee_commit()
	return TRUE

/datum/human_ai_brain/proc/halo_sangheili_clear_melee_commit(restore_firearm = TRUE)
	if(!halo_sangheili_melee_committed && !halo_sangheili_committed_primary_weapon)
		return

	var/obj/item/weapon/gun/committed_primary_weapon = halo_sangheili_committed_primary_weapon
	var/committed_tried_reload = halo_sangheili_committed_tried_reload
	var/committed_ignore_looting = halo_sangheili_committed_ignore_looting

	halo_sangheili_melee_committed = FALSE
	halo_sangheili_committed_primary_weapon = null
	halo_sangheili_committed_tried_reload = FALSE
	halo_sangheili_committed_ignore_looting = FALSE
	invalidate_halo_runtime_caches()

	remove_action_blacklist(halo_sangheili_get_commit_action_blacklist())

	set_tried_reload(committed_tried_reload)
	var/datum/human_ai_module/inventory/inventory = halo_get_inventory()
	inventory?.set_looting_disabled(committed_ignore_looting)

	if(!restore_firearm || inventory?.get_primary_weapon() || !committed_primary_weapon || !halo_sangheili_owns_item(committed_primary_weapon))
		return

	inventory.set_primary_weapon(committed_primary_weapon)

/datum/human_ai_brain/proc/halo_sangheili_should_keep_sword_drawn()
	if(halo_sangheili_should_preserve_drawn_sword())
		return TRUE

	if(!halo_sangheili_melee_committed)
		return FALSE

	return halo_sangheili_should_use_sword_mode()

/datum/human_ai_brain/proc/halo_sangheili_track_drawn_sword(obj/item/weapon/covenant/energy_sword/sword, storage_loc = null)
	if(!sword)
		return null

	if(halo_sangheili_drawn_sword && halo_sangheili_drawn_sword != sword)
		UnregisterSignal(halo_sangheili_drawn_sword, COMSIG_ITEM_DROPPED)

	halo_sangheili_drawn_sword = sword
	if(storage_loc)
		halo_sangheili_sword_storage_loc = storage_loc
	RegisterSignal(sword, COMSIG_ITEM_DROPPED, PROC_REF(on_halo_sangheili_sword_dropped), override = TRUE)
	return sword

/datum/human_ai_brain/proc/halo_sangheili_try_store_sword(obj/item/weapon/covenant/energy_sword/sword, storage_loc)
	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!has_valid_tied_human() || !sword || !controller?.is_item_equipped_or_held(sword))
		return FALSE

	switch(storage_loc)
		if("belt")
			if(istype(controller.get_belt(), /obj/item/storage))
				var/obj/item/storage/belt_storage = controller.get_belt()
				return controller.attempt_item_insertion(belt_storage, sword)
		if("suit_slot")
			if(!controller.get_s_store())
				return controller.equip_to_slot_if_possible(sword, WEAR_J_STORE, TRUE)

	return FALSE

/datum/human_ai_brain/proc/halo_sangheili_draw_sword()
	if(!has_valid_tied_human())
		return null
	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller)
		return null

	var/obj/item/weapon/covenant/energy_sword/sword = halo_sangheili_find_sword()
	if(!sword)
		return null

	var/storage_loc = halo_sangheili_sword_storage_loc

	if(sword == controller.get_l_hand() || sword == controller.get_r_hand())
		if(controller.get_inactive_hand() == sword)
			controller.swap_hand()
		halo_sangheili_track_drawn_sword(sword, storage_loc)
		halo_sangheili_begin_melee_commit(sword)
		if(!sword.activated && !sword.nonfunctional)
			controller.halo_set_sword_activation_state(sword, TRUE)
		halo_get_inventory()?.ensure_primary_hand(sword)
		return sword

	if(!halo_covenant_clear_hands())
		return null

	if(sword == controller.get_s_store())
		storage_loc = "suit_slot"
		controller.u_equip(sword)
	else if(sword.loc == controller.get_belt())
		storage_loc = "belt"
		var/obj/item/storage/belt_storage = controller.get_belt()
		controller.remove_from_storage(belt_storage, sword)
	else if(istype(sword.loc, /obj/item/storage))
		var/obj/item/storage/storage = sword.loc
		controller.remove_from_storage(storage, sword)

	if(!controller.is_item_equipped_or_held(sword))
		return null

	if(!controller.put_in_hands(sword, FALSE))
		return null

	halo_sangheili_track_drawn_sword(sword, storage_loc)
	halo_sangheili_begin_melee_commit(sword)

	if(!sword.activated && !sword.nonfunctional)
		controller.halo_set_sword_activation_state(sword, TRUE)
	halo_get_inventory()?.ensure_primary_hand(sword)
	return sword

/datum/human_ai_brain/proc/halo_sangheili_holster_sword(force = FALSE)
	var/obj/item/weapon/covenant/energy_sword/sword = halo_sangheili_drawn_sword || halo_sangheili_find_sword()
	if(!has_valid_tied_human() || !sword)
		on_halo_sangheili_sword_dropped()
		return TRUE

	if(!force && halo_sangheili_should_preserve_drawn_sword())
		return FALSE

	var/datum/human_tied_controller/controller = halo_get_controller()
	if(!controller)
		on_halo_sangheili_sword_dropped()
		return TRUE

	if(sword.activated)
		controller.halo_set_sword_activation_state(sword, FALSE)

	if(!controller.is_item_equipped_or_held(sword))
		on_halo_sangheili_sword_dropped()
		return TRUE

	var/storage_loc = halo_sangheili_sword_storage_loc || "belt"
	var/success = halo_sangheili_try_store_sword(sword, storage_loc)
	if(!success && (storage_loc != "belt"))
		success = halo_sangheili_try_store_sword(sword, "belt")
	if(!success && (storage_loc != "suit_slot"))
		success = halo_sangheili_try_store_sword(sword, "suit_slot")

	if(success)
		on_halo_sangheili_sword_dropped()
		return TRUE

	return FALSE
