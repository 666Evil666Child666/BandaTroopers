// Raw hand read primitives

/datum/human_tied_controller/proc/get_active_hand()
	RETURN_TYPE(/obj/item)
	return tied_human?.get_active_hand()

/datum/human_tied_controller/proc/get_inactive_hand()
	RETURN_TYPE(/obj/item)
	return tied_human?.get_inactive_hand()

/datum/human_tied_controller/proc/get_held_item()
	RETURN_TYPE(/obj/item)
	return tied_human?.get_held_item()

/datum/human_tied_controller/proc/is_holding(obj/item/item)
	return tied_human?.is_holding(item)

/datum/human_tied_controller/proc/get_hand_holding(obj/item/item)
	if(!can_read_puppet() || !item)
		return null
	if(tied_human.get_active_hand() == item)
		return "active"
	if(tied_human.get_inactive_hand() == item)
		return "inactive"
	return null

// Raw hand mutation primitives

/datum/human_tied_controller/proc/swap_hand()
	if(!can_mutate_puppet())
		return FALSE
	tied_human.swap_hand()
	return TRUE

/datum/human_tied_controller/proc/put_in_active_hand(obj/item/item)
	if(!can_mutate_puppet() || !item)
		return FALSE
	return tied_human.put_in_active_hand(item)

/datum/human_tied_controller/proc/put_in_hands(obj/item/item, force = TRUE)
	if(!can_mutate_puppet() || !item)
		return FALSE
	return tied_human.put_in_hands(item, force)

/datum/human_tied_controller/proc/drop_held_item(obj/item/item)
	if(!can_mutate_puppet() || !item)
		return FALSE
	return tied_human.drop_held_item(item)

/datum/human_tied_controller/proc/drop_inv_item_on_ground(obj/item/item)
	if(!can_mutate_puppet() || !item)
		return FALSE
	return tied_human.drop_inv_item_on_ground(item)

/datum/human_tied_controller/proc/u_equip(obj/item/item)
	if(!can_mutate_puppet() || !item)
		return FALSE
	return tied_human.u_equip(item)

/datum/human_tied_controller/proc/equip_to_slot(obj/item/item, slot, force = TRUE)
	if(!can_mutate_puppet() || !item || !slot)
		return FALSE
	return tied_human.equip_to_slot(item, slot, force)

/datum/human_tied_controller/proc/equip_to_slot_if_possible(obj/item/item, slot, force = TRUE)
	if(!can_mutate_puppet() || !item || !slot)
		return FALSE
	return tied_human.equip_to_slot_if_possible(item, slot, force)

/datum/human_tied_controller/proc/equip_to_slot_or_del(obj/item/item, slot, force = TRUE)
	if(!can_mutate_puppet() || !item || !slot)
		return FALSE
	return tied_human.equip_to_slot_or_del(item, slot, force)

/datum/human_tied_controller/proc/get_equipped_items(include_pockets = FALSE)
	if(!can_read_puppet())
		return list()
	return tied_human.get_equipped_items(include_pockets)

// Behavior helpers

/datum/human_tied_controller/proc/ensure_active_hand(obj/item/held_item)
	if(!can_mutate_puppet() || !held_item)
		return FALSE
	if(tied_human.get_inactive_hand() == held_item)
		tied_human.swap_hand()
	return tied_human.get_active_hand() == held_item

/datum/human_tied_controller/proc/can_clear_active_hand()
	var/obj/item/active_item = get_active_hand()
	return can_mutate_puppet() && active_item && !(active_item.flags_item & NODROP)

/datum/human_tied_controller/proc/clear_active_hand_if_possible()
	if(!can_clear_active_hand())
		return FALSE
	return drop_held_item(get_active_hand())
