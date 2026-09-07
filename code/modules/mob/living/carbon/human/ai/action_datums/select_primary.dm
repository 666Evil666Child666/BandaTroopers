/datum/ai_action/select_primary
	name = "Select Primary"
	action_flags = ACTION_USING_HANDS

/datum/ai_action/select_primary/get_weight(datum/human_ai_brain/brain)
	if(!brain.has_secondary_weapons())
		return 0

	if(!brain.has_tried_reload() && brain.has_primary_weapon())
		return 0

	if(brain.tied_controller.can_use_item(brain.get_primary_weapon()))
		return 0

	return 12

/datum/ai_action/select_primary/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .
	UNLINT(decide_primary_weapon())
	return ONGOING_ACTION_COMPLETED

/datum/ai_action/select_primary/proc/decide_primary_weapon()
	var/obj/item/weapon/gun/best_secondary = brain.get_next_secondary_weapon()
	if(!best_secondary)
		return

	var/obj/item/weapon/gun/primary_weapon = brain.get_primary_weapon()
	if(primary_weapon && brain.tied_controller.is_holding(primary_weapon))
		var/possible_storage_loc = brain.storage_has_room(primary_weapon)
		if((primary_weapon.flags_equip_slot & SLOT_BACK) && !brain.tied_controller.get_back())
			brain.tied_controller.equip_to_slot(primary_weapon, WEAR_BACK, TRUE)
		else if(!brain.tied_controller.get_s_store() && brain.tied_controller.get_wear_suit() && ((primary_weapon.flags_equip_slot & SLOT_SUIT_STORE) || is_type_in_list(primary_weapon, brain.tied_controller.get_wear_suit().allowed)))
			brain.tied_controller.equip_to_slot(primary_weapon, WEAR_J_STORE, TRUE)
		else if(possible_storage_loc)
			brain.store_item(primary_weapon, possible_storage_loc)

	brain.add_secondary_weapon(primary_weapon)
	brain.set_primary_weapon(best_secondary)
	brain.clear_tried_reload()
	return best_secondary
