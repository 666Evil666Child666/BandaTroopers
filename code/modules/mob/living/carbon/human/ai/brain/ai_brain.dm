GLOBAL_LIST_EMPTY(human_ai_brains)

/datum/human_ai_brain
	/// API facade for reading and controlling the tied human puppet.
	var/datum/human_tied_controller/tied_controller
	var/datum/human_ai_module_config/module_config

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
	module_config = create_module_config(new_human?.assigned_equipment_preset?.human_ai_module_config_type)
	module_config.setup_brain(src, new_human)
	setup_lifecycle_modules()
	tied_controller.register_signal_for(src, COMSIG_PARENT_QDELETING, PROC_REF(on_human_delete))
	tied_controller.register_signal_for(src, COMSIG_MOB_DEATH, PROC_REF(on_human_death)) // SS220 EDIT: HALO death guard should tear down AI and force corpses prone immediately
	tied_controller.register_signal_for(src, COMSIG_MOVABLE_MOVED, PROC_REF(on_move))
	tied_controller.register_signal_for(src, COMSIG_HUMAN_HANDCUFFED, PROC_REF(on_handcuffed))
	tied_controller.register_signal_for(src, COMSIG_HUMAN_GET_AI_BRAIN, PROC_REF(get_ai_brain))
	tied_controller.register_signal_for(src, COMSIG_HUMAN_SET_SPECIES, PROC_REF(on_species_change))
	tied_controller.register_signal_for(src, COMSIG_LIVING_SET_BODY_POSITION, PROC_REF(on_body_position_change)) // SS220 EDIT: standing back up should wake shared human AI immediately
	GLOB.human_ai_brains += src
	inventory?.appraise_inventory()
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
	module_config?.teardown_brain_modules(src)
	QDEL_NULL(module_config)
	QDEL_NULL(tied_controller)

	return ..()

/datum/human_ai_brain/proc/has_valid_tied_human()
	return tied_controller?.has_valid_tied_human()

/datum/human_ai_brain/proc/create_module_config(module_config_type = /datum/human_ai_module_config/default)
	if(!ispath(module_config_type, /datum/human_ai_module_config))
		module_config_type = /datum/human_ai_module_config/default
	return new module_config_type()

/datum/human_ai_brain/proc/setup_lifecycle_modules()
	module_config.configure_module_lists(src)

/datum/human_ai_brain/proc/register_extension_module(datum/human_ai_module/module)
	if(!module)
		return null

	module_config?.register_module(module)
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
	if(inventory)
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
	var/should_holster_primary = !emplacement?.has_sniper_home()
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


/datum/human_ai_brain/proc/on_human_delete(datum/source, force)
	SIGNAL_HANDLER
	perception?.clear_detection_radius() // SS220 EDIT: aggressively tear down brain state before component qdel catches up
	shutdown_runtime()
	wake_rethink_queued_at = -1 // SS220 EDIT: owner delete must not leave a queued wake rethink pointing at a null tied human
	tied_controller?.set_tied_human(null)

/datum/human_ai_brain/proc/on_human_death(datum/source)
	SIGNAL_HANDLER
	suspend_for_death()
	lifecycle_state = HUMAN_AI_LIFECYCLE_DEAD

/datum/human_ai_brain/proc/on_species_change(datum/source, new_species)
	SIGNAL_HANDLER
	if(!inventory)
		return
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

	inventory?.invalidate_nearby_item_search() // SS220 EDIT: wake-up should immediately invalidate idle pickup/grenade scan throttles
	if(targeting?.has_current_target())
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

	perception?.setup_detection_radius()

	if(cover && inventory && cover.is_in_cover() && (tied_controller.get_distance_to(cover.get_current_cover()) > inventory.get_gun_data()?.minimum_range))
		cover.end_cover()

	targeting?.update_target_pos()
