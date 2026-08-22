GLOBAL_LIST_EMPTY(human_ai_brains)

/datum/human_ai_brain
	/// The human that this brain ties into
	var/mob/living/carbon/human/tied_human

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

	var/micro_action_delay = 0.2 SECONDS
	var/short_action_delay = 0.5 SECONDS
	var/medium_action_delay = 2 SECONDS
	var/long_action_delay = 5 SECONDS
	/// Global multiplier for all AI action delays
	var/action_delay_mult = 2 // Doubled from 1, gives hAI a believable time between actions

	/// Distance for view checks
	var/view_distance = 6
	/// If TRUE, shoots until the target is dead. Else, stops when downed
	var/shoot_to_kill = TRUE
	/// Should we limit our FOV in case view_distance is more than 7
	var/scope_vision = TRUE

	/// A targeted turf that we should quickly approach
	var/turf/quick_approach

	/// If TRUE, the AI will not move at all
	var/hold_position = FALSE

	var/wake_rethink_queued_at = -1 // SS220 EDIT: wake-up signal should only queue one immediate rethink per tick
	var/last_process_tick = -1 // SS220 EDIT: prevent signal-driven wake rethinks from re-entering the scheduler in the same tick

/datum/human_ai_brain/New(mob/living/carbon/human/tied_human)
	. = ..()
	src.tied_human = tied_human
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
	perception = new(src)
	perception.register_signals()
	perception.setup_detection_radius()
	inventory = new(src)
	inventory.register_signals()
	RegisterSignal(tied_human, COMSIG_PARENT_QDELETING, PROC_REF(on_human_delete))
	RegisterSignal(tied_human, COMSIG_MOB_DEATH, PROC_REF(on_human_death)) // SS220 EDIT: HALO death guard should tear down AI and force corpses prone immediately
	RegisterSignal(tied_human, COMSIG_MOVABLE_MOVED, PROC_REF(on_move))
	RegisterSignal(tied_human, COMSIG_HUMAN_HANDCUFFED, PROC_REF(on_handcuffed))
	RegisterSignal(tied_human, COMSIG_HUMAN_GET_AI_BRAIN, PROC_REF(get_ai_brain))
	RegisterSignal(tied_human, COMSIG_HUMAN_SET_SPECIES, PROC_REF(on_species_change))
	RegisterSignal(tied_human, COMSIG_LIVING_SET_BODY_POSITION, PROC_REF(on_body_position_change)) // SS220 EDIT: standing back up should wake shared human AI immediately
	GLOB.human_ai_brains += src
	inventory.appraise_inventory()
	tied_human.a_intent_change(INTENT_DISARM)

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
	tied_human = null

	return ..()

/datum/human_ai_brain/proc/has_valid_tied_human()
	return tied_human && !QDELETED(tied_human) && !isnull(tied_human.loc)

/datum/human_ai_brain/proc/reset_ai()
	cover.end_cover()
	perception.reset_detection()
	wake_rethink_queued_at = -1 // SS220 EDIT: reset must always cancel deferred wake-up recovery before owner teardown finishes

	combat.reset_combat()
	grenade.reset_grenade()
	targeting.target_turf = null
	inventory.reset_inventory()
	targeting.lose_target()
	health.lose_injured_ally()

	action_runtime.clear_actions()

/datum/human_ai_brain/process(delta_time)
	last_process_tick = world.time // SS220 EDIT: track scheduler entry to guard same-tick wake rethinks
	wake_rethink_queued_at = -1 // SS220 EDIT: any queued wake rethink has been serviced once processing starts
	if(!has_valid_tied_human()) // SS220 EDIT: upstream process loop must no-op once modular AI owner is gone
		reset_ai()
		return

	if(tied_human.stat == DEAD) // SS220 EDIT: dead HALO AI must never remain in the wake-up recovery path
		perception.suspend()
		wake_rethink_queued_at = -1 // SS220 EDIT: death fallback must kill any queued wake rethink that survived until process()
		action_runtime.clear_actions()
		targeting.lose_target()
		if(!tied_human.resting)
			tied_human.set_resting(TRUE, TRUE)
		else
			tied_human.set_lying_down()
		return

	if(tied_human.is_mob_incapacitated())
		perception.suspend() // SS220 EDIT: stunned or dead AI should not keep turf-enter listeners alive
		action_runtime.clear_actions()
		targeting.lose_target()
		return

	perception.process_module(delta_time) // SS220 EDIT: restore projectile detection after recovering from incap or reset

	// SS220 EDIT - START: hardcrit AIs should keep resting until the crit loop and knockdown pressure are truly gone
	var/should_force_resting = ((locate(/datum/effects/crit) in tied_human.effects_list) && (tied_human.status_flags & CANKNOCKOUT))
	if(should_force_resting)
		if(!tied_human.resting)
			tied_human.set_resting(TRUE, TRUE)
		else
			tied_human.set_lying_down() // SS220 EDIT: crit-resting AI can keep a stale standing transform unless prone is re-asserted through the shared helper
		perception.suspend() // SS220 EDIT: prone hardcrit AI should not keep live projectile listeners or continue active combat movement
		action_runtime.clear_actions()
		inventory.to_pickup.Cut() // SS220 EDIT: lying crit AI must drop stale pickup goals so it does not keep chasing far-away weapons after forced prone
		inventory.invalidate_nearby_item_search()
		return
	else if((tied_human.stat == CONSCIOUS) && tied_human.resting && !HAS_TRAIT(tied_human, TRAIT_FLOORED))
		// SS220 EDIT - START: final stand-up gate must stay exactly aligned with the existing wake rethink eligibility rules
		if(has_valid_tied_human() && !tied_human.client && !tied_human.buckled && (tied_human.stat == CONSCIOUS) && !tied_human.is_mob_incapacitated())
			tied_human.set_resting(FALSE, TRUE)
		// SS220 EDIT - END
	// SS220 EDIT - END

	if(tied_human.buckled)
		tied_human.set_buckled(FALSE) // AI never buckle themselves into chairs at the moment, change if this becomes the case

	if(!targeting.current_target)
		targeting.set_target(targeting.get_target())

	if(targeting.current_target)
		combat.enter_combat()

	if(!iszombie(tied_human) && inventory.should_run_nearby_item_search())
		inventory.item_search(range(2, tied_human))

	if(action_runtime.process_actions(delta_time))
		return

/datum/human_ai_brain/proc/on_human_delete(datum/source, force)
	SIGNAL_HANDLER
	perception.clear_detection_radius() // SS220 EDIT: aggressively tear down brain state before component qdel catches up
	reset_ai()
	wake_rethink_queued_at = -1 // SS220 EDIT: owner delete must not leave a queued wake rethink pointing at a null tied human
	tied_human = null

/datum/human_ai_brain/proc/on_human_death(datum/source)
	SIGNAL_HANDLER
	reset_ai()
	wake_rethink_queued_at = -1 // SS220 EDIT: death signal must immediately invalidate any deferred wake processing
	if(!has_valid_tied_human() || (tied_human.stat != DEAD))
		return
	if(tied_human.buckled) // SS220 EDIT: only the direct death path should release forced-standing buckle state
		tied_human.buckled.unbuckle()
	if(!tied_human.resting)
		tied_human.set_resting(TRUE, TRUE)
	else
		tied_human.set_lying_down()

/datum/human_ai_brain/proc/on_species_change(datum/source, new_species)
	SIGNAL_HANDLER
	if((new_species == SPECIES_YAUTJA) || (new_species == SPECIES_ZOMBIE))
		inventory.ignore_looting = TRUE
	else
		inventory.ignore_looting = FALSE

/datum/human_ai_brain/proc/on_body_position_change(datum/source, new_position, old_position)
	SIGNAL_HANDLER
	if((new_position != STANDING_UP) || (old_position != LYING_DOWN))
		return

	if(!has_valid_tied_human() || tied_human.client || tied_human.buckled || (tied_human.stat != CONSCIOUS) || tied_human.is_mob_incapacitated())
		return

	inventory.invalidate_nearby_item_search() // SS220 EDIT: wake-up should immediately invalidate idle pickup/grenade scan throttles
	if(targeting.current_target)
		targeting.update_target_pos() // SS220 EDIT: refresh transient combat targeting state after knockdown recovery

	if((last_process_tick == world.time) || (wake_rethink_queued_at == world.time))
		return

	wake_rethink_queued_at = world.time
	INVOKE_ASYNC(src, PROC_REF(run_wake_rethink), world.time) // SS220 EDIT: queue exactly one no-sleep rethink outside the signal stack

/datum/human_ai_brain/proc/run_wake_rethink(queued_tick)
	if(QDELETED(src) || (wake_rethink_queued_at != queued_tick))
		return

	wake_rethink_queued_at = -1
	if(!has_valid_tied_human() || tied_human.client || tied_human.buckled || (tied_human.stat != CONSCIOUS) || tied_human.is_mob_incapacitated())
		return

	if((last_process_tick == queued_tick) || (last_process_tick == world.time))
		return

	process(0) // SS220 EDIT: reuse the existing shared AI loop instead of inventing a separate wake-up behavior



/datum/human_ai_brain/proc/on_move(atom/oldloc, direction, forced)
	if(!has_valid_tied_human())
		return

	perception.setup_detection_radius()

	if(cover.in_cover && (get_dist(tied_human, cover.current_cover) > inventory.gun_data?.minimum_range))
		cover.end_cover()

	targeting.update_target_pos()

/datum/human_ai_brain/proc/enter_combat()
	return combat.enter_combat()

/datum/human_ai_brain/proc/exit_combat()
	return combat.exit_combat()
