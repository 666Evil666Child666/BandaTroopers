/datum/human_ai_module/inventory/proc/get_container_ref(container_id)
	RETURN_TYPE(/obj/item/storage)
	return container_refs[container_id]

/datum/human_ai_module/inventory/proc/has_container_ref(container_id)
	return !!get_container_ref(container_id)

/datum/human_ai_module/inventory/proc/reset_container_refs()
	container_refs = list(
		HUMAN_AI_STORAGE_BELT = null,
		HUMAN_AI_STORAGE_BACKPACK = null,
		HUMAN_AI_STORAGE_LEFT_POCKET = null,
		HUMAN_AI_STORAGE_RIGHT_POCKET = null,
		HUMAN_AI_STORAGE_ARMOR = null,
		HUMAN_AI_STORAGE_UNIFORM = null,
	)

/datum/human_ai_module/inventory/proc/set_container_ref(container_id, obj/item/storage/container)
	if(!container_id)
		return FALSE

	container_refs[container_id] = container
	return TRUE

/datum/human_ai_module/inventory/proc/clear_container_ref(container_id)
	if(!container_id || !(container_id in container_refs))
		return FALSE

	container_refs[container_id] = null
	return TRUE

/datum/human_ai_module/inventory/proc/clear_container_ref_for_item(obj/item/item)
	if(!item)
		return FALSE

	var/cleared = FALSE
	for(var/container_id in container_refs)
		if(get_container_ref(container_id) != item)
			continue

		clear_container_ref(container_id)
		cleared = TRUE

	return cleared

/datum/human_ai_module/inventory/proc/get_container_id_for_item(obj/item/item)
	if(!item)
		return null

	for(var/container_id in container_refs)
		if(get_container_ref(container_id) == item)
			return container_id

	return null

/datum/human_ai_module/inventory/proc/remember_equipped_item_origin(obj/item/item, storage_id)
	if(!item || !storage_id)
		return FALSE

	equipped_items_original_loc[item] = storage_id
	return TRUE

/datum/human_ai_module/inventory/proc/forget_equipped_item_origin(obj/item/item)
	if(!item)
		return FALSE
	if(!(item in equipped_items_original_loc))
		return FALSE

	equipped_items_original_loc -= item
	return TRUE

/datum/human_ai_module/inventory/proc/has_equipped_item_origin(obj/item/item)
	return item && (item in equipped_items_original_loc)

/datum/human_ai_module/inventory/proc/take_equipped_item_origin(obj/item/item)
	if(!has_equipped_item_origin(item))
		return null

	var/storage_id = equipped_items_original_loc[item]
	forget_equipped_item_origin(item)
	return storage_id

/// Given a "storage type", returns the storage item
/datum/human_ai_module/inventory/proc/get_object_from_loc(object_loc)
	RETURN_TYPE(/obj/item/storage)

	return brain.tied_controller.get_storage_from_loc(object_loc)

/// Given a location and a reference, puts a referenced object into the AI's hand if possible
/datum/human_ai_module/inventory/proc/equip_item_from_equipment_map(object_type, obj/item/object_ref)
	if(!object_type || !object_ref)
		return

	var/object_loc = get_equipment_location(object_ref, object_type)
	var/obj/item/storage/storage_object = get_object_from_loc(object_loc)
	if(brain.tied_controller.is_item_equipped_or_held(object_ref))
		remember_equipped_item_origin(object_ref, object_loc)
		RegisterSignal(object_ref, COMSIG_ITEM_DROPPED, PROC_REF(on_equipment_dropped), override = TRUE)
		return brain.tied_controller.put_in_active_hand(object_ref)

	if(!storage_object)
		remove_from_equipment_map(object_ref, object_type)
		forget_equipped_item_origin(object_ref)
		return

	if(object_ref.loc != storage_object)
		remove_from_equipment_map(object_ref, object_type)
		forget_equipped_item_origin(object_ref)
		return

	brain.tied_controller.remove_from_storage(storage_object, object_ref)
	remember_equipped_item_origin(object_ref, object_loc)
	RegisterSignal(object_ref, COMSIG_ITEM_DROPPED, PROC_REF(on_equipment_dropped), override = TRUE)

	return brain.tied_controller.put_in_active_hand(object_ref)

/datum/human_ai_module/inventory/proc/store_item(obj/item/object_ref, object_loc, slot_type)
	if(slot_type)
		return store_item_as_types(object_ref, object_loc, list(slot_type))

	return store_item_as_types(object_ref, object_loc)

/datum/human_ai_module/inventory/proc/store_item_by_flags(obj/item/object_ref, object_loc)
	return store_item_as_types(object_ref, object_loc, get_equipment_types_for_item(object_ref))

/datum/human_ai_module/inventory/proc/store_item_as_types(obj/item/object_ref, object_loc, list/slot_types)
	// SS220 EDIT - START: late AI store callbacks can outlive the held item, owner, or original storage slot
	if(!brain.has_valid_tied_human() || QDELETED(object_ref))
		unqueue_pickup(object_ref)
		forget_equipped_item_origin(object_ref)
		remove_from_equipment_maps(object_ref)
		return FALSE

	if(!brain.tied_controller.is_item_equipped_or_held(object_ref))
		unqueue_pickup(object_ref)
		forget_equipped_item_origin(object_ref)
		remove_from_equipment_maps(object_ref)
		return FALSE

	var/storage_loc = object_loc
	var/obj/item/storage/storage_object

	if(has_equipped_item_origin(object_ref))
		storage_loc = take_equipped_item_origin(object_ref)
		storage_object = get_object_from_loc(storage_loc)
	else if(storage_loc) // we assume that we've already checked if something will fit or not
		storage_object = get_container_ref(storage_loc)

	if(!storage_object || !brain.tied_controller.attempt_item_insertion(storage_object, object_ref, FALSE))
		remove_from_equipment_maps(object_ref)
		if(brain.tied_controller.is_holding(object_ref))
			brain.tied_controller.drop_held_item(object_ref)
		unqueue_pickup(object_ref)
		return FALSE

	set_equipment_locations(object_ref, storage_loc, slot_types)

	unqueue_pickup(object_ref)
	return TRUE
	// SS220 EDIT - END

/// Reappraises what storage items the AI has
/datum/human_ai_module/inventory/proc/recalculate_containers()
	reset_container_refs()
	if(isstorage(brain.tied_controller.get_belt()))
		set_container_ref(HUMAN_AI_STORAGE_BELT, brain.tied_controller.get_belt())
	if(isstorage(brain.tied_controller.get_back()))
		set_container_ref(HUMAN_AI_STORAGE_BACKPACK, brain.tied_controller.get_back())
	if(isstorage(brain.tied_controller.get_l_store()))
		set_container_ref(HUMAN_AI_STORAGE_LEFT_POCKET, brain.tied_controller.get_l_store())
	if(isstorage(brain.tied_controller.get_r_store()))
		set_container_ref(HUMAN_AI_STORAGE_RIGHT_POCKET, brain.tied_controller.get_r_store())
	if(istype(brain.tied_controller.get_wear_suit(), /obj/item/clothing/suit/storage))
		var/obj/item/clothing/suit/storage/storage_suit = brain.tied_controller.get_wear_suit()
		set_container_ref(HUMAN_AI_STORAGE_ARMOR, storage_suit.pockets)
	if(isclothing(brain.tied_controller.get_w_uniform()))
		var/obj/item/clothing/accessory/storage/storage_accessory = locate(/obj/item/clothing/accessory/storage) in brain.tied_controller.get_w_uniform().accessories
		if(storage_accessory)
			set_container_ref(HUMAN_AI_STORAGE_UNIFORM, storage_accessory.hold)

/datum/human_ai_module/inventory/proc/storage_has_room(obj/item/inserting)
	for(var/container_id in container_refs)
		var/obj/item/storage/container = get_container_ref(container_id)
		if(brain.tied_controller.can_be_inserted(container, inserting, TRUE))
			return container_id
