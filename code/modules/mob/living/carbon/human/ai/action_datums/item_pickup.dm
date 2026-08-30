/datum/ai_action/item_pickup
	name = "Item Pickup"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS
	var/obj/item/to_pickup

/datum/ai_action/item_pickup/get_weight(datum/human_ai_brain/brain)
	if(brain.inventory.is_looting_disabled())
		return 0

	if(!brain.inventory.has_pickup_queue())
		return 0

	if(brain.tied_controller.has_trait_from(TRAIT_UNDENSE, LYING_DOWN_TRAIT))
		return 0

	if(brain.tied_controller.is_health_below(HEALTH_THRESHOLD_CRIT))
		return 0

	if(brain.tied_controller.get_l_hand()?.flags_item & NODROP)
		return 0

	if(brain.tied_controller.get_r_hand()?.flags_item & NODROP)
		return 0

	if(!brain.inventory.has_primary_weapon())
		return 16

	return 11

/datum/ai_action/item_pickup/Added()
	// If we already have a primary weapon, don't set to_pickup and action will be killed immideately
	if(isgun(to_pickup) && brain.inventory.has_primary_weapon())
		return

	to_pickup = brain.inventory.get_next_pickup()

/datum/ai_action/item_pickup/Destroy(force, ...)
	to_pickup = null
	return ..()

/datum/ai_action/item_pickup/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	if(QDELETED(to_pickup) || !isturf(to_pickup.loc))
		brain.UnregisterSignal(to_pickup, COMSIG_PARENT_QDELETING)
		brain.inventory.remove_from_pickup(to_pickup)
		return ONGOING_ACTION_COMPLETED

	var/obj/item/weapon/gun/primary_weapon = brain.inventory.get_primary_weapon()
	if(primary_weapon && isgun(to_pickup))
		brain.UnregisterSignal(to_pickup, COMSIG_PARENT_QDELETING)
		brain.inventory.remove_from_pickup(to_pickup)
		return ONGOING_ACTION_COMPLETED

	if(brain.tied_controller.get_distance_to(to_pickup) > 1)
		if(!brain.navigation.move_to_next_turf(get_turf(to_pickup)))
			brain.UnregisterSignal(to_pickup, COMSIG_PARENT_QDELETING)
			brain.inventory.remove_from_pickup(to_pickup)
			return ONGOING_ACTION_COMPLETED

		if(brain.tied_controller.get_distance_to(to_pickup) > 1)
			return ONGOING_ACTION_UNFINISHED

	if(primary_weapon)
		brain.tied_controller.unwield_weapon(primary_weapon)

	if(brain.tied_controller.get_held_item())
		brain.tied_controller.swap_hand()

	if(isgun(to_pickup))
		brain.tied_controller.put_in_hands(to_pickup, TRUE)
		var/obj/item/weapon/gun/primary = to_pickup
		// We do the three below lines to make it so that the AI can immediately pick up a gun and open fire. This ensures that we don't need to account for this possibility when firing.
		primary.wield_time = world.time
		primary.pull_time = world.time
		primary.guaranteed_delay_time = world.time
		return ONGOING_ACTION_COMPLETED

	if(istype(to_pickup, /obj/item/storage/belt) && !brain.inventory.has_container_ref("belt"))
		brain.tied_controller.put_in_hands(to_pickup, TRUE)
		INVOKE_ASYNC(brain.tied_controller, TYPE_PROC_REF(/datum/human_tied_controller, equip_to_slot), to_pickup, WEAR_WAIST)
		return ONGOING_ACTION_COMPLETED

	if(istype(to_pickup, /obj/item/storage/backpack) && !brain.inventory.has_container_ref("backpack"))
		brain.tied_controller.put_in_hands(to_pickup, TRUE)
		INVOKE_ASYNC(brain.tied_controller, TYPE_PROC_REF(/datum/human_tied_controller, equip_to_slot), to_pickup, WEAR_BACK)
		return ONGOING_ACTION_COMPLETED

	if(istype(to_pickup, /obj/item/storage/pouch) && !brain.inventory.has_container_ref("left_pocket"))
		brain.tied_controller.put_in_hands(to_pickup, TRUE)
		INVOKE_ASYNC(brain.tied_controller, TYPE_PROC_REF(/datum/human_tied_controller, equip_to_slot), to_pickup, WEAR_L_STORE)
		return ONGOING_ACTION_COMPLETED

	if(istype(to_pickup, /obj/item/storage/pouch) && !brain.inventory.has_container_ref("right_pocket"))
		brain.tied_controller.put_in_hands(to_pickup, TRUE)
		INVOKE_ASYNC(brain.tied_controller, TYPE_PROC_REF(/datum/human_tied_controller, equip_to_slot), to_pickup, WEAR_R_STORE)
		return ONGOING_ACTION_COMPLETED

	var/storage_spot = brain.inventory.storage_has_room(to_pickup)
	if(!storage_spot || !brain.tied_controller.can_use_item_on_self(to_pickup))
		brain.UnregisterSignal(to_pickup, COMSIG_PARENT_QDELETING)
		brain.inventory.remove_from_pickup(to_pickup)
		return ONGOING_ACTION_COMPLETED

	if(to_pickup.flags_human_ai & HEALING_ITEM)
		brain.tied_controller.put_in_hands(to_pickup, TRUE)
		brain.inventory.store_item(to_pickup, storage_spot, HUMAN_AI_HEALTHITEMS)
		return ONGOING_ACTION_COMPLETED

	if(primary_weapon && istype(to_pickup, /obj/item/ammo_magazine))
		var/obj/item/ammo_magazine/mag = to_pickup
		if(istype(primary_weapon, mag.gun_type))
			brain.tied_controller.put_in_hands(to_pickup, TRUE)
			brain.inventory.store_item(to_pickup, storage_spot, HUMAN_AI_AMMUNITION)
			brain.guns.clear_tried_reload() // not appraising inventory there, let's say we can reload now
		return ONGOING_ACTION_COMPLETED

	if(istype(to_pickup, /obj/item/explosive/grenade))
		var/obj/item/explosive/grenade/nade = to_pickup
		if(!nade.active)
			brain.tied_controller.put_in_hands(to_pickup, TRUE)
			brain.inventory.store_item(to_pickup, storage_spot, HUMAN_AI_GRENADES)
		return ONGOING_ACTION_COMPLETED

	if(to_pickup.flags_human_ai & TOOL_ITEM)
		brain.tied_controller.put_in_hands(to_pickup, TRUE)
		brain.inventory.store_item(to_pickup, storage_spot, HUMAN_AI_TOOLS)
		return ONGOING_ACTION_COMPLETED

	return ONGOING_ACTION_COMPLETED
