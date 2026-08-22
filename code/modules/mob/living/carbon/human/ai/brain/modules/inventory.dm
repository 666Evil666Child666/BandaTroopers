/datum/human_ai_module/inventory
	/// If an AI takes out an item from their equipment_map, the place it was last stored is added to this dict
	var/list/equipped_items_original_loc = list()
	/// A list of items that the AI is trying to pick up
	var/list/obj/item/to_pickup = list()
	/// The firearm the AI is using as its primary weapon
	var/obj/item/weapon/gun/primary_weapon
	/// Any other firearms the AI has that it considers "secondary"
	var/list/obj/item/weapon/gun/secondary_weapons = list()
	/// Ref to the latest weapon we've drawn as a melee
	var/obj/item/drawn_melee_weapon
	//var/obj/item/weapon/primary_melee
	/// Appraisal datum
	var/datum/firearm_appraisal/gun_data
	/// If TRUE, the AI won't try to pick up anything
	var/ignore_looting = FALSE
	/// If TRUE, the AI ignores darkness when it comes to determining vision
	var/has_nightvision = FALSE
	/// Optional throttle for nearby item scans. Zero means run every tick.
	var/nearby_item_search_interval = 0
	COOLDOWN_DECLARE(nearby_item_search_cooldown)
	var/nearby_item_search_dirty = FALSE

	/// list("object_type" = list(object_ref = "slot")
	var/list/equipment_map = list(
		HUMAN_AI_HEALTHITEMS = list(),
		HUMAN_AI_AMMUNITION = list(),
		HUMAN_AI_GRENADES = list(),
		HUMAN_AI_TOOLS = list(),
	)

	/// Dict of "storage type" : storage ref
	var/list/container_refs = list(
		"belt" = null,
		"backpack" = null,
		"left_pocket" = null,
		"right_pocket" = null,
		"armor" = null,
		"uniform" = null,
	)

	/// Static list of storage slots that the AI pays attention to for inventory appraisal
	var/static/list/important_storage_slots = list(
		WEAR_BACK,
		WEAR_WAIST,
		WEAR_L_STORE,
		WEAR_R_STORE,
		WEAR_JACKET,
		WEAR_BODY,
	)

	/// Bitflag equivalent of important_storage_slots
	var/static/important_storage_slots_bitflag = SLOT_BACK | SLOT_WAIST | SLOT_STORE | SLOT_OCLOTHING | SLOT_ICLOTHING

/datum/human_ai_module/inventory/proc/register_signals()
	if(!brain.has_valid_tied_human())
		return

	RegisterSignal(brain.tied_human, COMSIG_HUMAN_EQUIPPED_ITEM, PROC_REF(on_item_equip))
	RegisterSignal(brain.tied_human, COMSIG_HUMAN_UNEQUIPPED_ITEM, PROC_REF(on_item_unequip))
	RegisterSignal(brain.tied_human, COMSIG_MOB_PICKUP_ITEM, PROC_REF(on_item_pickup))
	RegisterSignal(brain.tied_human, COMSIG_MOB_DROP_ITEM, PROC_REF(on_item_drop))

/datum/human_ai_module/inventory/proc/reset_inventory()
	drawn_melee_weapon = null
	primary_weapon = null
	gun_data = null
	to_pickup.Cut()
	invalidate_nearby_item_search()

/datum/human_ai_module/inventory/proc/should_run_nearby_item_search()
	if(brain.halo_should_suspend_nearby_item_search())
		return FALSE

	if(nearby_item_search_interval <= 0)
		return TRUE

	if(!nearby_item_search_dirty && !COOLDOWN_FINISHED(src, nearby_item_search_cooldown))
		return FALSE

	nearby_item_search_dirty = FALSE
	COOLDOWN_START(src, nearby_item_search_cooldown, nearby_item_search_interval)
	return TRUE

/// Given a "storage type", returns the storage item
/datum/human_ai_module/inventory/proc/get_object_from_loc(object_loc)
	RETURN_TYPE(/obj/item/storage)

	var/obj/item/storage/storage_object
	switch(object_loc)
		if("belt")
			storage_object = brain.tied_human.belt
		if("backpack")
			storage_object = brain.tied_human.back
		if("left_pocket")
			storage_object = brain.tied_human.l_store
		if("right_pocket")
			storage_object = brain.tied_human.r_store
		if("armor")
			if(istype(brain.tied_human.wear_suit, /obj/item/clothing/suit/storage))
				var/obj/item/clothing/suit/storage/storage_suit = brain.tied_human.wear_suit
				storage_object = storage_suit.pockets
		if("uniform")
			if(isclothing(brain.tied_human.w_uniform))
				var/obj/item/clothing/accessory/storage/storage_accessory = locate(/obj/item/clothing/accessory/storage) in brain.tied_human.w_uniform.accessories
				storage_object = storage_accessory.hold
	return storage_object

/// Given a location and a reference, puts a referenced object into the AI's hand if possible
/datum/human_ai_module/inventory/proc/equip_item_from_equipment_map(object_type, obj/item/object_ref)
	if(!object_type || !object_ref)
		return

	var/object_loc = equipment_map[object_type][object_ref]
	var/obj/item/storage/storage_object = get_object_from_loc(object_loc)
	if(object_ref.loc == brain.tied_human)
		equipped_items_original_loc[object_ref] = object_loc
		RegisterSignal(object_ref, COMSIG_ITEM_DROPPED, PROC_REF(on_equipment_dropped), override = TRUE)
		return brain.tied_human.put_in_active_hand(object_ref)

	if(!storage_object)
		equipment_map[object_type] -= object_ref
		equipped_items_original_loc -= object_ref
		return

	if(object_ref.loc != storage_object)
		equipment_map[object_type] -= object_ref
		equipped_items_original_loc -= object_ref
		return

	storage_object.remove_from_storage(object_ref, brain.tied_human)
	equipped_items_original_loc[object_ref] = object_loc
	RegisterSignal(object_ref, COMSIG_ITEM_DROPPED, PROC_REF(on_equipment_dropped), override = TRUE)

	return brain.tied_human.put_in_active_hand(object_ref)

/datum/human_ai_module/inventory/proc/on_equipment_dropped(obj/item/source, mob/dropper)
	SIGNAL_HANDLER

	if(isturf(source.loc))
		equipped_items_original_loc -= source
		UnregisterSignal(source, COMSIG_ITEM_DROPPED)

/// Given an object path and where it may be stored, returns a ref to that object if it exists
/datum/human_ai_module/inventory/proc/get_item_from_equipment_map_path(object_path, object_type)
	return (locate(object_path) in equipment_map[object_type])

/datum/human_ai_module/inventory/proc/store_item(obj/item/object_ref, object_loc, slot_type)
	// SS220 EDIT - START: late AI store callbacks can outlive the held item, owner, or original storage slot
	if(!brain.has_valid_tied_human() || QDELETED(object_ref))
		to_pickup -= object_ref
		equipped_items_original_loc -= object_ref
		if(slot_type)
			equipment_map[slot_type] -= object_ref
		return FALSE

	if(object_ref.loc != brain.tied_human)
		to_pickup -= object_ref
		equipped_items_original_loc -= object_ref
		if(slot_type)
			equipment_map[slot_type] -= object_ref
		return FALSE

	var/storage_loc = object_loc
	var/obj/item/storage/storage_object

	if(object_ref in equipped_items_original_loc)
		storage_loc = equipped_items_original_loc[object_ref]
		storage_object = get_object_from_loc(storage_loc)
		equipped_items_original_loc -= object_ref
	else if(storage_loc) // we assume that we've already checked if something will fit or not
		storage_object = container_refs[storage_loc]

	if(!storage_object || !storage_object.attempt_item_insertion(object_ref, FALSE, brain.tied_human))
		if(slot_type)
			equipment_map[slot_type] -= object_ref
		if(brain.tied_human.is_holding(object_ref))
			brain.tied_human.drop_held_item(object_ref)
		to_pickup -= object_ref
		return FALSE

	if(slot_type)
		equipment_map[slot_type][object_ref] = storage_loc

	to_pickup -= object_ref
	return TRUE
	// SS220 EDIT - END

/// Whenever an item is deleted, purge it from anywhere it may be stored in here
/datum/human_ai_module/inventory/proc/on_item_delete(obj/item/source, force)
	SIGNAL_HANDLER

	UnregisterSignal(source, COMSIG_PARENT_QDELETING)
	to_pickup -= source
	if(source == brain.grenade.active_grenade_found) // SS220 EDIT: purge deleted grenade threat refs immediately
		brain.grenade.active_grenade_found = null
	invalidate_nearby_item_search()
	brain.invalidate_halo_runtime_caches() //halo code is not in our work zone
	equipped_items_original_loc -= source // SS220 EDIT: deleted held items must not keep stale original-slot tracking

	for(var/name in container_refs)
		if(source == container_refs[name])
			container_refs[name] = null
			return

	for(var/id in equipment_map)
		for(var/obj/item/item_ref as anything in equipment_map[id])
			if(source == item_ref)
				equipment_map[id] -= item_ref
				return

/datum/human_ai_module/inventory/proc/on_item_equip(datum/source, obj/item/equipment, slot)
	SIGNAL_HANDLER
	to_pickup -= equipment
	invalidate_nearby_item_search()
	brain.invalidate_halo_runtime_caches() //halo code is not in our work zone

	if((slot in important_storage_slots) && istype(equipment, /obj/item/storage))
		recalculate_containers()
		appraise_inventory(slot == WEAR_WAIST, slot == WEAR_BACK, slot == WEAR_L_STORE, slot == WEAR_R_STORE, slot == WEAR_JACKET, slot == WEAR_BODY)

	if(!primary_weapon && isgun(equipment) && (slot == WEAR_J_STORE))
		set_primary_weapon(equipment)

	if(istype(equipment, /obj/item/clothing/glasses/night) && (slot == WEAR_EYES))
		has_nightvision = TRUE

/datum/human_ai_module/inventory/proc/on_item_unequip(datum/source, obj/item/equipment, slot)
	SIGNAL_HANDLER
	invalidate_nearby_item_search()
	brain.invalidate_halo_runtime_caches() //halo code is not in our work zone

	if((important_storage_slots_bitflag & slot) && istype(equipment, /obj/item/storage))
		recalculate_containers()
		appraise_inventory(slot == SLOT_WAIST, slot == SLOT_BACK, slot == SLOT_STORE, slot == SLOT_STORE, slot == SLOT_OCLOTHING, slot == SLOT_ICLOTHING)

	if(isgun(equipment))
		appraise_inventory(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)

	if(istype(equipment, /obj/item/clothing/glasses/night) && (slot == WEAR_EYES))
		has_nightvision = FALSE

/// Reappraises what storage items the AI has
/datum/human_ai_module/inventory/proc/recalculate_containers()
	container_refs = list()
	if(isstorage(brain.tied_human.belt))
		container_refs["belt"] = brain.tied_human.belt
	if(isstorage(brain.tied_human.back))
		container_refs["backpack"] = brain.tied_human.back
	if(isstorage(brain.tied_human.l_store))
		container_refs["left_pocket"] = brain.tied_human.l_store
	if(isstorage(brain.tied_human.r_store))
		container_refs["right_pocket"] = brain.tied_human.r_store
	if(istype(brain.tied_human.wear_suit, /obj/item/clothing/suit/storage))
		var/obj/item/clothing/suit/storage/storage_suit = brain.tied_human.wear_suit
		container_refs["armor"] = storage_suit.pockets
	if(isclothing(brain.tied_human.w_uniform))
		var/obj/item/clothing/accessory/storage/storage_accessory = locate(/obj/item/clothing/accessory/storage) in brain.tied_human.w_uniform.accessories
		if(storage_accessory)
			container_refs["uniform"] = storage_accessory.hold

/// Currently doesn't support recursive storage
/// Used to determine what the AI has in their inventory
/datum/human_ai_module/inventory/proc/appraise_inventory(belt = TRUE, back = TRUE, pocket_l = TRUE, pocket_r = TRUE, armor = TRUE, uniform = TRUE)
	if(brain.faction.previous_faction != brain.tied_human.faction)
		brain.faction.previous_faction = brain.tied_human.faction
		var/datum/human_ai_faction/our_faction = SShuman_ai.human_ai_factions[brain.tied_human.faction]
		our_faction?.apply_faction_data(brain)

	/*if(tied_human.shoes && !primary_melee) // snowflake bootknife check
		var/obj/item/weapon/knife = locate() in tied_human.shoes
		if(knife)
			set_primary_melee(knife)*/

	// snowflake secondary weapon in suit storage check
	if(isgun(brain.tied_human.s_store) && (brain.tied_human.s_store != primary_weapon))
		add_secondary_weapon(brain.tied_human.s_store)

	brain.guns.tried_reload = FALSE // We don't really need to do this in a smart way
	if(belt)
		appraise_belt()

	if(back)
		appraise_back()

	if(pocket_l)
		appraise_left_pocket()

	if(pocket_r)
		appraise_right_pocket()

	if(armor)
		appraise_armor()

	if(uniform && isclothing(brain.tied_human.w_uniform))
		appraise_uniform()

/datum/human_ai_module/inventory/proc/appraise_belt()
	if(isgun(brain.tied_human.belt) && (brain.tied_human.belt != primary_weapon))
		add_secondary_weapon(brain.tied_human.belt)
		return

	if(!istype(brain.tied_human.belt, /obj/item/storage)) // belts can be backpacks, don't ask
		return

	for(var/id in equipment_map)
		for(var/obj/item/item as anything in equipment_map[id])
			if(equipment_map[id][item] != "belt")
				continue

			equipment_map[id] -= item

	RegisterSignal(brain.tied_human.belt, COMSIG_PARENT_QDELETING, PROC_REF(on_item_delete), TRUE)
	item_slot_appraisal_loop(brain.tied_human.belt, "belt")

/datum/human_ai_module/inventory/proc/appraise_back()
	if(isgun(brain.tied_human.back) && (brain.tied_human.back != primary_weapon))
		add_secondary_weapon(brain.tied_human.back)
		return

	// SS220 EDIT - START: HALO transport rigs such as the SPNKr pack sit on the back slot as storage,
	// but they are not guaranteed to inherit backpack. AI still needs to appraise their contents.
	if(!istype(brain.tied_human.back, /obj/item/storage))
		return
	// SS220 EDIT - END

	for(var/id in equipment_map)
		for(var/obj/item/item as anything in equipment_map[id])
			if(equipment_map[id][item] != "backpack")
				continue

			equipment_map[id] -= item

	RegisterSignal(brain.tied_human.back, COMSIG_PARENT_QDELETING, PROC_REF(on_item_delete), TRUE)
	item_slot_appraisal_loop(brain.tied_human.back, "backpack")

/datum/human_ai_module/inventory/proc/appraise_left_pocket()
	if(!istype(brain.tied_human.l_store, /obj/item/storage/pouch))
		return

	for(var/id in equipment_map)
		for(var/obj/item/item as anything in equipment_map[id])
			if(equipment_map[id][item] != "left_pocket")
				continue

			equipment_map[id] -= item

	RegisterSignal(brain.tied_human.l_store, COMSIG_PARENT_QDELETING, PROC_REF(on_item_delete), TRUE)
	item_slot_appraisal_loop(brain.tied_human.l_store, "left_pocket")

/datum/human_ai_module/inventory/proc/appraise_right_pocket()
	if(!istype(brain.tied_human.r_store, /obj/item/storage/pouch))
		return

	for(var/id in equipment_map)
		for(var/obj/item/item as anything in equipment_map[id])
			if(equipment_map[id][item] != "right_pocket")
				continue

			equipment_map[id] -= item

	RegisterSignal(brain.tied_human.r_store, COMSIG_PARENT_QDELETING, PROC_REF(on_item_delete), TRUE)
	item_slot_appraisal_loop(brain.tied_human.r_store, "right_pocket")

/datum/human_ai_module/inventory/proc/appraise_armor()
	if(!istype(brain.tied_human.wear_suit, /obj/item/clothing/suit))
		return

	if(istype(brain.tied_human.wear_suit, /obj/item/clothing/suit) && brain.tied_human.loc) // being in nullspace makes lights play weirdly
		var/obj/item/clothing/suit/worn_armor = brain.tied_human.wear_suit
		if(!worn_armor.has_light)
			return
		else if(!worn_armor.light_on)
			worn_armor.turn_light(brain.tied_human, TRUE)

	var/obj/item/clothing/suit/storage/storage_suit = brain.tied_human.wear_suit
	for(var/id in equipment_map)
		for(var/obj/item/item as anything in equipment_map[id])
			if(equipment_map[id][item] != "armor")
				continue

			equipment_map[id] -= item

	RegisterSignal(storage_suit, COMSIG_PARENT_QDELETING, PROC_REF(on_item_delete), TRUE)
	for(var/obj/item/clothing/accessory/storage/armour_webbing in storage_suit.accessories)
		item_slot_appraisal_loop(armour_webbing, "armor")
		return
	if(storage_suit.get_pockets())
		item_slot_appraisal_loop(storage_suit.pockets, "armor")

/datum/human_ai_module/inventory/proc/appraise_uniform()
	var/obj/item/clothing/accessory/storage/located_storage = locate(/obj/item/clothing/accessory/storage) in brain.tied_human.w_uniform.accessories
	if(!located_storage)
		return

	for(var/id in equipment_map)
		for(var/obj/item/item as anything in equipment_map[id])
			if(equipment_map[id][item] != "uniform")
				continue

			equipment_map[id] -= item

	RegisterSignal(located_storage, COMSIG_PARENT_QDELETING, PROC_REF(on_item_delete), TRUE)
	item_slot_appraisal_loop(located_storage.hold, "uniform")

/datum/human_ai_module/inventory/proc/item_slot_appraisal_loop(obj/item/container_to_loop, slot_to_assign)
	for(var/obj/item/inv_item as anything in container_to_loop)
		RegisterSignal(inv_item, COMSIG_PARENT_QDELETING, PROC_REF(on_item_delete), TRUE)
		if(inv_item.flags_human_ai & HEALING_ITEM)
			equipment_map[HUMAN_AI_HEALTHITEMS][inv_item] = slot_to_assign
		else if(inv_item.flags_human_ai & AMMUNITION_ITEM)
			equipment_map[HUMAN_AI_AMMUNITION][inv_item] = slot_to_assign
		else if(inv_item.flags_human_ai & GRENADE_ITEM)
			equipment_map[HUMAN_AI_GRENADES][inv_item] = slot_to_assign
		else if(inv_item.flags_human_ai & TOOL_ITEM)
			equipment_map[HUMAN_AI_TOOLS][inv_item] = slot_to_assign
		else if(isgun(inv_item) && !(inv_item in secondary_weapons))
			add_secondary_weapon(inv_item)

		//else if((inv_item.flags_human_ai & MELEE_WEAPON_ITEM) && !primary_melee)
		//	set_primary_melee(inv_item)

/datum/human_ai_module/inventory/proc/clear_main_hand()
	var/obj/item/active_hand = brain.tied_human.get_active_hand()
	if(!active_hand)
		return

	if(primary_weapon == active_hand)
		if(!holster_primary())
			brain.tied_human.drop_held_item(active_hand)
		return

	var/storage_id = storage_has_room(active_hand)
	if(!storage_id)
		brain.tied_human.drop_held_item(active_hand)
		return

	store_item(active_hand, storage_id)

/datum/human_ai_module/inventory/proc/storage_has_room(obj/item/inserting)
	for(var/container_id in container_refs)
		var/obj/item/storage/container = container_refs[container_id]
		if(container?.can_be_inserted(inserting, brain.tied_human, TRUE))
			return container_id

/datum/human_ai_module/inventory/proc/on_item_pickup(datum/source, obj/item/picked_up)
	SIGNAL_HANDLER

	brain.invalidate_halo_runtime_caches()

	if(!primary_weapon && isgun(picked_up))
		set_primary_weapon(picked_up)

	to_pickup -= picked_up
	if(picked_up == brain.grenade.active_grenade_found) // SS220 EDIT: once someone holds the grenade, stop floor-threat gating — unless throw-back is active
		if(!brain.action_runtime.has_ongoing_action(/datum/ai_action/throw_back_nade))
			addtimer(CALLBACK(src, PROC_REF(clear_active_grenade_if_stale), picked_up), 1 SECONDS) // SS220 EDIT: delay reset so throw-back action has time to spawn on next scheduler tick
	invalidate_nearby_item_search()

/// SS220 EDIT: delayed reset of active_grenade_found — gives throw-back action one scheduler tick to spawn before clearing
/datum/human_ai_module/inventory/proc/clear_active_grenade_if_stale(obj/item/explosive/grenade/grenade)
	if(brain.grenade.active_grenade_found == grenade && !brain.action_runtime.has_ongoing_action(/datum/ai_action/throw_back_nade))
		brain.grenade.active_grenade_found = null

/datum/human_ai_module/inventory/proc/on_item_drop(datum/source, obj/item/dropped)
	SIGNAL_HANDLER
	invalidate_nearby_item_search()
	brain.invalidate_halo_runtime_caches()
	if(iszombie(brain.tied_human))
		return

	if(dropped == primary_weapon)
		var/datum/firearm_appraisal/current_gun_data = gun_data
		if(!(current_gun_data?.disposable && !primary_weapon.ai_can_use(brain.tied_human, brain)))
			to_pickup |= dropped
		set_primary_weapon(null)

	for(var/slot in container_refs)
		if(container_refs[slot] == dropped)
			appraise_inventory(slot == "belt", slot == "backpack", slot == "left_pocket", slot == "right_pocket", slot == "armor", slot == "uniform")
			break

	for(var/id in equipment_map)
		for(var/obj/item/item_ref as anything in equipment_map[id])
			if(item_ref == dropped)
				equipment_map[id] -= item_ref
				return

/datum/human_ai_module/inventory/proc/set_primary_weapon(obj/item/weapon/gun/new_gun)
	if(primary_weapon)
		UnregisterSignal(primary_weapon, COMSIG_PARENT_QDELETING)
	primary_weapon = new_gun
	appraise_primary()
	invalidate_nearby_item_search()
	brain.invalidate_halo_runtime_caches()
	if(primary_weapon)
		RegisterSignal(primary_weapon, COMSIG_PARENT_QDELETING, PROC_REF(on_primary_delete), TRUE)

/datum/human_ai_module/inventory/proc/on_primary_delete(datum/source, force)
	SIGNAL_HANDLER

	set_primary_weapon(null)
	to_pickup -= source
	invalidate_nearby_item_search()
	brain.invalidate_halo_runtime_caches()

/*datum/human_ai_brain/proc/set_primary_melee(obj/item/weapon/new_melee)
	if(primary_melee)
		UnregisterSignal(primary_melee, COMSIG_PARENT_QDELETING)
	primary_melee = new_melee
	appraise_primary()
	if(primary_melee)
		RegisterSignal(primary_melee, COMSIG_PARENT_QDELETING, PROC_REF(on_primary_melee_delete))

/datum/human_ai_brain/proc/on_primary_melee_delete(datum/source, force)
	SIGNAL_HANDLER

	set_primary_melee(null)*/

/datum/human_ai_module/inventory/proc/appraise_primary()
	gun_data = null
	if(!primary_weapon)
		return
	var/static/datum/firearm_appraisal/default = new()
	for(var/datum/firearm_appraisal/appraisal as anything in GLOB.firearm_appraisals)
		if(is_type_in_list(primary_weapon, appraisal.gun_types))
			gun_data = appraisal
			break

	if(!gun_data)
		gun_data = default

/datum/human_ai_module/inventory/proc/item_search(list/things_around)
	// SS220 EDIT - START: grenade threat must come only from the current local scan, not from stale refs.
	// Preserve active_grenade_found across ticks if it is already the currently held, still-active timed grenade.
	if(!brain.grenade.active_grenade_found || QDELETED(brain.grenade.active_grenade_found) || !brain.grenade.active_grenade_found.active || (brain.grenade.active_grenade_found.fuse_type != TIMED_FUSE) || (brain.grenade.active_grenade_found.loc != brain.tied_human))
		brain.grenade.active_grenade_found = null
	var/can_handle_live_grenade = brain.grenade.can_throw_back_grenades && !((brain.tied_human.l_hand?.flags_item & NODROP) && (brain.tied_human.r_hand?.flags_item & NODROP))
	// SS220 EDIT - END
	search_loop:
		for(var/obj/item/thing in things_around)
			if(!isturf(thing.loc))
				continue

			if(thing in to_pickup)
				continue

			if(thing.flags_human_ai & GRENADE_ITEM)
				var/obj/item/explosive/grenade/nade = thing
				if(nade.active && (nade.fuse_type == IMPACT_FUSE))
					return
				else if(nade.active && (nade.fuse_type == TIMED_FUSE) && can_handle_live_grenade) // SS220 EDIT: only enter throw-back mode if we can actually manipulate the grenade
					brain.grenade.active_grenade_found = thing
					continue

			// SS220 EDIT - START: ignore_looting must also suppress pickup candidates, not only the Item Pickup action.
			if(ignore_looting)
				continue
			// SS220 EDIT - END

			if(!primary_weapon && isgun(thing))
				var/obj/item/weapon/gun/thing_gun = thing
				for(var/item in to_pickup)
					if(isgun(item)) // One weapon at a time
						continue search_loop

				for(var/datum/firearm_appraisal/appraisal as anything in GLOB.firearm_appraisals)
					if(is_type_in_list(thing_gun, appraisal.gun_types))
						if(appraisal.disposable && thing_gun.current_mag?.current_rounds <= 0)
							continue search_loop
						break

				add_to_pickup(thing)

			if(istype(thing, /obj/item/storage/belt) && !container_refs["belt"])
				add_to_pickup(thing)

			if(istype(thing, /obj/item/storage/backpack) && !container_refs["backpack"])
				add_to_pickup(thing)

			if(istype(thing, /obj/item/storage/pouch) && (!container_refs["left_pocket"] || !container_refs["right_pocket"]))
				add_to_pickup(thing)

			var/storage_spot = storage_has_room(thing)
			if(!storage_spot || !thing.ai_can_use(brain.tied_human, brain, brain.tied_human))
				continue

			if(thing.flags_human_ai & HEALING_ITEM)
				add_to_pickup(thing)

			if((thing.flags_human_ai & AMMUNITION_ITEM) && primary_weapon)
				var/obj/item/ammo_magazine/mag = thing
				if(istype(primary_weapon, mag.gun_type))
					add_to_pickup(thing)

			if(thing.flags_human_ai & GRENADE_ITEM)
				add_to_pickup(thing)

			if(thing.flags_human_ai & TOOL_ITEM)
				add_to_pickup(thing)

/datum/human_ai_module/inventory/proc/add_to_pickup(obj/item/thing)
	RegisterSignal(thing, COMSIG_PARENT_QDELETING, PROC_REF(on_item_delete), TRUE)
	to_pickup += thing

/datum/human_ai_module/inventory/proc/get_tool_from_equipment_map(tool_trait)
	RETURN_TYPE(/obj/item)
	for(var/obj/item/maybe_tool as anything in equipment_map[HUMAN_AI_TOOLS])
		if(!HAS_TRAIT(maybe_tool, tool_trait))
			continue
		return maybe_tool

/datum/human_ai_module/inventory/proc/add_secondary_weapon(obj/item/weapon/gun/secondary)
	if(!secondary || (secondary in secondary_weapons))
		return

	secondary_weapons += secondary
	RegisterSignal(secondary, COMSIG_PARENT_QDELETING, PROC_REF(on_secondary_delete), TRUE)

/datum/human_ai_module/inventory/proc/remove_secondary_weapon(obj/item/weapon/gun/secondary)
	UnregisterSignal(secondary, COMSIG_PARENT_QDELETING)
	secondary_weapons -= secondary


/datum/human_ai_module/inventory/proc/on_secondary_delete(datum/source, force)
	SIGNAL_HANDLER
	remove_secondary_weapon(source)

/datum/human_ai_module/inventory/proc/weapon_ammo_search(obj/item/weapon/gun/weapon)
	for(var/obj/item/ammo_magazine/mag as anything in equipment_map[HUMAN_AI_AMMUNITION])
		if(istype(weapon, mag.gun_type) && mag.ai_can_use(brain.tied_human, brain))
			return mag

/datum/human_ai_module/inventory/proc/invalidate_nearby_item_search()
	nearby_item_search_dirty = TRUE


/// Unholsters the AI's primary weapon, dropping anything that might obstruct it.
/datum/human_ai_module/inventory/proc/unholster_primary()
	if(!primary_weapon || brain.tied_human.l_hand == primary_weapon || brain.tied_human.r_hand == primary_weapon)
		return

	var/cur_hand = brain.tied_human.get_active_hand()
	if(cur_hand)
		brain.tied_human.drop_held_item(cur_hand)

	brain.tied_human.u_equip(primary_weapon)
	brain.tied_human.put_in_active_hand(primary_weapon)

	primary_weapon.guaranteed_delay_time = world.time
	primary_weapon.wield_time = world.time
	primary_weapon.pull_time = world.time

/// Tells the AI to wield their primary weapon, can be called if they aren't holding it or if they are already wielding it
/datum/human_ai_module/inventory/proc/wield_primary()
	primary_weapon?.wield(brain.tied_human)

/// wield_primary() with a delay inbuilt
/datum/human_ai_module/inventory/proc/wield_primary_sleep()
	wield_primary()
	sleep(max(primary_weapon?.wield_delay, brain.profile.short_action_delay * brain.profile.action_delay_mult))

/// Tells the AI to unwield *something*, prioritizing melee
/datum/human_ai_module/inventory/proc/unholster_any_weapon()
	if(iszombie(brain.tied_human))
		var/cur_hand = brain.tied_human.get_active_hand()
		if(isnull(cur_hand)) //Check if we have a hand. If not try the other one? Claws are stuck to hands so if this is null we've lost the hand
			var/obj/limb/hand/r_hand/right_hand	= brain.tied_human.get_limb("r_hand")
			var/obj/limb/hand/l_hand/left_hand = brain.tied_human.get_limb("l_hand")
			if(!(left_hand.status & LIMB_DESTROYED) || !(right_hand.status & LIMB_DESTROYED)) //We have hands?
				brain.tied_human.swap_hand()
				cur_hand = brain.tied_human.get_active_hand()
			else
				return FALSE
	if(unholster_melee())
		brain.tied_human.a_intent_change(INTENT_GRAB)
		return TRUE
	if(primary_weapon)
		unholster_primary()
		ensure_primary_hand(primary_weapon)
		wield_primary()
		brain.tied_human.a_intent_change(INTENT_GRAB)
		return TRUE
	// insert any viable weapon slot macros in here

/// Quick and dirty proc to holster a melee weapon if the AI is holding one.
/datum/human_ai_module/inventory/proc/holster_melee()
	if(!drawn_melee_weapon)
		return TRUE

	if(drawn_melee_weapon.loc != brain.tied_human)
		on_melee_dropped()
		return TRUE

	if(brain.tied_human.shoes && brain.tied_human.shoes.can_be_inserted(drawn_melee_weapon))
		return brain.tied_human.shoes.attempt_insert_item(brain.tied_human, drawn_melee_weapon)

	brain.tied_human.drop_held_item(drawn_melee_weapon)
	return FALSE

/// Signal for if a melee weapon is dropped
/datum/human_ai_module/inventory/proc/on_melee_dropped()
	SIGNAL_HANDLER

	UnregisterSignal(drawn_melee_weapon, COMSIG_ITEM_DROPPED)
	drawn_melee_weapon = null


/// Melee system currently only supports bootknives.
/datum/human_ai_module/inventory/proc/unholster_melee()
	if(istype(brain.tied_human.l_hand, /obj/item) || istype(brain.tied_human.r_hand, /obj/item))
		return TRUE

	var/cur_hand = brain.tied_human.get_active_hand()
	if(cur_hand)
		brain.tied_human.drop_held_item(cur_hand)

	if(brain.tied_human.shoes)
		var/obj/item/melee_weapon = brain.tied_human.shoes.remove_item(brain.tied_human)
		drawn_melee_weapon = melee_weapon
		RegisterSignal(drawn_melee_weapon, COMSIG_ITEM_DROPPED, PROC_REF(on_melee_dropped))
		return melee_weapon


/// Holsters the AI's primary weapon if possible
/datum/human_ai_module/inventory/proc/holster_primary()
	if(brain.tied_human.s_store || (brain.tied_human.l_hand != primary_weapon && brain.tied_human.r_hand != primary_weapon))
		return FALSE

	return brain.tied_human.equip_to_slot_if_possible(primary_weapon, WEAR_J_STORE, TRUE)

/// Assuming an item is in the AI's hands, this ensures it is their actively selected hand
/datum/human_ai_module/inventory/proc/ensure_primary_hand(obj/item/held_item)
	if(brain.tied_human.get_inactive_hand() == held_item)
		brain.tied_human.swap_hand()
