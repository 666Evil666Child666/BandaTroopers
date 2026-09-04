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

	var/wake_rethink_queued_at = -1 // SS220 EDIT: wake-up signal should only queue one immediate rethink per tick
	var/last_process_tick = -1 // SS220 EDIT: prevent signal-driven wake rethinks from re-entering the scheduler in the same tick
	var/lifecycle_state = HUMAN_AI_LIFECYCLE_ACTIVE // SS220 EDIT: brain owns active/suspended runtime admission

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
	reset_ai()
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

/datum/human_ai_brain/proc/reset_ai()
	cover.end_cover()
	perception.reset_detection()
	wake_rethink_queued_at = -1 // SS220 EDIT: reset must always cancel deferred wake-up recovery before owner teardown finishes

	combat.reset_combat()
	grenade.reset_grenade()
	targeting.clear_target_turf()
	inventory.reset_inventory()
	targeting.lose_target()
	health.lose_injured_ally()

	action_runtime.clear_actions()

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
	cover.end_cover()
	perception.suspend()
	wake_rethink_queued_at = -1
	combat.reset_combat()
	grenade.reset_grenade()
	targeting.clear_target_turf()
	targeting.lose_target()
	health.lose_injured_ally()
	health.healing_someone = FALSE
	action_runtime.clear_actions()
	if(clear_inventory)
		inventory.reset_inventory()
	else
		inventory.invalidate_nearby_item_search()

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

	inventory.appraise_inventory()
	guns.clear_tried_reload()
	inventory.invalidate_nearby_item_search()
	brain_resume_modular_runtime()
	return TRUE

/datum/human_ai_brain/proc/brain_resume_modular_runtime()
	invalidate_halo_runtime_caches()

/datum/human_ai_brain/proc/should_force_hardcrit_resting()
	return (tied_controller.has_effect(/datum/effects/crit) && tied_controller.has_status_flag(CANKNOCKOUT))

/datum/human_ai_brain/proc/process_active_ai(delta_time)

	perception.process_module(delta_time) // SS220 EDIT: restore projectile detection after recovering from incap or reset

	// SS220 EDIT - START: hardcrit AIs should keep resting until the crit loop and knockdown pressure are truly gone
	if((tied_controller.get_stat() == CONSCIOUS) && tied_controller.is_resting() && !tied_controller.has_trait(TRAIT_FLOORED))
		// SS220 EDIT - START: final stand-up gate must stay exactly aligned with the existing wake rethink eligibility rules
		tied_controller.try_stand_up()
		// SS220 EDIT - END
	// SS220 EDIT - END

	if(tied_controller.is_buckled())
		tied_controller.clear_buckle_state() // AI never buckle themselves into chairs at the moment, change if this becomes the case

	if(!targeting.has_current_target())
		targeting.set_target(targeting.get_target())

	if(targeting.has_current_target())
		combat.enter_combat()

	if(!tied_controller.is_zombie() && inventory.should_run_nearby_item_search())
		inventory.item_search(tied_controller.get_range(2))

	if(action_runtime.process_actions(delta_time))
		return

/datum/human_ai_brain/proc/on_human_delete(datum/source, force)
	SIGNAL_HANDLER
	perception.clear_detection_radius() // SS220 EDIT: aggressively tear down brain state before component qdel catches up
	reset_ai()
	lifecycle_state = HUMAN_AI_LIFECYCLE_INVALID
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
