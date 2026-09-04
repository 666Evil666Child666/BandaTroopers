/datum/human_ai_module/inventory/proc/set_primary_weapon(obj/item/weapon/gun/new_gun)
	if(primary_weapon)
		UnregisterSignal(primary_weapon, COMSIG_PARENT_QDELETING)
	if(new_gun && !can_select_firearm(new_gun))
		new_gun = null
	primary_weapon = new_gun
	appraise_primary()
	invalidate_nearby_item_search()
	brain.invalidate_halo_runtime_caches()
	if(primary_weapon)
		RegisterSignal(primary_weapon, COMSIG_PARENT_QDELETING, PROC_REF(on_primary_delete), TRUE)

/datum/human_ai_module/inventory/proc/add_secondary_weapon(obj/item/weapon/gun/secondary)
	if(!secondary || has_secondary_weapon(secondary) || !can_select_firearm(secondary))
		return

	secondary_weapons += secondary
	RegisterSignal(secondary, COMSIG_PARENT_QDELETING, PROC_REF(on_secondary_delete), TRUE)

/datum/human_ai_module/inventory/proc/remove_secondary_weapon(obj/item/weapon/gun/secondary)
	UnregisterSignal(secondary, COMSIG_PARENT_QDELETING)
	secondary_weapons -= secondary

/datum/human_ai_module/inventory/proc/get_next_secondary_weapon()
	RETURN_TYPE(/obj/item/weapon/gun)

	var/obj/item/weapon/gun/best_secondary
	var/best_secondary_weight = 0
	for(var/obj/item/weapon/gun/secondary as anything in secondary_weapons)
		if(!can_select_firearm(secondary) || !brain.tied_controller.can_use_item(secondary))
			continue

		var/datum/human_ai_firearm_context/context = new(secondary, brain)
		var/datum/human_ai_firearm_handler/handler = context.get_handler()
		var/secondary_weight = handler?.get_primary_weight(context) || 0
		qdel(context)
		if(!best_secondary || secondary_weight > best_secondary_weight)
			best_secondary = secondary
			best_secondary_weight = secondary_weight
			continue

	return best_secondary

/// Unholsters the AI's primary weapon, dropping anything that might obstruct it.
/datum/human_ai_module/inventory/proc/unholster_primary()
	if(!primary_weapon || brain.tied_controller.get_l_hand() == primary_weapon || brain.tied_controller.get_r_hand() == primary_weapon)
		return

	var/cur_hand = brain.tied_controller.get_active_hand()
	if(cur_hand)
		brain.tied_controller.drop_held_item(cur_hand)

	brain.tied_controller.u_equip(primary_weapon)
	brain.tied_controller.put_in_active_hand(primary_weapon)

	primary_weapon.guaranteed_delay_time = world.time
	primary_weapon.wield_time = world.time
	primary_weapon.pull_time = world.time

/// Tells the AI to wield their primary weapon, can be called if they aren't holding it or if they are already wielding it
/datum/human_ai_module/inventory/proc/wield_primary()
	brain.tied_controller.wield(primary_weapon)

/// wield_primary() with a delay inbuilt
/datum/human_ai_module/inventory/proc/wield_primary_sleep()
	wield_primary()
	sleep(max(primary_weapon?.wield_delay, brain.profile.short_action_delay * brain.profile.action_delay_mult))

/// Tells the AI to unwield *something*, prioritizing melee
/datum/human_ai_module/inventory/proc/unholster_any_weapon()
	if(brain.tied_controller.is_zombie())
		var/cur_hand = brain.tied_controller.get_active_hand()
		if(isnull(cur_hand)) //Check if we have a hand. If not try the other one? Claws are stuck to hands so if this is null we've lost the hand
			var/obj/limb/hand/r_hand/right_hand	= brain.tied_controller.get_limb("r_hand")
			var/obj/limb/hand/l_hand/left_hand = brain.tied_controller.get_limb("l_hand")
			if(!(left_hand.status & LIMB_DESTROYED) || !(right_hand.status & LIMB_DESTROYED)) //We have hands?
				brain.tied_controller.swap_hand()
				cur_hand = brain.tied_controller.get_active_hand()
			else
				return FALSE
	if(unholster_melee())
		brain.tied_controller.set_grab_intent()
		return TRUE
	if(primary_weapon)
		unholster_primary()
		ensure_primary_hand(primary_weapon)
		wield_primary()
		brain.tied_controller.set_grab_intent()
		return TRUE
	// insert any viable weapon slot macros in here

/// Holsters the AI's primary weapon if possible
/datum/human_ai_module/inventory/proc/holster_primary()
	if(brain.tied_controller.get_s_store() || (brain.tied_controller.get_l_hand() != primary_weapon && brain.tied_controller.get_r_hand() != primary_weapon))
		return FALSE

	return brain.tied_controller.equip_to_slot_if_possible(primary_weapon, WEAR_J_STORE, TRUE)

/// Assuming an item is in the AI's hands, this ensures it is their actively selected hand
/datum/human_ai_module/inventory/proc/ensure_primary_hand(obj/item/held_item)
	if(brain.tied_controller.get_inactive_hand() == held_item)
		brain.tied_controller.swap_hand()
