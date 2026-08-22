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

	var/micro_action_delay = 0.2 SECONDS
	var/short_action_delay = 0.5 SECONDS
	var/medium_action_delay = 2 SECONDS
	var/long_action_delay = 5 SECONDS
	/// Global multiplier for all AI action delays
	var/action_delay_mult = 2 // Doubled from 1, gives hAI a believable time between actions

	/// List of whitelisted/blacklisted action datums
	var/list/action_whitelist = null
	var/list/action_blacklist = null

	/// Distance for view checks
	var/view_distance = 6
	/// If TRUE, shoots until the target is dead. Else, stops when downed
	var/shoot_to_kill = TRUE
	/// Should we limit our FOV in case view_distance is more than 7
	var/scope_vision = TRUE

	/// List of current action datums
	var/list/ongoing_actions = list()

	/// A targeted turf that we should quickly approach
	var/turf/quick_approach

	/// Ref to the last turf that the AI shot at
	var/turf/shot_at

	/// If TRUE, then we're actively fighting someone or saw a bullet go by or saw someone else go into combat
	var/in_combat = FALSE

	/// The minimum amount of time that can pass before this AI can leave combat
	var/combat_decay_time_min = 15 SECONDS
	/// The maximum amount of time that can pass before this AI can leave combat
	var/combat_decay_time_max = 30 SECONDS
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
	tied_human = null

	return ..()

/datum/human_ai_brain/proc/has_valid_tied_human()
	return tied_human && !QDELETED(tied_human) && !isnull(tied_human.loc)

/datum/human_ai_brain/proc/reset_ai()
	cover.end_cover()
	perception.reset_detection()
	wake_rethink_queued_at = -1 // SS220 EDIT: reset must always cancel deferred wake-up recovery before owner teardown finishes

	in_combat = FALSE
	grenade.reset_grenade()
	targeting.target_turf = null
	shot_at = null
	inventory.reset_inventory()
	targeting.lose_target()
	health.lose_injured_ally()

	for(var/action in ongoing_actions)
		qdel(action)

	ongoing_actions.Cut()

/datum/human_ai_brain/process(delta_time)
	last_process_tick = world.time // SS220 EDIT: track scheduler entry to guard same-tick wake rethinks
	wake_rethink_queued_at = -1 // SS220 EDIT: any queued wake rethink has been serviced once processing starts
	if(!has_valid_tied_human()) // SS220 EDIT: upstream process loop must no-op once modular AI owner is gone
		reset_ai()
		return

	if(tied_human.stat == DEAD) // SS220 EDIT: dead HALO AI must never remain in the wake-up recovery path
		perception.suspend()
		wake_rethink_queued_at = -1 // SS220 EDIT: death fallback must kill any queued wake rethink that survived until process()
		for(var/action in ongoing_actions)
			qdel(action)
		ongoing_actions.Cut()
		targeting.lose_target()
		if(!tied_human.resting)
			tied_human.set_resting(TRUE, TRUE)
		else
			tied_human.set_lying_down()
		return

	if(tied_human.is_mob_incapacitated())
		perception.suspend() // SS220 EDIT: stunned or dead AI should not keep turf-enter listeners alive
		for(var/action in ongoing_actions)
			qdel(action)
		ongoing_actions.Cut()
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
		for(var/action in ongoing_actions)
			qdel(action)
		ongoing_actions.Cut()
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
		enter_combat()

	if(!iszombie(tied_human) && inventory.should_run_nearby_item_search())
		inventory.item_search(range(2, tied_human))

	// List all allowed action types for AI to consider
	var/list/allowed_actions = action_whitelist || (GLOB.AI_actions.Copy() - action_blacklist)
	for(var/datum/ongoing_action as anything in ongoing_actions)
		if(is_type_in_list(ongoing_action, allowed_actions))
			allowed_actions -= ongoing_action.type

	var/grenade_throw_in_progress = grenade.has_throw_in_progress()

	// Create assoc list of selected AI actions and their weight
	var/list/possible_actions = list()
	for(var/action_type in shuffle(allowed_actions))
		var/datum/ai_action/glob_ref = GLOB.AI_actions[action_type]
		// SS220 EDIT: skip hand-using actions while a grenade throw is in async flight
		if(grenade_throw_in_progress && (glob_ref.action_flags & ACTION_USING_HANDS))
			continue
		var/weight = glob_ref.get_weight(src)
		if(weight) // No weight means we shouldn't consider this action at all
			possible_actions[action_type] = weight

	// Sorts all allowed actions by their weight
	var/list/sorted_actions = sortTim(possible_actions, GLOBAL_PROC_REF(cmp_numeric_dsc), TRUE)

	// Choose what actions to start in current process() iteration
	for(var/action_type as anything in sorted_actions)
		var/datum/ai_action/possible_action = GLOB.AI_actions[action_type]

		var/list/conflicting_actions = possible_action.get_conflicts(src)
		for(var/datum/ai_action/ongoing_action as anything in ongoing_actions)
			if(ongoing_action.type in conflicting_actions)
				possible_action = null
				break

		if(!possible_action)
			continue

		ongoing_actions += new action_type(src)
#if defined(TESTING) && defined(HUMAN_AI_TESTING)
		message_admins("action of type [action_type] was added to [tied_human.real_name]")
#endif

	for(var/datum/ai_action/action as anything in ongoing_actions)
		// SS220 EDIT: suppress hand-using actions while a grenade throw is in async flight
		if(grenade_throw_in_progress && (action.action_flags & ACTION_USING_HANDS))
			continue
		var/retval = action.trigger_action()
		switch(retval)
			if(ONGOING_ACTION_UNFINISHED_BLOCK)
				return
			if(ONGOING_ACTION_COMPLETED)
				qdel(action)

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
	SIGNAL_HANDLER
	if(!has_valid_tied_human())
		return

	if(squad.squad_id) // call for help
		var/datum/human_ai_squad/squad_datum = SShuman_ai.squad_id_dict["[squad.squad_id]"]
		for(var/datum/human_ai_brain/squaddie as anything in squad_datum.ai_in_squad)
			if(!squaddie.has_valid_tied_human())
				continue
			if(squaddie.targeting.target_turf)
				continue
			if(get_dist(squaddie.tied_human, tied_human) > squaddie.view_distance)
				continue
			if(!squaddie.targeting.can_target(targeting.current_target))
				continue
			squaddie.targeting.target_turf = targeting.target_turf

	if(tied_human.client)
		return

	if(!in_combat)
		communication.say_in_combat_line()

	if(isxeno(targeting.current_target))
		cover.try_cover(Get_Angle(targeting.current_target, tied_human), targeting.current_target)

	in_combat = TRUE
	addtimer(CALLBACK(src, PROC_REF(exit_combat)), rand(combat_decay_time_min, combat_decay_time_max), TIMER_UNIQUE | TIMER_NO_HASH_WAIT | TIMER_OVERRIDE)
	SShuman_ai.combat_ever_started = TRUE

/datum/human_ai_brain/proc/exit_combat()
	if(!has_valid_tied_human())
		targeting.lose_target()
		targeting.target_turf = null
		cover.end_cover()
		in_combat = FALSE
		return

	if(tied_human.client)
		return

	if(in_combat)
		tied_human.a_intent_change(INTENT_DISARM)
		targeting.lose_target()
		communication.say_exit_combat_line()
		if(!sniper_home)
			inventory.holster_primary()
		inventory.holster_melee()

	if(cover.current_cover)
		if(!prob(cover.peek_cover_chance))
			targeting.target_turf = null
		cover.end_cover()
	else
		targeting.target_turf = null

	in_combat = FALSE
