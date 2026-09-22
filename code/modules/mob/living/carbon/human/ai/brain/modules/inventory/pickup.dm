#define HUMAN_AI_PICKUP_SCAN_CONTINUE 0
#define HUMAN_AI_PICKUP_SCAN_SKIP 1
#define HUMAN_AI_PICKUP_SCAN_STOP 2

/datum/human_ai_module/inventory/proc/has_pickup_queue()
	return length(to_pickup)

/datum/human_ai_module/inventory/proc/get_next_pickup()
	RETURN_TYPE(/obj/item)
	if(!length(to_pickup))
		return null
	return to_pickup[1]

/datum/human_ai_module/inventory/proc/queue_pickup(obj/item/item)
	if(!item || is_pickup_queued(item))
		return FALSE
	RegisterSignal(item, COMSIG_PARENT_QDELETING, PROC_REF(on_item_delete), TRUE)
	to_pickup += item
	return TRUE

/datum/human_ai_module/inventory/proc/unqueue_pickup(obj/item/item)
	if(!item || !is_pickup_queued(item))
		return FALSE
	to_pickup -= item
	return TRUE

/datum/human_ai_module/inventory/proc/is_pickup_queued(obj/item/item)
	return item && (item in to_pickup)

/datum/human_ai_module/inventory/proc/clear_pickup_queue()
	to_pickup.Cut()

/datum/human_ai_module/inventory/proc/should_run_nearby_item_search()
	if(!can_continue_inventory_work())
		return FALSE

	if(should_owner_suspend_nearby_item_search())
		return FALSE

	if(nearby_item_search_interval <= 0)
		return TRUE

	if(!nearby_item_search_dirty && !COOLDOWN_FINISHED(src, nearby_item_search_cooldown))
		return FALSE

	nearby_item_search_dirty = FALSE
	COOLDOWN_START(src, nearby_item_search_cooldown, nearby_item_search_interval)
	return TRUE

/// SS220 EDIT: delayed reset of active_grenade_found - gives throw-back action one scheduler tick to spawn before clearing
/datum/human_ai_module/inventory/proc/clear_active_grenade_if_stale(obj/item/explosive/grenade/grenade)
	if(QDELETED(src) || !can_continue_inventory_work() || QDELETED(grenade))
		return
	if(get_owner_active_grenade() == grenade && !has_owner_ongoing_action(/datum/ai_action/throw_back_nade))
		clear_owner_active_grenade()

/datum/human_ai_module/inventory/proc/item_search(list/things_around)
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return

	// SS220 EDIT - START: grenade threat must come only from the current local scan, not from stale refs.
	// Preserve active_grenade_found across ticks if it is already the currently held, still-active timed grenade.
	var/obj/item/explosive/grenade/active_grenade = get_owner_active_grenade()
	if(!active_grenade || QDELETED(active_grenade) || !active_grenade.active || (active_grenade.fuse_type != TIMED_FUSE) || !controller.is_item_equipped_or_held(active_grenade))
		clear_owner_active_grenade()
	var/can_handle_live_grenade = can_owner_throw_back_grenade() && !((controller.get_l_hand()?.flags_item & NODROP) && (controller.get_r_hand()?.flags_item & NODROP))
	// SS220 EDIT - END
	for(var/obj/item/thing in things_around)
		if(!isturf(thing.loc))
			continue

		if(is_pickup_queued(thing))
			continue

		var/live_grenade_result = handle_live_grenade_candidate(thing, can_handle_live_grenade)
		if(live_grenade_result == HUMAN_AI_PICKUP_SCAN_STOP)
			return
		if(live_grenade_result == HUMAN_AI_PICKUP_SCAN_SKIP)
			continue

		// SS220 EDIT - START: ignore_looting must also suppress pickup candidates, not only the Item Pickup action.
		if(ignore_looting)
			continue
		// SS220 EDIT - END

		if(should_pickup_weapon(thing))
			queue_pickup(thing)

		if(should_pickup_storage(thing))
			queue_pickup(thing)

		var/storage_spot = storage_has_room(thing)
		var/mob/living/carbon/human/self_target = controller.get_self_target()
		if(!storage_spot || !self_target || !controller.can_use_item(thing, self_target))
			continue

		if(thing.flags_human_ai & HEALING_ITEM)
			queue_pickup(thing)

		if(should_pickup_ammo(thing))
			queue_pickup(thing)

		if(should_pickup_grenade(thing))
			queue_pickup(thing)

		if(should_pickup_tool(thing))
			queue_pickup(thing)

/datum/human_ai_module/inventory/proc/handle_live_grenade_candidate(obj/item/thing, can_handle_live_grenade)
	if(!(thing.flags_human_ai & GRENADE_ITEM))
		return HUMAN_AI_PICKUP_SCAN_CONTINUE

	var/obj/item/explosive/grenade/nade = thing
	if(!istype(nade))
		return HUMAN_AI_PICKUP_SCAN_CONTINUE
	if(nade.active && (nade.fuse_type == IMPACT_FUSE))
		return HUMAN_AI_PICKUP_SCAN_STOP
	if(nade.active && (nade.fuse_type == TIMED_FUSE) && can_handle_live_grenade) // SS220 EDIT: only enter throw-back mode if we can actually manipulate the grenade
		set_owner_active_grenade(nade)
		return HUMAN_AI_PICKUP_SCAN_SKIP
	return HUMAN_AI_PICKUP_SCAN_CONTINUE

/datum/human_ai_module/inventory/proc/should_pickup_weapon(obj/item/thing)
	if(primary_weapon || !isgun(thing))
		return FALSE

	if(has_queued_weapon_pickup())
		return FALSE

	var/obj/item/weapon/gun/thing_gun = thing
	var/datum/human_ai_firearm_profile/firearm_profile = get_available_firearm_profile(thing_gun)
	if(!firearm_profile)
		return FALSE
	if(firearm_profile?.disposable && thing_gun.current_mag?.current_rounds <= 0)
		return FALSE

	return TRUE

/datum/human_ai_module/inventory/proc/should_pickup_storage(obj/item/thing)
	if(istype(thing, /obj/item/storage/belt) && !has_container_ref(HUMAN_AI_STORAGE_BELT))
		return TRUE
	if(istype(thing, /obj/item/storage/backpack) && !has_container_ref(HUMAN_AI_STORAGE_BACKPACK))
		return TRUE
	if(istype(thing, /obj/item/storage/pouch) && (!has_container_ref(HUMAN_AI_STORAGE_LEFT_POCKET) || !has_container_ref(HUMAN_AI_STORAGE_RIGHT_POCKET)))
		return TRUE
	return FALSE

/datum/human_ai_module/inventory/proc/should_pickup_ammo(obj/item/thing)
	if(!(thing.flags_human_ai & AMMUNITION_ITEM) || !primary_weapon)
		return FALSE
	if(istype(thing, /obj/item/ammo_box/magazine))
		return FALSE
	return can_item_supply_ammo_for_weapon(thing, primary_weapon)

/datum/human_ai_module/inventory/proc/should_pickup_grenade(obj/item/thing)
	if(istype(thing, /obj/item/ammo_box/magazine/nade_box))
		return FALSE
	return (thing.flags_human_ai & GRENADE_ITEM) && can_item_supply_grenade(thing)

/datum/human_ai_module/inventory/proc/should_pickup_tool(obj/item/thing)
	return thing.flags_human_ai & TOOL_ITEM

/datum/human_ai_module/inventory/proc/get_pickup_storage_equipment_types(obj/item/thing)
	var/list/equipment_types = list()
	if(!thing)
		return equipment_types

	if(thing.flags_human_ai & HEALING_ITEM)
		equipment_types += HUMAN_AI_HEALTHITEMS

	if(should_pickup_ammo(thing))
		equipment_types += HUMAN_AI_AMMUNITION

	if(istype(thing, /obj/item/explosive/grenade))
		var/obj/item/explosive/grenade/nade = thing
		if(!nade.active)
			equipment_types += HUMAN_AI_GRENADES
	else if(!istype(thing, /obj/item/ammo_box/magazine/nade_box) && can_item_supply_grenade(thing))
		equipment_types += HUMAN_AI_GRENADES

	if(should_pickup_tool(thing))
		equipment_types += HUMAN_AI_TOOLS

	return equipment_types

/datum/human_ai_module/inventory/proc/has_queued_weapon_pickup()
	for(var/item in to_pickup)
		if(isgun(item)) // One weapon at a time
			return TRUE
	return FALSE

/datum/human_ai_module/inventory/proc/invalidate_nearby_item_search()
	nearby_item_search_dirty = TRUE

#undef HUMAN_AI_PICKUP_SCAN_CONTINUE
#undef HUMAN_AI_PICKUP_SCAN_SKIP
#undef HUMAN_AI_PICKUP_SCAN_STOP
