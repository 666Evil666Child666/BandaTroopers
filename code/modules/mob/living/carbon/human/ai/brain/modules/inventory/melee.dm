/// Quick and dirty proc to holster a melee weapon if the AI is holding one.
/datum/human_ai_module/inventory/proc/holster_melee()
	if(!drawn_melee_weapon)
		return TRUE

	if(!brain.tied_controller.is_item_equipped_or_held(drawn_melee_weapon))
		on_melee_dropped()
		return TRUE

	if(brain.tied_controller.can_insert_into_shoes(drawn_melee_weapon))
		return brain.tied_controller.attempt_insert_into_shoes(drawn_melee_weapon)

	brain.tied_controller.drop_held_item(drawn_melee_weapon)
	return FALSE

/// Melee system currently only supports bootknives.
/datum/human_ai_module/inventory/proc/unholster_melee()
	if(brain.tied_controller.has_item_in_hands())
		return TRUE

	var/cur_hand = brain.tied_controller.get_active_hand()
	if(cur_hand)
		brain.tied_controller.drop_held_item(cur_hand)

	if(brain.tied_controller.get_shoes())
		var/obj/item/melee_weapon = brain.tied_controller.remove_item_from_shoes()
		drawn_melee_weapon = melee_weapon
		RegisterSignal(drawn_melee_weapon, COMSIG_ITEM_DROPPED, PROC_REF(on_melee_dropped))
		return melee_weapon
