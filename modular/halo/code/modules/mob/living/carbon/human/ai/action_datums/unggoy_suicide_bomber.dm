/datum/ai_action/unggoy_suicide_bomber
	name = "Унггой-смертник"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/targeting, /datum/human_ai_module/navigation, /datum/human_ai_module/inventory, /datum/human_ai_module/action_runtime, /datum/human_ai_module/halo_covenant, /datum/human_ai_module/halo_unggoy)

/datum/ai_action/unggoy_suicide_bomber/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	if(!brain?.has_valid_tied_human())
		return 0

	if(!brain.halo_unggoy_is_suicide_bomber())
		return 0

	if(!brain.halo_covenant_can_run_movement_action())
		return 0

	if(!get_charge_target(brain))
		return 0

	if(find_active_held_grenade(context))
		return 80

	if(!brain.halo_covenant_has_grenade_equipment())
		return 0

	return 70

/datum/ai_action/unggoy_suicide_bomber/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain?.has_valid_tied_human() || !controller)
		return ONGOING_ACTION_COMPLETED

	brain.halo_covenant_end_cover()

	var/obj/item/explosive/grenade/active_grenade = find_active_held_grenade(context)
	if(!active_grenade)
		var/atom/charge_target = get_charge_target(brain)
		if(!charge_target)
			return ONGOING_ACTION_COMPLETED

		var/target_dist = controller.get_distance_to(charge_target)
		if(target_dist > brain.halo_unggoy_get_suicide_prime_range())
			if(!move_towards_target(charge_target, context))
				return ONGOING_ACTION_COMPLETED
			return ONGOING_ACTION_UNFINISHED_BLOCK

		if(!prime_grenades(context))
			return ONGOING_ACTION_COMPLETED

		active_grenade = find_active_held_grenade(context)
		if(!active_grenade)
			return ONGOING_ACTION_COMPLETED

	var/atom/current_target = get_charge_target(brain)
	if(!current_target)
		return ONGOING_ACTION_UNFINISHED_BLOCK

	if(controller.get_distance_to(current_target) <= 1)
		controller.face_atom(current_target)
		return ONGOING_ACTION_UNFINISHED_BLOCK

	move_towards_target(current_target, context)
	return ONGOING_ACTION_UNFINISHED_BLOCK

/datum/ai_action/unggoy_suicide_bomber/proc/get_charge_target(datum/human_ai_brain/brain)
	return brain.halo_covenant_get_threat_atom()

/datum/ai_action/unggoy_suicide_bomber/proc/find_active_held_grenade(datum/human_ai_context/action_context)
	var/datum/human_ai_brain/brain = action_context?.brain
	var/datum/human_tied_controller/controller = action_context?.controller
	if(!brain?.has_valid_tied_human() || !controller)
		return null
	if(istype(controller.get_l_hand(), /obj/item/explosive/grenade))
		var/obj/item/explosive/grenade/left_grenade = controller.get_l_hand()
		if(left_grenade.active)
			return left_grenade

	if(istype(controller.get_r_hand(), /obj/item/explosive/grenade))
		var/obj/item/explosive/grenade/right_grenade = controller.get_r_hand()
		if(right_grenade.active)
			return right_grenade

/datum/ai_action/unggoy_suicide_bomber/proc/find_stored_grenade(datum/human_ai_context/action_context, obj/item/explosive/grenade/excluding = null)
	var/datum/human_ai_brain/brain = action_context?.brain
	if(!brain)
		return null

	return brain.halo_covenant_get_stored_grenade(excluding)

/datum/ai_action/unggoy_suicide_bomber/proc/clear_both_hands(datum/human_ai_context/action_context)
	var/datum/human_ai_brain/brain = action_context?.brain
	brain?.halo_covenant_clear_both_hands()

/datum/ai_action/unggoy_suicide_bomber/proc/prime_grenades(datum/human_ai_context/action_context)
	var/datum/human_ai_brain/brain = action_context?.brain
	var/datum/human_tied_controller/controller = action_context?.controller
	if(!brain || !controller || !brain.has_valid_tied_human())
		return FALSE

	clear_both_hands(action_context)
	if(!brain.has_valid_tied_human())
		return FALSE

	var/obj/item/explosive/grenade/first_grenade = find_stored_grenade(action_context)
	if(!first_grenade)
		return FALSE

	brain.halo_covenant_equip_grenade(first_grenade)
	if(QDELETED(first_grenade) || !controller.is_item_equipped_or_held(first_grenade))
		return FALSE

	var/obj/item/explosive/grenade/second_grenade = find_stored_grenade(action_context, first_grenade)
	if(second_grenade)
		controller.swap_hand()
		brain.halo_covenant_equip_grenade(second_grenade)
		if(QDELETED(second_grenade) || !controller.is_item_equipped_or_held(second_grenade))
			second_grenade = null
		controller.swap_hand()

	if(!controller.prime_grenade_no_sleep(first_grenade))
		return FALSE
	if(second_grenade)
		controller.prime_grenade_no_sleep(second_grenade)
	if(controller.has_throw_mode())
		controller.disable_throw_mode()

	return TRUE

/datum/ai_action/unggoy_suicide_bomber/proc/move_towards_target(atom/charge_target, datum/human_ai_context/action_context)
	var/datum/human_ai_brain/brain = action_context?.brain
	if(!brain || !brain.has_valid_tied_human())
		return FALSE

	return brain.halo_covenant_move_to_atom(charge_target, brain.halo_unggoy_is_active())
