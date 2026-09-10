#define HUMAN_AI_PICKUP_APPROACH_IN_RANGE 1
#define HUMAN_AI_PICKUP_APPROACH_MOVING 2
#define HUMAN_AI_PICKUP_APPROACH_FAILED 3

/datum/ai_action/item_pickup
	name = "Item Pickup"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/inventory, /datum/human_ai_module/navigation)
	var/obj/item/to_pickup

/datum/ai_action/item_pickup/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !controller || !inventory)
		return 0

	if(inventory.is_looting_disabled())
		return 0

	if(!inventory.has_pickup_queue())
		return 0

	if(controller.has_trait_from(TRAIT_UNDENSE, LYING_DOWN_TRAIT))
		return 0

	if(controller.is_health_below(HEALTH_THRESHOLD_CRIT))
		return 0

	if(controller.get_l_hand()?.flags_item & NODROP)
		return 0

	if(controller.get_r_hand()?.flags_item & NODROP)
		return 0

	if(!inventory.has_primary_weapon())
		return 16

	return 11

/datum/ai_action/item_pickup/Added()
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!inventory)
		return

	// If we already have a primary weapon, don't set to_pickup and action will be killed immideately
	if(isgun(to_pickup) && inventory.has_primary_weapon())
		return

	to_pickup = inventory.get_next_pickup()

/datum/ai_action/item_pickup/Destroy(force, ...)
	to_pickup = null
	return ..()

/datum/ai_action/item_pickup/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !controller || !inventory)
		return ONGOING_ACTION_COMPLETED

	if(is_pickup_target_invalid())
		cleanup_pickup_target()
		return ONGOING_ACTION_COMPLETED

	var/obj/item/weapon/gun/primary_weapon = inventory.get_primary_weapon()
	if(primary_weapon && isgun(to_pickup))
		cleanup_pickup_target()
		return ONGOING_ACTION_COMPLETED

	var/approach_result = approach_pickup_target()
	if(approach_result == HUMAN_AI_PICKUP_APPROACH_FAILED)
		return ONGOING_ACTION_COMPLETED
	if(approach_result == HUMAN_AI_PICKUP_APPROACH_MOVING)
		return ONGOING_ACTION_UNFINISHED

	prepare_hands_for_pickup(primary_weapon)

	if(try_pickup_primary_weapon())
		return ONGOING_ACTION_COMPLETED

	if(try_equip_pickup_storage())
		return ONGOING_ACTION_COMPLETED

	var/storage_spot = inventory.storage_has_room(to_pickup)
	if(!storage_spot || !controller.can_use_item_on_self(to_pickup))
		cleanup_pickup_target()
		return ONGOING_ACTION_COMPLETED

	try_store_pickup_item(storage_spot)

	return ONGOING_ACTION_COMPLETED

/datum/ai_action/item_pickup/proc/is_pickup_target_invalid()
	return QDELETED(to_pickup) || !isturf(to_pickup.loc)

/datum/ai_action/item_pickup/proc/cleanup_pickup_target()
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !inventory)
		return

	brain.UnregisterSignal(to_pickup, COMSIG_PARENT_QDELETING)
	inventory.unqueue_pickup(to_pickup)

/datum/ai_action/item_pickup/proc/approach_pickup_target()
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return HUMAN_AI_PICKUP_APPROACH_FAILED

	if(controller.get_distance_to(to_pickup) <= 1)
		return HUMAN_AI_PICKUP_APPROACH_IN_RANGE

	if(!brain.move_to_atom(to_pickup))
		cleanup_pickup_target()
		return HUMAN_AI_PICKUP_APPROACH_FAILED

	if(controller.get_distance_to(to_pickup) > 1)
		return HUMAN_AI_PICKUP_APPROACH_MOVING

	return HUMAN_AI_PICKUP_APPROACH_IN_RANGE

/datum/ai_action/item_pickup/proc/prepare_hands_for_pickup(obj/item/weapon/gun/primary_weapon)
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return

	if(primary_weapon)
		controller.unwield_weapon(primary_weapon)

	if(controller.get_held_item())
		controller.swap_hand()

/datum/ai_action/item_pickup/proc/try_pickup_primary_weapon()
	if(!isgun(to_pickup))
		return FALSE

	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return FALSE

	controller.put_in_hands(to_pickup, TRUE)
	var/obj/item/weapon/gun/primary = to_pickup
	// We do the three below lines to make it so that the AI can immediately pick up a gun and open fire. This ensures that we don't need to account for this possibility when firing.
	primary.wield_time = world.time
	primary.pull_time = world.time
	primary.guaranteed_delay_time = world.time
	return TRUE

/datum/ai_action/item_pickup/proc/try_equip_pickup_storage()
	if(try_equip_pickup_storage_to_slot(/obj/item/storage/belt, HUMAN_AI_STORAGE_BELT, WEAR_WAIST))
		return TRUE

	if(try_equip_pickup_storage_to_slot(/obj/item/storage/backpack, HUMAN_AI_STORAGE_BACKPACK, WEAR_BACK))
		return TRUE

	if(try_equip_pickup_storage_to_slot(/obj/item/storage/pouch, HUMAN_AI_STORAGE_LEFT_POCKET, WEAR_L_STORE))
		return TRUE

	return try_equip_pickup_storage_to_slot(/obj/item/storage/pouch, HUMAN_AI_STORAGE_RIGHT_POCKET, WEAR_R_STORE)

/datum/ai_action/item_pickup/proc/try_equip_pickup_storage_to_slot(storage_type, container_id, wear_slot)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !controller || !inventory)
		return FALSE

	if(!istype(to_pickup, storage_type) || inventory.has_container_ref(container_id))
		return FALSE

	controller.put_in_hands(to_pickup, TRUE)
	INVOKE_ASYNC(controller, TYPE_PROC_REF(/datum/human_tied_controller, equip_to_slot), to_pickup, wear_slot)
	return TRUE

/datum/ai_action/item_pickup/proc/try_store_pickup_item(storage_spot)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !controller || !inventory)
		return FALSE

	var/list/equipment_types = inventory.get_pickup_storage_equipment_types(to_pickup)
	if(!length(equipment_types))
		return FALSE

	controller.put_in_hands(to_pickup, TRUE)
	if(inventory.store_item_as_types(to_pickup, storage_spot, equipment_types) && (HUMAN_AI_AMMUNITION in equipment_types))
		brain.clear_tried_reload() // not appraising inventory there, let's say we can reload now
	return TRUE

#undef HUMAN_AI_PICKUP_APPROACH_IN_RANGE
#undef HUMAN_AI_PICKUP_APPROACH_MOVING
#undef HUMAN_AI_PICKUP_APPROACH_FAILED
