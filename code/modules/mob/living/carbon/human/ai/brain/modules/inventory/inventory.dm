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
	/// Firearm profile datum
	var/datum/human_ai_firearm_profile/gun_data
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
		HUMAN_AI_STORAGE_BELT = null,
		HUMAN_AI_STORAGE_BACKPACK = null,
		HUMAN_AI_STORAGE_LEFT_POCKET = null,
		HUMAN_AI_STORAGE_RIGHT_POCKET = null,
		HUMAN_AI_STORAGE_ARMOR = null,
		HUMAN_AI_STORAGE_UNIFORM = null,
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

/datum/human_ai_module/inventory/proc/reset_inventory()
	drawn_melee_weapon = null
	primary_weapon = null
	gun_data = null
	clear_pickup_queue()
	invalidate_nearby_item_search()

/datum/human_ai_module/inventory/proc/get_primary_weapon()
	RETURN_TYPE(/obj/item/weapon/gun)
	return primary_weapon

/datum/human_ai_module/inventory/proc/has_primary_weapon()
	return !!primary_weapon

/datum/human_ai_module/inventory/proc/get_gun_data()
	RETURN_TYPE(/datum/human_ai_firearm_profile)
	return gun_data

/datum/human_ai_module/inventory/proc/get_gun_handler()
	RETURN_TYPE(/datum/human_ai_firearm_handler)
	return GLOB.human_ai_firearm_registry?.get_handler(primary_weapon)

/datum/human_ai_module/inventory/proc/has_gun_data()
	return !!gun_data

/datum/human_ai_module/inventory/proc/get_available_firearm_profile(obj/item/weapon/gun/weapon)
	RETURN_TYPE(/datum/human_ai_firearm_profile)

	var/datum/human_ai_firearm_profile/firearm_profile = GLOB.human_ai_firearm_registry?.get_profile(weapon)
	if(!firearm_profile?.available_to_ai)
		return null
	return firearm_profile

/datum/human_ai_module/inventory/proc/can_select_firearm(obj/item/weapon/gun/weapon)
	return !!get_available_firearm_profile(weapon)

/datum/human_ai_module/inventory/proc/has_secondary_weapons()
	return get_secondary_weapon_count()

/datum/human_ai_module/inventory/proc/get_secondary_weapon_count()
	return length(secondary_weapons)

/datum/human_ai_module/inventory/proc/has_secondary_weapon(obj/item/weapon/gun/weapon)
	return weapon && (weapon in secondary_weapons)

/datum/human_ai_module/inventory/proc/is_looting_disabled()
	return ignore_looting

/datum/human_ai_module/inventory/proc/set_looting_disabled(disabled)
	ignore_looting = disabled

/datum/human_ai_module/inventory/proc/has_equipment(equipment_type)
	return get_equipment_count(equipment_type)

/datum/human_ai_module/inventory/proc/clear_main_hand()
	var/obj/item/active_hand = brain.tied_controller.get_active_hand()
	if(!active_hand)
		return

	if(primary_weapon == active_hand)
		if(!holster_primary())
			brain.tied_controller.drop_held_item(active_hand)
		return

	var/storage_id = storage_has_room(active_hand)
	if(!storage_id)
		brain.tied_controller.drop_held_item(active_hand)
		return

	store_item(active_hand, storage_id)
