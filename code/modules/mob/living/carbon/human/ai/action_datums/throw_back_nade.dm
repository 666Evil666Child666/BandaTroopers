/datum/ai_action/throw_back_nade
	name = "Throw Back Grenade"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS
	var/min_safe_throw_distance = 4 // SS220 EDIT: throw-back should not deliberately choose turf inside the expected grenade danger radius
	var/throw_ready_time = 0 // SS220 EDIT: picked-up timed grenades roll a random hold window before the actual throw
	var/mid_throw = FALSE // SS220 EDIT: transient async state keeps trigger_action() no-sleep while the real throw runs separately
	var/throw_finished = FALSE // SS220 EDIT: transient async state completes the action on the next scheduler tick

/datum/ai_action/throw_back_nade/get_weight(datum/human_ai_brain/brain)
	if(!brain.grenade.can_throw_back()) // SS220 EDIT: modular HALO weak AI presets must not enter throw-back mode
		return 0

	var/obj/item/explosive/grenade/active_grenade_found = brain.grenade.get_active_grenade()
	if(QDELETED(active_grenade_found))
		return 0

	if(brain.tied_controller.get_distance_to(active_grenade_found) > 4)
		return 0

	return 50

/datum/ai_action/throw_back_nade/Destroy(force, ...)
	brain.grenade.clear_active_grenade() // Mr. Grenade is not our friend now
	throw_ready_time = 0
	mid_throw = FALSE // SS220 EDIT: drop transient async throw state when the action is torn down
	throw_finished = FALSE // SS220 EDIT: drop transient async throw state when the action is torn down
	return ..()

/datum/ai_action/throw_back_nade/proc/try_hold_grenade(obj/item/explosive/grenade/grenade)
	if(!grenade || QDELETED(grenade) || !isturf(grenade.loc))
		return FALSE

	if(brain.tied_controller.get_active_hand() == grenade)
		return TRUE

	if(!(brain.tied_controller.get_active_hand()?.flags_item & NODROP))
		brain.inventory.clear_main_hand()
		if(brain.tied_controller.put_in_active_hand(grenade))
			return TRUE

	brain.tied_controller.swap_hand()
	if(brain.tied_controller.get_active_hand() == grenade)
		return TRUE

	if(!(brain.tied_controller.get_active_hand()?.flags_item & NODROP))
		brain.inventory.clear_main_hand()
		if(brain.tied_controller.put_in_active_hand(grenade))
			return TRUE

	brain.tied_controller.swap_hand()
	return FALSE

// SS220 EDIT START: partial unification with throw_grenade try_hold_grenade - add ensure_primary_hand
/datum/ai_action/throw_back_nade/proc/try_hold_grenade_ensure_primary(obj/item/explosive/grenade/grenade)
	if(!try_hold_grenade(grenade))
		return FALSE
	brain.inventory.ensure_primary_hand(grenade)
	return TRUE
// SS220 EDIT END

/datum/ai_action/throw_back_nade/proc/get_directional_throw_target()
	var/list/directions = list(
		locate(brain.tied_controller.get_x(), brain.tied_controller.get_y() + min_safe_throw_distance, brain.tied_controller.get_z()),
		locate(brain.tied_controller.get_x() + min_safe_throw_distance, brain.tied_controller.get_y(), brain.tied_controller.get_z()),
		locate(brain.tied_controller.get_x(), brain.tied_controller.get_y() - min_safe_throw_distance, brain.tied_controller.get_z()),
		locate(brain.tied_controller.get_x() - min_safe_throw_distance, brain.tied_controller.get_y(), brain.tied_controller.get_z()),
	)

	dir_loop:
		for(var/turf/location as anything in directions)
			if(location)
				var/list/turf/path = brain.tied_controller.get_line_to(location, FALSE)
				for(var/turf/possible_blocker as anything in path)
					if(possible_blocker.density)
						continue dir_loop

					for(var/obj/possible_object_blocker in possible_blocker) // SS220 EDIT: fix - iterate possible_blocker contents instead of path turfs
						if(possible_object_blocker.density)
							continue dir_loop

				var/has_friendly = FALSE
				for(var/mob/possible_friendly in range(brain.grenade.get_friendly_throw_check_range(), location)) // SS220 EDIT: use configurable range from grenade module
					if(!brain.targeting.can_target(possible_friendly))
						has_friendly = TRUE
						break

				if(!has_friendly)
					return location

	return null

/datum/ai_action/throw_back_nade/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	if(throw_finished)
		return ONGOING_ACTION_COMPLETED

	if(mid_throw)
		return ONGOING_ACTION_UNFINISHED

	if(!brain.grenade.can_throw_back()) // SS220 EDIT: abort stale throw-back actions after preset capability changes
		log_game("AI GRENADE: throw-back aborted — capability disabled, mob=[brain?.tied_controller?.get_key_name()]")
		brain.grenade.clear_active_grenade()
		throw_ready_time = 0
		return ONGOING_ACTION_COMPLETED

	var/obj/item/explosive/grenade/active_grenade_found = brain.grenade.get_active_grenade()
	if(QDELETED(active_grenade_found) || !active_grenade_found.active || (!isturf(active_grenade_found.loc) && !brain.tied_controller.is_item_equipped_or_held(active_grenade_found)))
		log_game("AI GRENADE: throw-back aborted — grenade stale or spent, grenade=[active_grenade_found], mob=[brain?.tied_controller?.get_key_name()]")
		brain.grenade.clear_active_grenade() // SS220 EDIT: stale or spent grenades must not keep the AI in throw-back mode
		throw_ready_time = 0
		return ONGOING_ACTION_COMPLETED

	if(!brain.tied_controller.is_item_equipped_or_held(active_grenade_found))
		if(brain.tied_controller.get_distance_to(active_grenade_found) > 1)
			if(!brain.navigation.move_to_next_turf(get_turf(active_grenade_found)))
				log_game("AI GRENADE: throw-back aborted — could not move to grenade, grenade=[active_grenade_found], mob=[brain.tied_controller.get_key_name()]")
				return ONGOING_ACTION_COMPLETED

			if(brain.tied_controller.get_distance_to(active_grenade_found) > 1)
				return ONGOING_ACTION_UNFINISHED

		if(!try_hold_grenade(active_grenade_found))
			log_game("AI GRENADE: throw-back aborted — could not pick up grenade, grenade=[active_grenade_found], mob=[brain.tied_controller.get_key_name()]")
			brain.grenade.clear_active_grenade()
			throw_ready_time = 0
			return ONGOING_ACTION_COMPLETED

		var/remaining_fuse_ticks = active_grenade_found.get_remaining_timed_fuse_ticks()
		if(isnull(remaining_fuse_ticks) || (remaining_fuse_ticks <= 0))
			throw_ready_time = world.time // SS220 EDIT: if this grenade does not expose a usable timed-fuse window, toss it back immediately after pickup
		else
			var/safe_window = max(1, remaining_fuse_ticks - 2) // SS220 EDIT: safety margin — ensure throw happens at least 2 ticks before detonation
			throw_ready_time = world.time + rand(1, safe_window)
		log_game("AI GRENADE: throw-back holding grenade — grenade=[active_grenade_found], remaining_fuse=[remaining_fuse_ticks], throw_ready=[throw_ready_time], mob=[brain.tied_controller.get_key_name()]")
		return ONGOING_ACTION_UNFINISHED

	if(world.time < throw_ready_time)
		return ONGOING_ACTION_UNFINISHED

	var/view_distance = brain.profile.view_distance
	var/list/possible_targets = list()

	for(var/mob/living/carbon/target in brain.tied_controller.get_range(view_distance))
		if(brain.targeting.can_target(target))
			possible_targets += target

	var/turf/place_to_throw
	if(length(possible_targets))
		var/mob/living/carbon/chosen_target = pick(possible_targets)
		var/list/turf_pathfind_list = AStar(brain.tied_controller.get_current_turf(), get_turf(chosen_target), /turf/proc/AdjacentTurfs, /turf/proc/Distance, view_distance)
		for(var/i = length(turf_pathfind_list); i >= min_safe_throw_distance; i--) // We cut it off at 4 because we want to avoid most of the nade blast
			var/turf/target_turf = turf_pathfind_list[i]
			if(brain.tied_controller.is_in_view_of(target_turf, view_distance))
				place_to_throw = target_turf
				break

	if(place_to_throw && (brain.tied_controller.get_distance_to(place_to_throw) < min_safe_throw_distance))
		place_to_throw = null // SS220 EDIT: short A* paths must not degrade into self-throws when the target is already too close

	if(!place_to_throw)
		place_to_throw = get_directional_throw_target() // SS220 EDIT: fallback keeps the primed grenade moving away from nearby friendlies and the thrower
		if(!place_to_throw)
			// SS220 EDIT: no safe throw target exists — drop the live grenade and clean up throw-back state
			log_game("AI GRENADE: throw-back EMERGENCY — no safe target, dropping live grenade on floor, grenade=[active_grenade_found], mob=[brain.tied_controller.get_key_name()], loc=[brain.tied_controller.get_area_coords()]")
			msg_admin_attack("[brain.tied_controller.get_key_name()] (AI) dropped a live [active_grenade_found] on the floor during throw-back — no safe throw target at [brain.tied_controller.get_area_coords()].")
			brain.tied_controller.drop_live_grenade(active_grenade_found)
			brain.grenade.clear_active_grenade()
			throw_ready_time = 0
			return ONGOING_ACTION_COMPLETED

	if(!try_hold_grenade_ensure_primary(active_grenade_found)) // SS220 EDIT: only continue once the live grenade is actually in-hand
		log_game("AI GRENADE: throw-back aborted — final hold failed, grenade=[active_grenade_found], mob=[brain.tied_controller.get_key_name()]")
		brain.grenade.clear_active_grenade()
		throw_ready_time = 0
		return ONGOING_ACTION_COMPLETED

	if(QDELETED(active_grenade_found) || !brain.tied_controller.is_item_equipped_or_held(active_grenade_found) || !active_grenade_found.active)
		log_game("AI GRENADE: throw-back aborted — grenade lost before throw, grenade=[active_grenade_found], mob=[brain.tied_controller.get_key_name()]")
		brain.grenade.clear_active_grenade() // SS220 EDIT: grenade throw-back must abort cleanly if the primed grenade left our hands before scheduling
		throw_ready_time = 0
		return ONGOING_ACTION_COMPLETED

	brain.tied_controller.toggle_throw_mode(THROW_MODE_NORMAL)
	brain.tied_controller.face_atom(place_to_throw)
	log_game("AI GRENADE: throw-back proceeding to async throw — grenade=[active_grenade_found], target=[place_to_throw], mob=[brain.tied_controller.get_key_name()]")
	brain.grenade.clear_active_grenade() // SS220 EDIT: the grenade is already under this AI's control, stop blocking the rest of its combat state
	brain.inventory.unqueue_pickup(active_grenade_found) // Do NOT play fetch. Please.
	throw_ready_time = 0
	mid_throw = TRUE // SS220 EDIT: actual throw runs asynchronously so trigger_action() stays no-sleep for DreamChecker
	INVOKE_ASYNC(src, PROC_REF(async_throw_grenade), brain.tied_controller.get_identity_ref(), active_grenade_found, place_to_throw) // SS220 EDIT: async throw avoids DreamChecker sleep violations from throw_item/launch paths
	return ONGOING_ACTION_UNFINISHED

/datum/ai_action/throw_back_nade/proc/finish_async_throw()
	throw_ready_time = 0
	mid_throw = FALSE
	throw_finished = TRUE

/datum/ai_action/throw_back_nade/proc/async_throw_grenade(datum/weakref/puppet_ref, obj/item/explosive/grenade/grenade, turf/place_to_throw)
	log_game("AI GRENADE: throw-back async throw started — grenade=[grenade], target=[place_to_throw], mob=[brain?.tied_controller?.get_key_name()]")
	if(QDELETED(src))
		return

	if(!brain || !brain.has_valid_tied_human() || !brain.tied_controller.matches_identity_ref(puppet_ref))
		log_game("AI GRENADE: throw-back async throw aborted — brain invalid or mismatch, mob=[brain?.tied_controller?.get_key_name()]")
		finish_async_throw()
		return

	if(QDELETED(grenade) || !grenade.active || !brain.tied_controller.is_item_equipped_or_held(grenade) || !place_to_throw)
		log_game("AI GRENADE: throw-back async throw aborted — grenade invalid or missing, grenade=[grenade], active=[grenade?.active], loc=[grenade?.loc], target=[place_to_throw], mob=[brain?.tied_controller?.get_key_name()]")
		finish_async_throw()
		return

	if(brain.tied_controller.get_active_hand() != grenade)
		if(brain.tied_controller.get_inactive_hand() == grenade)
			brain.tied_controller.swap_hand() // SS220 EDIT: async throw must reselect the exact grenade chosen during sync target resolution
		else
			log_game("AI GRENADE: throw-back async throw aborted — grenade not in hands, mob=[brain.tied_controller.get_key_name()]")
			finish_async_throw()
			return

	if(brain.tied_controller.get_active_hand() != grenade)
		log_game("AI GRENADE: throw-back async throw aborted — grenade not in active hand after swap, mob=[brain.tied_controller.get_key_name()]")
		finish_async_throw()
		return

	brain.tied_controller.throw_item(place_to_throw) // SS220 EDIT: actual throw runs outside SHOULD_NOT_SLEEP action processing
	log_game("AI GRENADE: throw-back throw_item() called — grenade=[grenade], target=[place_to_throw], mob=[brain.tied_controller.get_key_name()]")
	finish_async_throw()
