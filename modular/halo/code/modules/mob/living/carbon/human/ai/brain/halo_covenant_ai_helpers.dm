/datum/human_ai_module/halo_covenant
	module_id = "halo_covenant"
	var/cached_threat_turf_time = -1
	var/atom/cached_threat_atom
	var/turf/cached_threat_turf
	var/ranged_fire_backoff_until = 0

/datum/human_ai_module/halo_unggoy
	module_id = "halo_unggoy"
	required_module_types = list(/datum/human_ai_module/halo_covenant, /datum/human_ai_module/squad)
	var/runtime = FALSE
	var/role
	var/panic_health_pct = 0
	var/panics_without_leader = FALSE
	var/ignore_panic = FALSE
	var/overheat_retreat = TRUE
	var/suicide_bomber = FALSE
	var/suicide_prime_range = 5
	var/cached_squad_anchor_time = -1
	var/turf/cached_squad_anchor

/datum/human_ai_module/halo_sangheili
	module_id = "halo_sangheili"
	required_module_types = list(/datum/human_ai_module/halo_covenant, /datum/human_ai_module/melee, /datum/human_ai_module/inventory, /datum/human_ai_module/guns)
	var/runtime = FALSE
	var/has_sword = FALSE
	var/sword_only = FALSE
	var/sword_charge_range = 5
	var/unarmed_commit_range = 2
	var/obj/item/weapon/covenant/energy_sword/drawn_sword
	var/sword_storage_loc
	var/melee_committed = FALSE
	var/obj/item/weapon/gun/committed_primary_weapon
	var/committed_tried_reload = FALSE
	var/committed_ignore_looting = FALSE
	var/cached_ranged_fallback_time = -1
	var/cached_ranged_fallback_available

/datum/human_ai_module_config/get_supported_module_types()
	. = ..()
	if(!(/datum/human_ai_module/halo_covenant in .))
		. += /datum/human_ai_module/halo_covenant
	if(!(/datum/human_ai_module/halo_unggoy in .))
		. += /datum/human_ai_module/halo_unggoy
	if(!(/datum/human_ai_module/halo_sangheili in .))
		. += /datum/human_ai_module/halo_sangheili

/datum/human_ai_brain/proc/halo_get_covenant_module()
	RETURN_TYPE(/datum/human_ai_module/halo_covenant)
	return get_module(/datum/human_ai_module/halo_covenant)

/datum/human_ai_brain/proc/halo_get_unggoy_module()
	RETURN_TYPE(/datum/human_ai_module/halo_unggoy)
	var/datum/human_ai_module/halo_unggoy/unggoy_module = get_module(/datum/human_ai_module/halo_unggoy)
	if(!unggoy_module)
		unggoy_module = module_config?.setup_module_by_type(src, /datum/human_ai_module/halo_unggoy)
	return unggoy_module

/datum/human_ai_brain/proc/halo_get_sangheili_module()
	RETURN_TYPE(/datum/human_ai_module/halo_sangheili)
	var/datum/human_ai_module/halo_sangheili/sangheili_module = get_module(/datum/human_ai_module/halo_sangheili)
	if(!sangheili_module)
		sangheili_module = module_config?.setup_module_by_type(src, /datum/human_ai_module/halo_sangheili)
	return sangheili_module

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
	invalidate_runtime_caches()
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
	if(brain.halo_sangheili_has_melee_commit() || brain.halo_sangheili_get_drawn_sword())
		brain.halo_sangheili_holster_sword()

/datum/human_ai_module/halo_covenant/proc/get_controller()
	RETURN_TYPE(/datum/human_tied_controller)
	return context?.controller

/datum/human_ai_module/halo_covenant/proc/get_inventory()
	RETURN_TYPE(/datum/human_ai_module/inventory)
	return context?.get_module(/datum/human_ai_module/inventory)

/datum/human_ai_module/halo_covenant/proc/can_run_movement_action(block_active_grenade = FALSE)
	if(!brain.is_in_combat() || !brain.can_move_for_action())
		return FALSE
	if(block_active_grenade && brain.has_active_grenade())
		return FALSE
	return TRUE

/datum/human_ai_module/halo_covenant/proc/has_pending_cover()
	return brain.has_pending_cover()

/datum/human_ai_module/halo_covenant/proc/has_cover()
	return brain.has_cover()

/datum/human_ai_module/halo_covenant/proc/end_cover()
	brain.end_cover()

/datum/human_ai_module/halo_covenant/proc/try_cover_retreat(atom/threat)
	if(!brain.get_cover_module())
		return FALSE
	var/datum/human_tied_controller/controller = get_controller()
	if(!controller)
		return FALSE

	if(!brain.get_current_cover())
		brain.try_cover(controller.get_angle_from(threat), threat)

	var/turf/cover_turf = get_turf(brain.get_current_cover())
	if(!cover_turf)
		return FALSE

	if(controller.get_distance_to(cover_turf) > 0)
		if(!brain.move_to_turf(cover_turf))
			brain.end_cover()
			return FALSE

		return TRUE

	brain.enter_cover()
	controller.face_atom(threat)
	return TRUE

/datum/human_ai_module/halo_covenant/proc/step_away_from_threat(atom/threat, turf/anchor = null, anchor_weight = 0)
	var/turf/threat_turf = get_cached_threat_turf()
	if(!brain.has_valid_tied_human() || !threat_turf)
		return FALSE
	var/datum/human_tied_controller/controller = get_controller()
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

	if(!brain.move_to_turf(best_destination))
		return FALSE

	controller.face_atom(threat)
	return TRUE

/datum/human_ai_module/halo_covenant/proc/move_to_threat(atom/threat)
	var/turf/threat_turf = get_cached_threat_turf()
	if(!threat_turf)
		return FALSE

	if(!brain.move_to_turf(threat_turf))
		return FALSE

	var/datum/human_tied_controller/controller = get_controller()
	if(!controller)
		return FALSE
	controller.face_atom(threat)
	return TRUE

/datum/human_ai_module/halo_covenant/proc/move_to_atom(atom/target, use_cached_threat_turf = FALSE)
	if(!brain.has_valid_tied_human() || !target)
		return FALSE

	var/turf/target_turf = use_cached_threat_turf ? get_cached_threat_turf() : get_turf(target)
	if(!target_turf)
		return FALSE

	if(!brain.move_to_turf(target_turf))
		return FALSE

	if(!brain.has_valid_tied_human())
		return FALSE

	var/datum/human_tied_controller/controller = get_controller()
	if(!controller)
		return FALSE
	controller.face_atom(target)
	return TRUE

/datum/human_ai_module/halo_covenant/proc/has_grenade_equipment()
	return get_inventory()?.has_equipment(HUMAN_AI_GRENADES)

/datum/human_ai_module/halo_covenant/proc/get_stored_grenade(obj/item/explosive/grenade/excluding = null)
	return get_inventory()?.get_first_equipment_item(HUMAN_AI_GRENADES, excluding)

/datum/human_ai_module/halo_covenant/proc/clear_both_hands()
	if(!brain.has_valid_tied_human())
		return

	var/datum/human_ai_module/inventory/inventory = get_inventory()
	inventory?.clear_main_hand()
	var/datum/human_tied_controller/controller = get_controller()
	if(!controller)
		return
	controller.swap_hand()
	inventory?.clear_main_hand()
	controller.swap_hand()

/datum/human_ai_module/halo_covenant/proc/equip_grenade(obj/item/explosive/grenade/grenade_item)
	return get_inventory()?.equip_item_from_equipment_map(HUMAN_AI_GRENADES, grenade_item)

/datum/human_ai_module/halo_covenant/proc/get_threat_atom()
	return brain.get_current_target() || brain.get_target_turf()

/datum/human_ai_module/halo_covenant/proc/get_cached_threat_turf(cache_duration = 0.5 SECONDS)
	var/atom/threat = get_threat_atom()
	if(!threat)
		cached_threat_turf_time = -1
		cached_threat_atom = null
		cached_threat_turf = null
		return null

	if(cached_threat_atom == threat && cached_threat_turf_time >= (world.time - cache_duration))
		return cached_threat_turf

	cached_threat_atom = threat
	cached_threat_turf = get_turf(threat)
	cached_threat_turf_time = world.time
	return cached_threat_turf

/datum/human_ai_module/halo_covenant/proc/invalidate_runtime_caches()
	cached_threat_turf_time = -1
	cached_threat_atom = null
	cached_threat_turf = null
	ranged_fire_backoff_until = 0

/datum/human_ai_module/halo_covenant/proc/uses_projectile_pressure_controls()
	return brain.halo_unggoy_is_active() || brain.halo_sangheili_is_active()

/datum/human_ai_module/halo_covenant/proc/apply_navigation_profile(short_step_range = 0, path_retarget_slack = 0, nearby_item_interval = 1 SECONDS)
	brain.apply_navigation_profile(short_step_range, path_retarget_slack)
	var/datum/human_ai_module/inventory/inventory = get_inventory()
	if(inventory)
		inventory.nearby_item_search_interval = nearby_item_interval
		inventory.invalidate_nearby_item_search()

/datum/human_ai_module/halo_covenant/proc/should_suspend_nearby_item_search(queued_projectiles_override = null)
	if(!uses_projectile_pressure_controls() || !brain.is_in_combat())
		return FALSE

	return halo_is_projectile_queue_soft_limited(queued_projectiles_override)

/datum/human_ai_module/halo_covenant/proc/should_disable_cover_retreat(queued_projectiles_override = null)
	if(!uses_projectile_pressure_controls() || !brain.is_in_combat())
		return FALSE

	return halo_is_projectile_queue_hard_limited(queued_projectiles_override)

/datum/human_ai_module/halo_covenant/proc/should_defer_ranged_fire(atom/threat = null, queued_projectiles_override = null)
	if(!uses_projectile_pressure_controls())
		return FALSE

	if(ranged_fire_backoff_until > world.time)
		return TRUE

	if(!threat)
		threat = get_threat_atom()

	var/datum/human_ai_module/inventory/inventory = get_inventory()
	var/obj/item/weapon/gun/primary_weapon = inventory?.get_primary_weapon()
	if(!brain.has_valid_tied_human() || !primary_weapon || !threat)
		return FALSE

	var/datum/ammo/gun_ammo = halo_get_gun_combat_ammo(primary_weapon)
	var/datum/human_tied_controller/controller = get_controller()
	if(!controller)
		return FALSE
	if(controller.halo_should_backpressure_projectile_fire(threat, gun_ammo, queued_projectiles_override))
		ranged_fire_backoff_until = world.time + 0.6 SECONDS
		halo_perf_bump_projectile_throttles()
		return TRUE

	// When the AI has only a remembered threat turf, still shed ranged pressure for HALO runtime loops.
	if(!isturf(threat) || !controller.halo_is_ai_only_human() || !halo_is_projectile_pressure_relevant_ammo(gun_ammo))
		return FALSE

	if(!halo_is_projectile_queue_soft_limited(queued_projectiles_override))
		return FALSE

	ranged_fire_backoff_until = world.time + 0.6 SECONDS
	halo_perf_bump_projectile_throttles()
	return TRUE

/datum/human_ai_module/halo_covenant/proc/weapon_is_cooling(obj/item/weapon/gun/gun = null)
	if(!gun)
		gun = get_inventory()?.get_primary_weapon()

	if(!istype(gun, /obj/item/weapon/gun/energy/plasma))
		return FALSE

	var/obj/item/weapon/gun/energy/plasma/plasma_gun = gun
	return !COOLDOWN_FINISHED(plasma_gun, cooldown) || !COOLDOWN_FINISHED(plasma_gun, manual_cooldown)

/datum/human_ai_module/halo_covenant/proc/clear_hands()
	if(!brain.has_valid_tied_human())
		return FALSE
	var/datum/human_tied_controller/controller = get_controller()
	if(!controller)
		return FALSE

	if(!controller.get_active_hand())
		return TRUE

	if(!controller.get_inactive_hand())
		controller.swap_hand()
		return !controller.get_active_hand()

	var/datum/human_ai_module/inventory/inventory = get_inventory()
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

/datum/human_ai_brain/proc/halo_covenant_can_run_movement_action(block_active_grenade = FALSE)
	return halo_get_covenant_module()?.can_run_movement_action(block_active_grenade)

/datum/human_ai_brain/proc/halo_covenant_has_pending_cover()
	return halo_get_covenant_module()?.has_pending_cover()

/datum/human_ai_brain/proc/halo_covenant_has_cover()
	return halo_get_covenant_module()?.has_cover()

/datum/human_ai_brain/proc/halo_covenant_end_cover()
	halo_get_covenant_module()?.end_cover()

/datum/human_ai_brain/proc/halo_covenant_try_cover_retreat(atom/threat)
	return halo_get_covenant_module()?.try_cover_retreat(threat)

/datum/human_ai_brain/proc/halo_covenant_step_away_from_threat(atom/threat, turf/anchor = null, anchor_weight = 0)
	return halo_get_covenant_module()?.step_away_from_threat(threat, anchor, anchor_weight)

/datum/human_ai_brain/proc/halo_covenant_move_to_threat(atom/threat)
	return halo_get_covenant_module()?.move_to_threat(threat)

/datum/human_ai_brain/proc/halo_covenant_move_to_atom(atom/target, use_cached_threat_turf = FALSE)
	return halo_get_covenant_module()?.move_to_atom(target, use_cached_threat_turf)

/datum/human_ai_brain/proc/halo_get_inventory()
	RETURN_TYPE(/datum/human_ai_module/inventory)
	return halo_get_covenant_module()?.get_inventory()

/datum/human_ai_brain/proc/halo_covenant_has_grenade_equipment()
	return halo_get_covenant_module()?.has_grenade_equipment()

/datum/human_ai_brain/proc/halo_covenant_get_stored_grenade(obj/item/explosive/grenade/excluding = null)
	return halo_get_covenant_module()?.get_stored_grenade(excluding)

/datum/human_ai_brain/proc/halo_covenant_clear_both_hands()
	halo_get_covenant_module()?.clear_both_hands()

/datum/human_ai_brain/proc/halo_covenant_equip_grenade(obj/item/explosive/grenade/grenade_item)
	return halo_get_covenant_module()?.equip_grenade(grenade_item)

/datum/human_ai_brain/proc/halo_covenant_get_threat_atom()
	return halo_get_covenant_module()?.get_threat_atom()

/datum/human_ai_brain/proc/halo_covenant_get_cached_threat_turf(cache_duration = 0.5 SECONDS)
	return halo_get_covenant_module()?.get_cached_threat_turf(cache_duration)

/datum/human_ai_brain/proc/invalidate_halo_runtime_caches()
	halo_get_covenant_module()?.invalidate_runtime_caches()
	halo_get_unggoy_module()?.invalidate_runtime_caches()
	halo_get_sangheili_module()?.invalidate_runtime_caches()

/datum/human_ai_brain/proc/halo_runtime_uses_projectile_pressure_controls()
	return halo_get_covenant_module()?.uses_projectile_pressure_controls()

/datum/human_ai_brain/proc/halo_apply_navigation_profile(short_step_range = 0, path_retarget_slack = 0, nearby_item_interval = 1 SECONDS)
	halo_get_covenant_module()?.apply_navigation_profile(short_step_range, path_retarget_slack, nearby_item_interval)

/datum/human_ai_brain/proc/halo_should_suspend_nearby_item_search(queued_projectiles_override = null)
	return halo_get_covenant_module()?.should_suspend_nearby_item_search(queued_projectiles_override)

/datum/human_ai_brain/proc/halo_should_disable_cover_retreat(queued_projectiles_override = null)
	return halo_get_covenant_module()?.should_disable_cover_retreat(queued_projectiles_override)

/datum/human_ai_brain/proc/halo_should_defer_ranged_fire(atom/threat = null, queued_projectiles_override = null)
	return halo_get_covenant_module()?.should_defer_ranged_fire(threat, queued_projectiles_override)

/datum/human_ai_brain/proc/halo_covenant_weapon_is_cooling(obj/item/weapon/gun/gun = null)
	return halo_get_covenant_module()?.weapon_is_cooling(gun)

/datum/human_ai_brain/proc/halo_covenant_clear_hands()
	return halo_get_covenant_module()?.clear_hands()

/datum/human_ai_module/halo_unggoy/proc/configure(new_role, new_panic_health_pct = 0, new_panics_without_leader = FALSE, new_ignore_panic = FALSE, new_overheat_retreat = TRUE)
	runtime = TRUE
	role = new_role
	panic_health_pct = new_panic_health_pct
	panics_without_leader = new_panics_without_leader
	ignore_panic = new_ignore_panic
	overheat_retreat = new_overheat_retreat
	invalidate_runtime_caches()

/datum/human_ai_module/halo_unggoy/proc/configure_suicide_bomber(new_suicide_prime_range = 5)
	runtime = TRUE
	suicide_bomber = TRUE
	suicide_prime_range = new_suicide_prime_range

/datum/human_ai_module/halo_unggoy/proc/invalidate_runtime_caches()
	cached_squad_anchor_time = -1
	cached_squad_anchor = null

/datum/human_ai_module/halo_unggoy/proc/is_active()
	return runtime

/datum/human_ai_module/halo_unggoy/proc/is_suicide_bomber()
	return suicide_bomber

/datum/human_ai_module/halo_unggoy/proc/get_suicide_prime_range()
	return suicide_prime_range

/datum/human_ai_module/halo_unggoy/proc/get_squad()
	return brain.get_squad_datum()

/datum/human_ai_module/halo_unggoy/proc/get_squad_leader()
	return brain.get_squad_leader()

/datum/human_ai_module/halo_unggoy/proc/has_active_squad_leader()
	var/datum/human_ai_brain/leader = get_squad_leader()
	if(!leader)
		return FALSE
	if(leader == brain)
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

/datum/human_ai_module/halo_unggoy/proc/get_squad_anchor()
	if(!runtime)
		return null

	if(cached_squad_anchor_time == world.time)
		return cached_squad_anchor

	var/datum/human_ai_brain/leader = get_squad_leader()
	var/datum/human_tied_controller/leader_controller = leader?.halo_get_controller()
	var/turf/anchor = leader_controller?.get_current_turf()
	if(anchor)
		cached_squad_anchor_time = world.time
		cached_squad_anchor = anchor
		return anchor

	var/list/squad_members = brain.get_squad_members()
	if(!length(squad_members))
		cached_squad_anchor_time = world.time
		cached_squad_anchor = null
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
		cached_squad_anchor_time = world.time
		cached_squad_anchor = null
		return null

	cached_squad_anchor_time = world.time
	cached_squad_anchor = locate(round(anchor_x / valid_members), round(anchor_y / valid_members), anchor_z)
	return cached_squad_anchor

/datum/human_ai_module/halo_unggoy/proc/get_health_pct()
	if(!brain.has_valid_tied_human())
		return 1
	var/datum/human_tied_controller/controller = brain.halo_get_controller()
	if(!controller)
		return 1
	return controller.get_health_ratio()

/datum/human_ai_module/halo_unggoy/proc/should_panic()
	if(!runtime || ignore_panic || !brain.has_valid_tied_human())
		return FALSE

	if((panic_health_pct > 0) && (get_health_pct() <= panic_health_pct))
		return TRUE

	if(!panics_without_leader || !brain.has_squad() || brain.is_squad_leader())
		return FALSE

	return !has_active_squad_leader()

/datum/human_ai_module/halo_unggoy/proc/should_retreat_on_overheat()
	if(!runtime || !overheat_retreat || !brain.has_valid_tied_human())
		return FALSE

	if(!brain.halo_covenant_get_threat_atom())
		return FALSE

	return brain.halo_covenant_weapon_is_cooling(brain.halo_get_inventory()?.get_primary_weapon())

/datum/human_ai_module/halo_unggoy/proc/should_hold_anchor_on_overheat()
	if(!should_retreat_on_overheat())
		return FALSE

	return has_active_squad_leader()

/datum/human_ai_module/halo_unggoy/proc/should_flee_on_overheat()
	if(!should_retreat_on_overheat())
		return FALSE

	return !has_active_squad_leader()

/datum/human_ai_module/halo_unggoy/proc/should_use_cover_retreat()
	if(brain.halo_should_disable_cover_retreat())
		return FALSE

	return should_panic() || should_hold_anchor_on_overheat()

/datum/human_ai_module/halo_unggoy/proc/should_retreat()
	return should_panic() || should_retreat_on_overheat()

/datum/human_ai_brain/proc/halo_configure_unggoy_behavior(role, panic_health_pct = 0, panics_without_leader = FALSE, ignore_panic = FALSE, overheat_retreat = TRUE)
	halo_get_unggoy_module()?.configure(role, panic_health_pct, panics_without_leader, ignore_panic, overheat_retreat)

/datum/human_ai_brain/proc/halo_configure_unggoy_suicide_bomber(suicide_prime_range = 5)
	halo_get_unggoy_module()?.configure_suicide_bomber(suicide_prime_range)

/datum/human_ai_brain/proc/halo_unggoy_is_active()
	return halo_get_unggoy_module()?.is_active()

/datum/human_ai_brain/proc/halo_unggoy_is_suicide_bomber()
	return halo_get_unggoy_module()?.is_suicide_bomber()

/datum/human_ai_brain/proc/halo_unggoy_get_suicide_prime_range()
	return halo_get_unggoy_module()?.get_suicide_prime_range()

/datum/human_ai_brain/proc/halo_unggoy_get_squad()
	return halo_get_unggoy_module()?.get_squad()

/datum/human_ai_brain/proc/halo_unggoy_get_squad_leader()
	return halo_get_unggoy_module()?.get_squad_leader()

/datum/human_ai_brain/proc/halo_unggoy_has_active_squad_leader()
	return halo_get_unggoy_module()?.has_active_squad_leader()

/datum/human_ai_brain/proc/halo_unggoy_get_squad_anchor()
	return halo_get_unggoy_module()?.get_squad_anchor()

/datum/human_ai_brain/proc/halo_unggoy_get_health_pct()
	return halo_get_unggoy_module()?.get_health_pct()

/datum/human_ai_brain/proc/halo_unggoy_should_panic()
	return halo_get_unggoy_module()?.should_panic()

/datum/human_ai_brain/proc/halo_unggoy_should_retreat_on_overheat()
	return halo_get_unggoy_module()?.should_retreat_on_overheat()

/datum/human_ai_brain/proc/halo_unggoy_should_hold_anchor_on_overheat()
	return halo_get_unggoy_module()?.should_hold_anchor_on_overheat()

/datum/human_ai_brain/proc/halo_unggoy_should_flee_on_overheat()
	return halo_get_unggoy_module()?.should_flee_on_overheat()

/datum/human_ai_brain/proc/halo_unggoy_should_use_cover_retreat()
	return halo_get_unggoy_module()?.should_use_cover_retreat()

/datum/human_ai_brain/proc/halo_unggoy_should_retreat()
	return halo_get_unggoy_module()?.should_retreat()

/datum/human_ai_module/halo_sangheili/proc/configure(new_has_sword = FALSE, new_sword_only = FALSE, new_sword_charge_range = 5, new_unarmed_commit_range = 2)
	runtime = TRUE
	has_sword = new_has_sword
	sword_only = new_sword_only
	sword_charge_range = new_sword_charge_range
	unarmed_commit_range = new_unarmed_commit_range
	invalidate_runtime_caches()

/datum/human_ai_module/halo_sangheili/proc/invalidate_runtime_caches()
	cached_ranged_fallback_time = -1
	cached_ranged_fallback_available = null

/datum/human_ai_module/halo_sangheili/proc/is_active()
	return runtime

/datum/human_ai_module/halo_sangheili/proc/is_sword_only()
	return sword_only

/datum/human_ai_module/halo_sangheili/proc/has_melee_commit()
	return melee_committed

/datum/human_ai_module/halo_sangheili/proc/get_drawn_sword()
	return drawn_sword

/datum/human_ai_module/halo_sangheili/proc/find_sword()
	if(QDELETED(drawn_sword))
		drawn_sword = null
		sword_storage_loc = null

	if(istype(drawn_sword))
		return drawn_sword
	var/datum/human_tied_controller/controller = brain.halo_get_controller()
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

	if(melee_committed)
		clear_melee_commit()

/datum/human_ai_module/halo_sangheili/proc/primary_weapon_unavailable()
	if(!brain.has_valid_tied_human())
		return TRUE

	var/datum/human_ai_module/inventory/inventory = brain.halo_get_inventory()
	var/obj/item/weapon/gun/primary_weapon = inventory?.get_primary_weapon()
	if(!primary_weapon)
		return TRUE

	var/datum/human_tied_controller/controller = brain.halo_get_controller()
	if(!controller || !controller.can_ai_use_weapon(primary_weapon))
		return TRUE

	if(brain.halo_covenant_weapon_is_cooling(primary_weapon))
		return TRUE

	return brain.should_reload()

/datum/human_ai_module/halo_sangheili/proc/has_usable_ranged_fallback()
	if(!runtime)
		return FALSE

	if(cached_ranged_fallback_time == world.time)
		return cached_ranged_fallback_available

	var/datum/human_ai_module/inventory/inventory = brain.halo_get_inventory()
	var/obj/item/weapon/gun/fallback_weapon = committed_primary_weapon || inventory?.get_primary_weapon()
	if(!brain.has_valid_tied_human() || !fallback_weapon || QDELETED(fallback_weapon))
		cached_ranged_fallback_time = world.time
		cached_ranged_fallback_available = FALSE
		return FALSE

	if(!owns_item(fallback_weapon))
		cached_ranged_fallback_time = world.time
		cached_ranged_fallback_available = FALSE
		return FALSE

	var/datum/human_tied_controller/controller = brain.halo_get_controller()
	if(!controller || !controller.can_ai_use_weapon(fallback_weapon))
		cached_ranged_fallback_time = world.time
		cached_ranged_fallback_available = FALSE
		return FALSE

	if(fallback_weapon.has_ammunition())
		cached_ranged_fallback_time = world.time
		cached_ranged_fallback_available = TRUE
		return TRUE

	cached_ranged_fallback_time = world.time
	cached_ranged_fallback_available = !isnull(inventory?.find_ammo_for_weapon(fallback_weapon))
	return cached_ranged_fallback_available

/datum/human_ai_module/halo_sangheili/proc/should_preserve_drawn_sword()
	if(!find_sword())
		return FALSE

	if(sword_only)
		return TRUE

	return !has_usable_ranged_fallback()

/datum/human_ai_module/halo_sangheili/proc/should_use_sword_mode(atom/threat = null)
	if(!runtime)
		return FALSE

	if(!threat)
		threat = brain.halo_covenant_get_threat_atom()

	if(!brain.has_valid_tied_human() || !threat)
		return FALSE

	if(!has_sword && !sword_only)
		return FALSE

	if(!find_sword())
		return FALSE

	var/datum/human_tied_controller/controller = brain.halo_get_controller()
	if(!controller)
		return FALSE
	var/distance_to_threat = controller.get_distance_to(threat)
	if(distance_to_threat > sword_charge_range)
		return FALSE

	if(sword_only)
		return TRUE

	if(distance_to_threat <= unarmed_commit_range)
		return TRUE

	return primary_weapon_unavailable()

/datum/human_ai_module/halo_sangheili/proc/should_sword_charge(atom/charge_target = null)
	return should_use_sword_mode(charge_target)

/datum/human_ai_module/halo_sangheili/proc/should_overheat_response(atom/threat = null)
	if(!runtime)
		return FALSE

	if(!threat)
		threat = brain.halo_covenant_get_threat_atom()

	if(!brain.has_valid_tied_human() || !threat)
		return FALSE

	if(!brain.halo_covenant_weapon_is_cooling(brain.halo_get_inventory()?.get_primary_weapon()))
		return FALSE

	if(should_sword_charge(threat))
		return FALSE

	return TRUE

/datum/human_ai_module/halo_sangheili/proc/should_unarmed_commit(atom/threat = null)
	if(!runtime)
		return FALSE

	if(!threat)
		threat = brain.halo_covenant_get_threat_atom()

	if(!brain.has_valid_tied_human() || !threat)
		return FALSE

	var/datum/human_tied_controller/controller = brain.halo_get_controller()
	return controller && (controller.get_distance_to(threat) <= unarmed_commit_range)

/datum/human_ai_module/halo_sangheili/proc/on_sword_dropped()
	SIGNAL_HANDLER

	if(drawn_sword)
		UnregisterSignal(drawn_sword, COMSIG_ITEM_DROPPED)

	invalidate_runtime_caches()
	drawn_sword = null
	sword_storage_loc = null
	clear_melee_commit()

/datum/human_ai_module/halo_sangheili/proc/get_commit_action_blacklist()
	var/static/list/commit_action_blacklist = list(
		/datum/ai_action/fire_at_target,
		/datum/ai_action/keep_distance,
		/datum/ai_action/reload,
		/datum/ai_action/select_primary,
		/datum/ai_action/machinegunner_nest,
		/datum/ai_action/sniper_nest,
	)
	return commit_action_blacklist

/datum/human_ai_module/halo_sangheili/proc/cancel_committed_actions()
	brain.cancel_ongoing_actions_by_type(get_commit_action_blacklist())

/datum/human_ai_module/halo_sangheili/proc/owns_item(obj/item/item)
	var/datum/human_tied_controller/controller = brain.halo_get_controller()
	return controller?.is_item_equipped_or_in_direct_storage(item)

/datum/human_ai_module/halo_sangheili/proc/begin_melee_commit(obj/item/weapon/covenant/energy_sword/sword)
	if(melee_committed)
		return TRUE

	var/datum/human_tied_controller/controller = brain.halo_get_controller()
	if(!brain.has_valid_tied_human() || !sword || !controller?.is_item_equipped_or_held(sword))
		return FALSE

	melee_committed = TRUE
	var/datum/human_ai_module/inventory/inventory = brain.halo_get_inventory()
	committed_primary_weapon = inventory?.get_primary_weapon()
	committed_tried_reload = brain.has_tried_reload()
	committed_ignore_looting = inventory?.is_looting_disabled()
	brain.invalidate_halo_runtime_caches()

	if(inventory?.get_primary_weapon())
		inventory.set_primary_weapon(null)

	brain.mark_tried_reload()
	inventory?.set_looting_disabled(TRUE)

	var/list/commit_action_blacklist = get_commit_action_blacklist()
	brain.add_action_blacklist(commit_action_blacklist)

	cancel_committed_actions()
	return TRUE

/datum/human_ai_module/halo_sangheili/proc/restore_ranged_state(atom/threat = null)
	if(sword_only || !melee_committed)
		return FALSE

	if(!has_usable_ranged_fallback())
		return FALSE

	if(should_use_sword_mode(threat))
		return FALSE

	if(holster_sword())
		return TRUE

	clear_melee_commit()
	return TRUE

/datum/human_ai_module/halo_sangheili/proc/clear_melee_commit(restore_firearm = TRUE)
	if(!melee_committed && !committed_primary_weapon)
		return

	var/obj/item/weapon/gun/restored_primary_weapon = committed_primary_weapon
	var/restored_tried_reload = committed_tried_reload
	var/restored_ignore_looting = committed_ignore_looting

	melee_committed = FALSE
	committed_primary_weapon = null
	committed_tried_reload = FALSE
	committed_ignore_looting = FALSE
	brain.invalidate_halo_runtime_caches()

	brain.remove_action_blacklist(get_commit_action_blacklist())

	brain.set_tried_reload(restored_tried_reload)
	var/datum/human_ai_module/inventory/inventory = brain.halo_get_inventory()
	inventory?.set_looting_disabled(restored_ignore_looting)

	if(!restore_firearm || inventory?.get_primary_weapon() || !restored_primary_weapon || !owns_item(restored_primary_weapon))
		return

	inventory.set_primary_weapon(restored_primary_weapon)

/datum/human_ai_module/halo_sangheili/proc/should_keep_sword_drawn()
	if(should_preserve_drawn_sword())
		return TRUE

	if(!melee_committed)
		return FALSE

	return should_use_sword_mode()

/datum/human_ai_module/halo_sangheili/proc/track_drawn_sword(obj/item/weapon/covenant/energy_sword/sword, storage_loc = null)
	if(!sword)
		return null

	if(drawn_sword && drawn_sword != sword)
		UnregisterSignal(drawn_sword, COMSIG_ITEM_DROPPED)

	drawn_sword = sword
	if(storage_loc)
		sword_storage_loc = storage_loc
	RegisterSignal(sword, COMSIG_ITEM_DROPPED, PROC_REF(on_sword_dropped), override = TRUE)
	return sword

/datum/human_ai_module/halo_sangheili/proc/try_store_sword(obj/item/weapon/covenant/energy_sword/sword, storage_loc)
	var/datum/human_tied_controller/controller = brain.halo_get_controller()
	if(!brain.has_valid_tied_human() || !sword || !controller?.is_item_equipped_or_held(sword))
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

/datum/human_ai_module/halo_sangheili/proc/draw_sword()
	if(!brain.has_valid_tied_human())
		return null
	var/datum/human_tied_controller/controller = brain.halo_get_controller()
	if(!controller)
		return null

	var/obj/item/weapon/covenant/energy_sword/sword = find_sword()
	if(!sword)
		return null

	var/storage_loc = sword_storage_loc

	if(sword == controller.get_l_hand() || sword == controller.get_r_hand())
		if(controller.get_inactive_hand() == sword)
			controller.swap_hand()
		track_drawn_sword(sword, storage_loc)
		begin_melee_commit(sword)
		if(!sword.activated && !sword.nonfunctional)
			controller.halo_set_sword_activation_state(sword, TRUE)
		brain.halo_get_inventory()?.ensure_primary_hand(sword)
		return sword

	if(!brain.halo_covenant_clear_hands())
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

	track_drawn_sword(sword, storage_loc)
	begin_melee_commit(sword)

	if(!sword.activated && !sword.nonfunctional)
		controller.halo_set_sword_activation_state(sword, TRUE)
	brain.halo_get_inventory()?.ensure_primary_hand(sword)
	return sword

/datum/human_ai_module/halo_sangheili/proc/holster_sword(force = FALSE)
	var/obj/item/weapon/covenant/energy_sword/sword = drawn_sword || find_sword()
	if(!brain.has_valid_tied_human() || !sword)
		on_sword_dropped()
		return TRUE

	if(!force && should_preserve_drawn_sword())
		return FALSE

	var/datum/human_tied_controller/controller = brain.halo_get_controller()
	if(!controller)
		on_sword_dropped()
		return TRUE

	if(sword.activated)
		controller.halo_set_sword_activation_state(sword, FALSE)

	if(!controller.is_item_equipped_or_held(sword))
		on_sword_dropped()
		return TRUE

	var/storage_loc = sword_storage_loc || "belt"
	var/success = try_store_sword(sword, storage_loc)
	if(!success && (storage_loc != "belt"))
		success = try_store_sword(sword, "belt")
	if(!success && (storage_loc != "suit_slot"))
		success = try_store_sword(sword, "suit_slot")

	if(success)
		on_sword_dropped()
		return TRUE

	return FALSE

/datum/human_ai_brain/proc/halo_configure_sangheili_behavior(has_sword = FALSE, sword_only = FALSE, sword_charge_range = 5, unarmed_commit_range = 2)
	halo_get_sangheili_module()?.configure(has_sword, sword_only, sword_charge_range, unarmed_commit_range)

/datum/human_ai_brain/proc/halo_sangheili_is_active()
	return halo_get_sangheili_module()?.is_active()

/datum/human_ai_brain/proc/halo_sangheili_is_sword_only()
	return halo_get_sangheili_module()?.is_sword_only()

/datum/human_ai_brain/proc/halo_sangheili_has_melee_commit()
	return halo_get_sangheili_module()?.has_melee_commit()

/datum/human_ai_brain/proc/halo_sangheili_get_drawn_sword()
	return halo_get_sangheili_module()?.get_drawn_sword()

/datum/human_ai_brain/proc/halo_sangheili_find_sword()
	return halo_get_sangheili_module()?.find_sword()

/datum/human_ai_brain/proc/halo_sangheili_primary_weapon_unavailable()
	return halo_get_sangheili_module()?.primary_weapon_unavailable()

/datum/human_ai_brain/proc/halo_sangheili_has_usable_ranged_fallback()
	return halo_get_sangheili_module()?.has_usable_ranged_fallback()

/datum/human_ai_brain/proc/halo_sangheili_should_preserve_drawn_sword()
	return halo_get_sangheili_module()?.should_preserve_drawn_sword()

/datum/human_ai_brain/proc/halo_sangheili_should_use_sword_mode(atom/threat = null)
	return halo_get_sangheili_module()?.should_use_sword_mode(threat)

/datum/human_ai_brain/proc/halo_sangheili_should_sword_charge(atom/charge_target = null)
	return halo_get_sangheili_module()?.should_sword_charge(charge_target)

/datum/human_ai_brain/proc/halo_sangheili_should_overheat_response(atom/threat = null)
	return halo_get_sangheili_module()?.should_overheat_response(threat)

/datum/human_ai_brain/proc/halo_sangheili_should_unarmed_commit(atom/threat = null)
	return halo_get_sangheili_module()?.should_unarmed_commit(threat)

/datum/human_ai_brain/proc/on_halo_sangheili_sword_dropped()
	SIGNAL_HANDLER

	halo_get_sangheili_module()?.on_sword_dropped()

/datum/human_ai_brain/proc/halo_sangheili_get_commit_action_blacklist()
	return halo_get_sangheili_module()?.get_commit_action_blacklist()

/datum/human_ai_brain/proc/halo_sangheili_cancel_committed_actions()
	halo_get_sangheili_module()?.cancel_committed_actions()

/datum/human_ai_brain/proc/halo_sangheili_owns_item(obj/item/item)
	return halo_get_sangheili_module()?.owns_item(item)

/datum/human_ai_brain/proc/halo_sangheili_begin_melee_commit(obj/item/weapon/covenant/energy_sword/sword)
	return halo_get_sangheili_module()?.begin_melee_commit(sword)

/datum/human_ai_brain/proc/halo_sangheili_restore_ranged_state(atom/threat = null)
	return halo_get_sangheili_module()?.restore_ranged_state(threat)

/datum/human_ai_brain/proc/halo_sangheili_clear_melee_commit(restore_firearm = TRUE)
	halo_get_sangheili_module()?.clear_melee_commit(restore_firearm)

/datum/human_ai_brain/proc/halo_sangheili_should_keep_sword_drawn()
	return halo_get_sangheili_module()?.should_keep_sword_drawn()

/datum/human_ai_brain/proc/halo_sangheili_track_drawn_sword(obj/item/weapon/covenant/energy_sword/sword, storage_loc = null)
	return halo_get_sangheili_module()?.track_drawn_sword(sword, storage_loc)

/datum/human_ai_brain/proc/halo_sangheili_try_store_sword(obj/item/weapon/covenant/energy_sword/sword, storage_loc)
	return halo_get_sangheili_module()?.try_store_sword(sword, storage_loc)

/datum/human_ai_brain/proc/halo_sangheili_draw_sword()
	return halo_get_sangheili_module()?.draw_sword()

/datum/human_ai_brain/proc/halo_sangheili_holster_sword(force = FALSE)
	return halo_get_sangheili_module()?.holster_sword(force)
