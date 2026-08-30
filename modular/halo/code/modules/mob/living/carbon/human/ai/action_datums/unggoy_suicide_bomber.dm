/datum/human_ai_brain
	var/halo_suicide_bomber = FALSE
	var/halo_suicide_prime_range = 5

/datum/ai_action/unggoy_suicide_bomber
	name = "Унггой-смертник"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS

/datum/ai_action/unggoy_suicide_bomber/get_weight(datum/human_ai_brain/brain)
	if(!brain.has_valid_tied_human())
		return 0

	if(!brain.halo_suicide_bomber)
		return 0

	if(!brain.combat.in_combat || !brain.orders.can_move_for_action())
		return 0

	if(!get_charge_target(brain))
		return 0

	if(find_active_held_grenade())
		return 80

	if(!length(brain.inventory.equipment_map[HUMAN_AI_GRENADES]))
		return 0

	return 70

/datum/ai_action/unggoy_suicide_bomber/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	if(!brain.has_valid_tied_human())
		return ONGOING_ACTION_COMPLETED

	brain.cover.end_cover()

	var/obj/item/explosive/grenade/active_grenade = find_active_held_grenade()
	if(!active_grenade)
		var/atom/charge_target = get_charge_target(brain)
		if(!charge_target)
			return ONGOING_ACTION_COMPLETED

		var/target_dist = brain.tied_controller.get_distance_to(charge_target)
		if(target_dist > brain.halo_suicide_prime_range)
			if(!move_towards_target(charge_target))
				return ONGOING_ACTION_COMPLETED
			return ONGOING_ACTION_UNFINISHED_BLOCK

		if(!prime_grenades())
			return ONGOING_ACTION_COMPLETED

		active_grenade = find_active_held_grenade()
		if(!active_grenade)
			return ONGOING_ACTION_COMPLETED

	var/atom/current_target = get_charge_target(brain)
	if(!current_target)
		return ONGOING_ACTION_UNFINISHED_BLOCK

	if(brain.tied_controller.get_distance_to(current_target) <= 1)
		brain.tied_controller.face_atom(current_target)
		return ONGOING_ACTION_UNFINISHED_BLOCK

	move_towards_target(current_target)
	return ONGOING_ACTION_UNFINISHED_BLOCK

/datum/ai_action/unggoy_suicide_bomber/proc/get_charge_target(datum/human_ai_brain/brain)
	return brain.targeting.current_target || brain.targeting.target_turf

/datum/ai_action/unggoy_suicide_bomber/proc/find_active_held_grenade()
	if(!brain?.has_valid_tied_human())
		return null
	if(istype(brain.tied_controller.get_l_hand(), /obj/item/explosive/grenade))
		var/obj/item/explosive/grenade/left_grenade = brain.tied_controller.get_l_hand()
		if(left_grenade.active)
			return left_grenade

	if(istype(brain.tied_controller.get_r_hand(), /obj/item/explosive/grenade))
		var/obj/item/explosive/grenade/right_grenade = brain.tied_controller.get_r_hand()
		if(right_grenade.active)
			return right_grenade

/datum/ai_action/unggoy_suicide_bomber/proc/find_stored_grenade(obj/item/explosive/grenade/excluding = null)
	for(var/obj/item/explosive/grenade/grenade as anything in brain.inventory.equipment_map[HUMAN_AI_GRENADES])
		if(grenade == excluding)
			continue
		return grenade

/datum/ai_action/unggoy_suicide_bomber/proc/clear_both_hands()
	if(!brain || !brain.has_valid_tied_human())
		return

	brain.inventory.clear_main_hand()
	brain.tied_controller.swap_hand()
	brain.inventory.clear_main_hand()
	brain.tied_controller.swap_hand()

/datum/ai_action/unggoy_suicide_bomber/proc/prime_grenades()
	if(!brain || !brain.has_valid_tied_human())
		return FALSE

	clear_both_hands()
	if(!brain.has_valid_tied_human())
		return FALSE

	var/obj/item/explosive/grenade/first_grenade = find_stored_grenade()
	if(!first_grenade)
		return FALSE

	brain.inventory.equip_item_from_equipment_map(HUMAN_AI_GRENADES, first_grenade)
	if(QDELETED(first_grenade) || !brain.tied_controller.is_item_equipped_or_held(first_grenade))
		return FALSE

	var/obj/item/explosive/grenade/second_grenade = find_stored_grenade(first_grenade)
	if(second_grenade)
		brain.tied_controller.swap_hand()
		brain.inventory.equip_item_from_equipment_map(HUMAN_AI_GRENADES, second_grenade)
		if(QDELETED(second_grenade) || !brain.tied_controller.is_item_equipped_or_held(second_grenade))
			second_grenade = null
		brain.tied_controller.swap_hand()

	if(!brain.tied_controller.prime_grenade_no_sleep(first_grenade))
		return FALSE
	if(second_grenade)
		brain.tied_controller.prime_grenade_no_sleep(second_grenade)
	if(brain.tied_controller.has_throw_mode())
		brain.tied_controller.disable_throw_mode()

	return TRUE

/datum/ai_action/unggoy_suicide_bomber/proc/move_towards_target(atom/charge_target)
	if(!brain || !brain.has_valid_tied_human())
		return FALSE

	var/turf/charge_turf = get_turf(charge_target)
	if(brain.halo_unggoy_runtime)
		charge_turf = brain.halo_covenant_get_cached_threat_turf()
	if(!charge_turf)
		return FALSE

	if(!brain.navigation.move_to_next_turf(charge_turf))
		return FALSE

	if(!brain.has_valid_tied_human())
		return FALSE

	brain.tied_controller.face_atom(charge_target)
	return TRUE
