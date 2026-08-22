/datum/ai_action/item_pickup
	name = "Item Pickup"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS
	var/obj/item/to_pickup

/datum/ai_action/item_pickup/get_weight(datum/human_ai_brain/brain)
	if(brain.inventory.ignore_looting)
		return 0

	if(!length(brain.inventory.to_pickup))
		return 0

	if(HAS_TRAIT_FROM(brain.tied_human, TRAIT_UNDENSE, LYING_DOWN_TRAIT))
		return 0

	if(brain.tied_human.health < HEALTH_THRESHOLD_CRIT)
		return 0

	if(brain.tied_human.l_hand?.flags_item & NODROP)
		return 0

	if(brain.tied_human.r_hand?.flags_item & NODROP)
		return 0

	if(!brain.inventory.primary_weapon)
		return 16

	return 11

/datum/ai_action/item_pickup/Added()
	// If we already have a primary weapon, don't set to_pickup and action will be killed immideately
	if(isgun(to_pickup) && brain.inventory.primary_weapon)
		return

	to_pickup = brain.inventory.to_pickup[1]

/datum/ai_action/item_pickup/Destroy(force, ...)
	to_pickup = null
	return ..()

/datum/ai_action/item_pickup/trigger_action()
	. = ..()

	if(QDELETED(to_pickup) || !isturf(to_pickup.loc))
		brain.UnregisterSignal(to_pickup, COMSIG_PARENT_QDELETING)
		brain.inventory.to_pickup -= to_pickup
		return ONGOING_ACTION_COMPLETED

	if(brain.inventory.primary_weapon && isgun(to_pickup))
		brain.UnregisterSignal(to_pickup, COMSIG_PARENT_QDELETING)
		brain.inventory.to_pickup -= to_pickup
		return ONGOING_ACTION_COMPLETED

	var/mob/living/carbon/human/tied_human = brain.tied_human
	if(get_dist(to_pickup, tied_human) > 1)
		if(!brain.move_to_next_turf(get_turf(to_pickup)))
			brain.UnregisterSignal(to_pickup, COMSIG_PARENT_QDELETING)
			brain.inventory.to_pickup -= to_pickup
			return ONGOING_ACTION_COMPLETED

		if(get_dist(to_pickup, tied_human) > 1)
			return ONGOING_ACTION_UNFINISHED

	if(brain.inventory.primary_weapon)
		brain.inventory.primary_weapon.unwield(tied_human)

	if(tied_human.get_held_item())
		tied_human.swap_hand()

	if(isgun(to_pickup))
		tied_human.put_in_hands(to_pickup, TRUE)
		var/obj/item/weapon/gun/primary = to_pickup
		// We do the three below lines to make it so that the AI can immediately pick up a gun and open fire. This ensures that we don't need to account for this possibility when firing.
		primary.wield_time = world.time
		primary.pull_time = world.time
		primary.guaranteed_delay_time = world.time
		return ONGOING_ACTION_COMPLETED

	if(istype(to_pickup, /obj/item/storage/belt) && !brain.inventory.container_refs["belt"])
		tied_human.put_in_hands(to_pickup, TRUE)
		INVOKE_ASYNC(tied_human, TYPE_PROC_REF(/mob, equip_to_slot), to_pickup, WEAR_WAIST)
		return ONGOING_ACTION_COMPLETED

	if(istype(to_pickup, /obj/item/storage/backpack) && !brain.inventory.container_refs["backpack"])
		tied_human.put_in_hands(to_pickup, TRUE)
		INVOKE_ASYNC(tied_human, TYPE_PROC_REF(/mob, equip_to_slot), to_pickup, WEAR_BACK)
		return ONGOING_ACTION_COMPLETED

	if(istype(to_pickup, /obj/item/storage/pouch) && !brain.inventory.container_refs["left_pocket"])
		tied_human.put_in_hands(to_pickup, TRUE)
		INVOKE_ASYNC(tied_human, TYPE_PROC_REF(/mob, equip_to_slot), to_pickup, WEAR_L_STORE)
		return ONGOING_ACTION_COMPLETED

	if(istype(to_pickup, /obj/item/storage/pouch) && !brain.inventory.container_refs["right_pocket"])
		tied_human.put_in_hands(to_pickup, TRUE)
		INVOKE_ASYNC(tied_human, TYPE_PROC_REF(/mob, equip_to_slot), to_pickup, WEAR_R_STORE)
		return ONGOING_ACTION_COMPLETED

	var/storage_spot = brain.inventory.storage_has_room(to_pickup)
	if(!storage_spot || !to_pickup.ai_can_use(tied_human, brain, tied_human))
		brain.UnregisterSignal(to_pickup, COMSIG_PARENT_QDELETING)
		brain.inventory.to_pickup -= to_pickup
		return ONGOING_ACTION_COMPLETED

	if(to_pickup.flags_human_ai & HEALING_ITEM)
		tied_human.put_in_hands(to_pickup, TRUE)
		brain.inventory.store_item(to_pickup, storage_spot, HUMAN_AI_HEALTHITEMS)
		return ONGOING_ACTION_COMPLETED

	if(brain.inventory.primary_weapon && istype(to_pickup, /obj/item/ammo_magazine))
		var/obj/item/ammo_magazine/mag = to_pickup
		if(istype(brain.inventory.primary_weapon, mag.gun_type))
			tied_human.put_in_hands(to_pickup, TRUE)
			brain.inventory.store_item(to_pickup, storage_spot, HUMAN_AI_AMMUNITION)
			brain.guns.tried_reload = FALSE // not appraising inventory there, let's say we can reload now
		return ONGOING_ACTION_COMPLETED

	if(istype(to_pickup, /obj/item/explosive/grenade))
		var/obj/item/explosive/grenade/nade = to_pickup
		if(!nade.active)
			tied_human.put_in_hands(to_pickup, TRUE)
			brain.inventory.store_item(to_pickup, storage_spot, HUMAN_AI_GRENADES)
		return ONGOING_ACTION_COMPLETED

	if(to_pickup.flags_human_ai & TOOL_ITEM)
		tied_human.put_in_hands(to_pickup, TRUE)
		brain.inventory.store_item(to_pickup, storage_spot, HUMAN_AI_TOOLS)
		return ONGOING_ACTION_COMPLETED

	return ONGOING_ACTION_COMPLETED
