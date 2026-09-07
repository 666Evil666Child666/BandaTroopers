/datum/human_ai_brain
	var/halo_suicide_bomber = FALSE
	var/halo_suicide_prime_range = 5

/datum/ai_action/unggoy_suicide_bomber
	name = "Унггой-смертник"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/targeting, /datum/human_ai_module/navigation, /datum/human_ai_module/inventory, /datum/human_ai_module/action_runtime)

/datum/ai_action/unggoy_suicide_bomber/get_weight(datum/human_ai_brain/brain)
	if(!brain.has_valid_tied_human())
		return 0

	if(!brain.halo_suicide_bomber)
		return 0

	if(!brain.halo_covenant_can_run_movement_action())
		return 0

	if(!get_charge_target(brain))
		return 0

	if(find_active_held_grenade())
		return 80

	if(!brain.halo_covenant_has_grenade_equipment())
		return 0

	return 70

/datum/ai_action/unggoy_suicide_bomber/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	if(!brain.has_valid_tied_human())
		return ONGOING_ACTION_COMPLETED

	brain.halo_covenant_end_cover()

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
	return brain.halo_covenant_get_threat_atom()

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
	return brain.halo_covenant_get_stored_grenade(excluding)

/datum/ai_action/unggoy_suicide_bomber/proc/clear_both_hands()
	brain?.halo_covenant_clear_both_hands()

/datum/ai_action/unggoy_suicide_bomber/proc/prime_grenades()
	if(!brain || !brain.has_valid_tied_human())
		return FALSE

	clear_both_hands()
	if(!brain.has_valid_tied_human())
		return FALSE

	var/obj/item/explosive/grenade/first_grenade = find_stored_grenade()
	if(!first_grenade)
		return FALSE

	brain.halo_covenant_equip_grenade(first_grenade)
	if(QDELETED(first_grenade) || !brain.tied_controller.is_item_equipped_or_held(first_grenade))
		return FALSE

	var/obj/item/explosive/grenade/second_grenade = find_stored_grenade(first_grenade)
	if(second_grenade)
		brain.tied_controller.swap_hand()
		brain.halo_covenant_equip_grenade(second_grenade)
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

	return brain.halo_covenant_move_to_atom(charge_target, brain.halo_unggoy_runtime)
