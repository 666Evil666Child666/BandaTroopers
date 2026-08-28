#define HUMAN_AI_GRENADE_MIN_HOLD_DELAY (1 SECONDS)
#define HUMAN_AI_GRENADE_POST_PRIME_THROW_DELAY (1 SECONDS)

/datum/ai_action/throw_grenade
	name = "Throw Grenade"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS // SS220 EDIT: grenade priming/throwing should own both hand and movement slots until it resolves
	var/obj/item/explosive/grenade/throwing
	var/mid_throw = FALSE
	var/throw_finished = FALSE
	var/min_safe_throw_distance = 2
	var/throw_range_override = null

/datum/ai_action/throw_grenade/get_weight(datum/human_ai_brain/brain)
	if(!brain.grenade.can_throw_grenades())
		return 0

	if(!brain.combat.in_combat)
		return 0

	var/turf/target_turf = brain.targeting.get_target_turf()
	if(!target_turf)
		return 0

	if(!brain.inventory.has_equipment(HUMAN_AI_GRENADES))
		return 0

	if(!brain.inventory.has_primary_weapon())
		return 10

	if(locate(/turf/closed) in brain.tied_controller.get_line_to(target_turf))
		return 10

	return 0

/datum/ai_action/throw_grenade/get_conflicts(datum/human_ai_brain/brain)
	. = ..()
	. += /datum/ai_action/chase_target
	. += /datum/ai_action/sniper_nest

/datum/ai_action/throw_grenade/Added()
	throwing = locate() in brain.inventory.get_equipment_list(HUMAN_AI_GRENADES)
	throw_range_override = isnum(throwing?.throw_range) ? throwing.throw_range : null
	log_game("AI GRENADE: throw action created — grenade=[throwing] ([throwing?.type]), available=[english_list(brain?.inventory?.get_equipment_list(HUMAN_AI_GRENADES))], throw_range=[throw_range_override], mob=[brain?.tied_controller?.get_key_name()]")
	cancel_conflicting_actions()

/datum/ai_action/throw_grenade/Destroy(force, ...)
	throwing = null
	mid_throw = FALSE
	throw_finished = FALSE
	throw_range_override = null
	return ..()

/datum/ai_action/throw_grenade/proc/cancel_conflicting_actions()
	if(!brain)
		return

	var/list/conflicts = get_conflicts(brain)
	for(var/datum/ai_action/conflicting_action as anything in brain.action_runtime.ongoing_actions)
		if((conflicting_action != src) && (conflicting_action.type in conflicts))
			qdel(conflicting_action)

/datum/ai_action/throw_grenade/proc/try_hold_grenade(obj/item/explosive/grenade/grenade)
	if(!grenade || QDELETED(grenade) || !brain || !brain.has_valid_tied_human())
		return FALSE

	if(brain.tied_controller.get_active_hand() == grenade)
		return TRUE

	if(brain.tied_controller.get_inactive_hand() == grenade)
		brain.tied_controller.swap_hand()
		if(brain.tied_controller.get_active_hand() == grenade)
			return TRUE

	var/obj/item/active_hand = brain.tied_controller.get_active_hand()
	if(active_hand && (active_hand != grenade))
		if(active_hand.flags_item & NODROP)
			return FALSE
		brain.inventory.clear_main_hand()
		if(brain.tied_controller.get_active_hand())
			return FALSE

	if(!brain.tied_controller.is_item_equipped_or_held(grenade))
		if(!brain.inventory.equip_item_from_equipment_map(HUMAN_AI_GRENADES, grenade))
			return FALSE
	else if(!brain.tied_controller.put_in_active_hand(grenade))
		return FALSE

	brain.inventory.ensure_primary_hand(grenade)
	return brain.tied_controller.get_active_hand() == grenade

/datum/ai_action/throw_grenade/proc/can_throw_to_target(obj/item/explosive/grenade/grenade, turf/target_turf)
	if(!brain?.has_valid_tied_human() || !grenade || QDELETED(grenade) || !target_turf)
		return FALSE

	var/distance = brain.tied_controller.get_distance_to(target_turf)
	if(distance <= min_safe_throw_distance)
		return FALSE

	var/effective_throw_range = isnum(grenade.throw_range) ? grenade.throw_range : throw_range_override
	if(!isnum(effective_throw_range))
		return FALSE

	if(distance > effective_throw_range)
		return FALSE

	var/list/turf_line = brain.tied_controller.get_line_to(target_turf)
	for(var/turf/turf as anything in turf_line)
		if(turf.density)
			return FALSE

		for(var/obj/object in turf)
			if(object.density)
				return FALSE

	return TRUE

/datum/ai_action/throw_grenade/proc/get_effective_throw_range(obj/item/explosive/grenade/grenade)
	if(!grenade || QDELETED(grenade))
		return null

	var/effective_throw_range = isnum(grenade.throw_range) ? grenade.throw_range : throw_range_override
	if(!isnum(effective_throw_range))
		return null

	return effective_throw_range

/datum/ai_action/throw_grenade/proc/get_fallback_throw_directions(turf/original_target)
	var/list/directions = list()
	var/original_dir = original_target ? brain.tied_controller.get_direction_to(original_target) : 0

	if(original_dir)
		for(var/direction in make_dir_cardinal(original_dir))
			if(!(direction in directions))
				directions += direction

	if(brain.tied_controller.get_current_dir())
		for(var/direction in make_dir_cardinal(brain.tied_controller.get_current_dir()))
			if(!(direction in directions))
				directions += direction

	for(var/direction in GLOB.cardinals)
		if(!(direction in directions))
			directions += direction

	return directions

/datum/ai_action/throw_grenade/proc/has_friendly_near_throw_target(turf/target_turf)
	if(!brain || !target_turf)
		return FALSE

	for(var/mob/possible_friendly in range(brain.grenade.get_friendly_throw_check_range(), target_turf)) // SS220 EDIT: use configurable range from grenade module
		if(!brain.targeting.can_target(possible_friendly))
			return TRUE

	return FALSE

/datum/ai_action/throw_grenade/proc/resolve_throw_target(obj/item/explosive/grenade/grenade, turf/original_target)
	if(can_throw_to_target(grenade, original_target))
		return original_target

	var/effective_throw_range = get_effective_throw_range(grenade)
	if(!isnum(effective_throw_range) || (effective_throw_range <= min_safe_throw_distance))
		return null

	var/list/fallback_directions = get_fallback_throw_directions(original_target)
	for(var/direction in fallback_directions)
		var/turf/cardinal_target = brain.tied_controller.get_ranged_target_turf(direction, effective_throw_range)
		if(can_throw_to_target(grenade, cardinal_target) && !has_friendly_near_throw_target(cardinal_target))
			return cardinal_target

	for(var/direction in fallback_directions)
		for(var/candidate_range = effective_throw_range; candidate_range > min_safe_throw_distance; candidate_range--)
			var/turf/cardinal_target = brain.tied_controller.get_ranged_target_turf(direction, candidate_range)
			if(can_throw_to_target(grenade, cardinal_target))
				return cardinal_target

	return null

/datum/ai_action/throw_grenade/proc/finish_async_throw()
	mid_throw = FALSE
	throw_finished = TRUE

/datum/ai_action/throw_grenade/proc/async_prime_and_throw(datum/weakref/puppet_ref, obj/item/explosive/grenade/grenade, turf/target_turf)
	log_game("AI GRENADE: async throw started — grenade=[grenade] ([grenade?.type]), target=[target_turf], mob=[brain?.tied_controller?.get_key_name()]")
	if(QDELETED(src))
		return

	if(!brain || !brain.has_valid_tied_human() || !brain.tied_controller.matches_identity_ref(puppet_ref))
		log_game("AI GRENADE: async throw aborted — brain invalid or puppet mismatch, mob=[brain?.tied_controller?.get_key_name()]")
		finish_async_throw()
		return

	var/pre_throw_hold_delay = max(HUMAN_AI_GRENADE_MIN_HOLD_DELAY, brain.profile.short_action_delay * brain.profile.action_delay_mult)
	sleep(pre_throw_hold_delay) // SS220 EDIT: NPCs should visibly commit to the throw and hold the grenade for at least one second before priming/throwing

	if(!brain || !brain.has_valid_tied_human() || !brain.tied_controller.matches_identity_ref(puppet_ref))
		log_game("AI GRENADE: async throw aborted after pre-hold — brain invalid or mismatch, mob=[brain?.tied_controller?.get_key_name()]")
		finish_async_throw()
		return

	if(!try_hold_grenade(grenade) || !can_throw_to_target(grenade, target_turf))
		log_game("AI GRENADE: async throw aborted — hold or target check failed, grenade=[grenade], mob=[brain?.tied_controller?.get_key_name()]")
		finish_async_throw()
		return

	// SS220 EDIT START: resolve throw target BEFORE priming to avoid holding a live grenade
	var/turf/final_target_turf = resolve_throw_target(grenade, target_turf)
	if(!final_target_turf)
		log_game("AI GRENADE: async throw aborted — no valid throw target, target=[target_turf], mob=[brain?.tied_controller?.get_key_name()]")
		finish_async_throw()
		return

	brain.tied_controller.prime_grenade(grenade)
	log_game("AI GRENADE: grenade primed — grenade=[grenade], target=[final_target_turf], mob=[brain?.tied_controller?.get_key_name()]")
	if(QDELETED(grenade) || !grenade.active)
		log_game("AI GRENADE: async throw aborted after prime — QDELETED=[QDELETED(grenade)], active=[grenade?.active], mob=[brain?.tied_controller?.get_key_name()]")
		finish_async_throw()
		return

	brain.inventory.ensure_primary_hand(grenade)
	brain.communication.say_grenade_thrown_line() // SS220 EDIT: keep the voiceline inside the fixed one-second post-prime throw window
	sleep(HUMAN_AI_GRENADE_POST_PRIME_THROW_DELAY) // SS220 EDIT: generic AI should release its own primed grenade after one second, not after burning most of the fuse in hand
	if(QDELETED(grenade) || !brain.tied_controller.is_item_equipped_or_held(grenade))
		log_game("AI GRENADE: async throw aborted after post-prime hold — grenade lost, QDELETED=[QDELETED(grenade)], loc=[grenade?.loc], mob=[brain?.tied_controller?.get_key_name()]")
		finish_async_throw()
		return

	if(!try_hold_grenade(grenade))
		log_game("AI GRENADE: async throw aborted — final hold failed, grenade=[grenade], mob=[brain?.tied_controller?.get_key_name()]")
		finish_async_throw()
		return

	// SS220 EDIT START: emergency fallback if target became invalid after prime
	var/turf/emergency_target = resolve_throw_target(grenade, target_turf)
	if(!emergency_target)
		emergency_target = get_fallback_throw_directions(target_turf)
		if(length(emergency_target))
			for(var/direction in emergency_target)
				var/turf/candidate = brain.tied_controller.get_ranged_target_turf(direction, get_effective_throw_range(grenade))
				if(candidate && can_throw_to_target(grenade, candidate))
					emergency_target = candidate
					break
			if(!isturf(emergency_target))
				emergency_target = null
	if(!emergency_target)
		log_game("AI GRENADE: EMERGENCY — no valid target, dropping live grenade on floor, grenade=[grenade], mob=[brain.tied_controller.get_key_name()], loc=[brain.tied_controller.get_area_coords()]")
		msg_admin_attack("[brain.tied_controller.get_key_name()] (AI) dropped a live [grenade] on the floor — no valid throw target at [brain.tied_controller.get_area_coords()].")
		brain.tied_controller.drop_live_grenade(grenade)
		finish_async_throw()
		return
	final_target_turf = emergency_target
	// SS220 EDIT END

	brain.tied_controller.toggle_throw_mode(THROW_MODE_NORMAL)
	brain.tied_controller.throw_item(final_target_turf) // SS220 EDIT: still release the primed grenade if the original target turf became invalid during the one-second wind-up
	log_game("AI GRENADE: throw_item() called — grenade=[grenade], target=[final_target_turf], mob=[brain.tied_controller.get_key_name()]")
	finish_async_throw()

/datum/ai_action/throw_grenade/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	if(throw_finished)
		return ONGOING_ACTION_COMPLETED

	if(mid_throw)
		return ONGOING_ACTION_UNFINISHED_BLOCK

	var/turf/target_turf = brain.targeting.get_target_turf()
	if(QDELETED(throwing) || !target_turf)
		log_game("AI GRENADE: throw action aborted — grenade missing or no target, QDELETED=[QDELETED(throwing)], target=[target_turf], mob=[brain?.tied_controller?.get_key_name()]")
		return ONGOING_ACTION_COMPLETED

	var/obj/item/weapon/gun/primary_weapon = brain.inventory.get_primary_weapon()
	if(primary_weapon)
		brain.tied_controller.unwield_weapon(primary_weapon)
		if(brain.tied_controller.get_active_hand() == primary_weapon)
			brain.tied_controller.swap_hand()

	cancel_conflicting_actions() // SS220 EDIT: cancel any already-running move/fire/reload actions before the grenade is primed
	if(!try_hold_grenade(throwing))
		log_game("AI GRENADE: throw action aborted — could not hold grenade, grenade=[throwing], mob=[brain.tied_controller.get_key_name()]")
		return ONGOING_ACTION_COMPLETED

	if(isnum(throwing.throw_range))
		throw_range_override = throwing.throw_range

	if(!can_throw_to_target(throwing, target_turf))
		log_game("AI GRENADE: throw action aborted — target unreachable, distance=[brain.tied_controller.get_distance_to(target_turf)], throw_range=[throw_range_override], mob=[brain.tied_controller.get_key_name()]")
		return ONGOING_ACTION_COMPLETED

	log_game("AI GRENADE: throw action proceeding to async prime — grenade=[throwing], target=[target_turf], mob=[brain.tied_controller.get_key_name()]")
	mid_throw = TRUE
	INVOKE_ASYNC(src, PROC_REF(async_prime_and_throw), brain.tied_controller.get_identity_ref(), throwing, target_turf)
	return ONGOING_ACTION_UNFINISHED_BLOCK

#undef HUMAN_AI_GRENADE_MIN_HOLD_DELAY
#undef HUMAN_AI_GRENADE_POST_PRIME_THROW_DELAY
