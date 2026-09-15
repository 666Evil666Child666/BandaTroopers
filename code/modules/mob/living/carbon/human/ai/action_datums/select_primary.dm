/datum/ai_action/select_primary
	name = "Select Primary"
	action_flags = ACTION_USING_HANDS
	required_ai_modules = list(/datum/human_ai_module/guns, /datum/human_ai_module/inventory)

/datum/ai_action/select_primary/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return 0

	if(!brain.has_secondary_weapons())
		return 0

	if(!brain.has_tried_reload() && brain.has_primary_weapon())
		return 0

	if(controller.can_use_item(brain.get_primary_weapon()))
		return 0

	return 12

/datum/ai_action/select_primary/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	UNLINT(decide_primary_weapon())
	return ONGOING_ACTION_COMPLETED

/datum/ai_action/select_primary/proc/decide_primary_weapon()
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return

	var/obj/item/weapon/gun/best_secondary = brain.get_next_secondary_weapon()
	if(!best_secondary)
		return

	var/obj/item/weapon/gun/primary_weapon = brain.get_primary_weapon()
	if(primary_weapon && controller.is_holding(primary_weapon))
		var/possible_storage_loc = brain.storage_has_room(primary_weapon)
		if((primary_weapon.flags_equip_slot & SLOT_BACK) && !controller.get_back())
			controller.equip_to_slot(primary_weapon, WEAR_BACK, TRUE)
		else if(!controller.get_s_store() && controller.get_wear_suit() && ((primary_weapon.flags_equip_slot & SLOT_SUIT_STORE) || is_type_in_list(primary_weapon, controller.get_wear_suit().allowed)))
			controller.equip_to_slot(primary_weapon, WEAR_J_STORE, TRUE)
		else if(possible_storage_loc)
			brain.store_item(primary_weapon, possible_storage_loc)

	brain.add_secondary_weapon(primary_weapon)
	brain.set_primary_weapon(best_secondary)
	brain.clear_tried_reload()
	return best_secondary
