/// Currently doesn't support recursive storage
/// Used to determine what the AI has in their inventory
/datum/human_ai_module/inventory/proc/appraise_inventory(belt = TRUE, back = TRUE, pocket_l = TRUE, pocket_r = TRUE, armor = TRUE, uniform = TRUE)
	recalculate_containers()

	if(brain.get_previous_faction() != brain.tied_controller.get_faction())
		brain.set_previous_faction(brain.tied_controller.get_faction())
		var/datum/human_ai_faction/our_faction = SShuman_ai.human_ai_factions[brain.tied_controller.get_faction()]
		our_faction?.apply_faction_data(brain)

	/*if(puppet.shoes && !primary_melee) // snowflake bootknife check
		var/obj/item/weapon/knife = locate() in puppet.shoes
		if(knife)
			set_primary_melee(knife)*/

	// snowflake secondary weapon in suit storage check
	if(isgun(brain.tied_controller.get_s_store()) && (brain.tied_controller.get_s_store() != primary_weapon))
		add_secondary_weapon(brain.tied_controller.get_s_store())

	brain.clear_tried_reload() // We don't really need to do this in a smart way
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

	if(uniform && isclothing(brain.tied_controller.get_w_uniform()))
		appraise_uniform()

/datum/human_ai_module/inventory/proc/appraise_belt()
	if(isgun(brain.tied_controller.get_belt()) && (brain.tied_controller.get_belt() != primary_weapon))
		add_secondary_weapon(brain.tied_controller.get_belt())
		return

	if(!istype(brain.tied_controller.get_belt(), /obj/item/storage)) // belts can be backpacks, don't ask
		return

	appraise_storage_contents(brain.tied_controller.get_belt(), brain.tied_controller.get_belt(), HUMAN_AI_STORAGE_BELT)

/datum/human_ai_module/inventory/proc/appraise_back()
	if(isgun(brain.tied_controller.get_back()) && (brain.tied_controller.get_back() != primary_weapon))
		add_secondary_weapon(brain.tied_controller.get_back())
		return

	// SS220 EDIT - START: HALO transport rigs such as the SPNKr pack sit on the back slot as storage,
	// but they are not guaranteed to inherit backpack. AI still needs to appraise their contents.
	if(!istype(brain.tied_controller.get_back(), /obj/item/storage))
		return
	// SS220 EDIT - END

	appraise_storage_contents(brain.tied_controller.get_back(), brain.tied_controller.get_back(), HUMAN_AI_STORAGE_BACKPACK)

/datum/human_ai_module/inventory/proc/appraise_left_pocket()
	if(!istype(brain.tied_controller.get_l_store(), /obj/item/storage/pouch))
		return

	appraise_storage_contents(brain.tied_controller.get_l_store(), brain.tied_controller.get_l_store(), HUMAN_AI_STORAGE_LEFT_POCKET)

/datum/human_ai_module/inventory/proc/appraise_right_pocket()
	if(!istype(brain.tied_controller.get_r_store(), /obj/item/storage/pouch))
		return

	appraise_storage_contents(brain.tied_controller.get_r_store(), brain.tied_controller.get_r_store(), HUMAN_AI_STORAGE_RIGHT_POCKET)

/datum/human_ai_module/inventory/proc/appraise_armor()
	if(!istype(brain.tied_controller.get_wear_suit(), /obj/item/clothing/suit))
		return

	if(istype(brain.tied_controller.get_wear_suit(), /obj/item/clothing/suit) && brain.tied_controller.get_loc()) // being in nullspace makes lights play weirdly
		var/obj/item/clothing/suit/worn_armor = brain.tied_controller.get_wear_suit()
		if(!worn_armor.has_light)
			return
		else if(!worn_armor.light_on)
			brain.tied_controller.turn_suit_light(worn_armor, TRUE)

	var/obj/item/clothing/suit/storage/storage_suit = brain.tied_controller.get_wear_suit()
	clear_equipment_refs_for_slot(HUMAN_AI_STORAGE_ARMOR)
	RegisterSignal(storage_suit, COMSIG_PARENT_QDELETING, PROC_REF(on_item_delete), TRUE)
	for(var/obj/item/clothing/accessory/storage/armour_webbing in storage_suit.accessories)
		item_slot_appraisal_loop(armour_webbing, HUMAN_AI_STORAGE_ARMOR)
		return
	if(storage_suit.get_pockets())
		item_slot_appraisal_loop(storage_suit.pockets, HUMAN_AI_STORAGE_ARMOR)

/datum/human_ai_module/inventory/proc/appraise_uniform()
	var/obj/item/clothing/accessory/storage/located_storage = locate(/obj/item/clothing/accessory/storage) in brain.tied_controller.get_w_uniform().accessories
	if(!located_storage)
		return

	appraise_storage_contents(located_storage, located_storage.hold, HUMAN_AI_STORAGE_UNIFORM)

/datum/human_ai_module/inventory/proc/appraise_storage_contents(obj/item/signal_source, obj/item/container_to_loop, slot_to_assign)
	clear_equipment_refs_for_slot(slot_to_assign)
	RegisterSignal(signal_source, COMSIG_PARENT_QDELETING, PROC_REF(on_item_delete), TRUE)
	item_slot_appraisal_loop(container_to_loop, slot_to_assign)

/datum/human_ai_module/inventory/proc/item_slot_appraisal_loop(obj/item/container_to_loop, slot_to_assign)
	for(var/obj/item/inv_item as anything in container_to_loop)
		RegisterSignal(inv_item, COMSIG_PARENT_QDELETING, PROC_REF(on_item_delete), TRUE)
		if(!add_item_to_equipment_maps(inv_item, slot_to_assign) && isgun(inv_item) && !has_secondary_weapon(inv_item))
			add_secondary_weapon(inv_item)

		//else if((inv_item.flags_human_ai & MELEE_WEAPON_ITEM) && !primary_melee)
		//	set_primary_melee(inv_item)

/datum/human_ai_module/inventory/proc/add_item_to_equipment_maps(obj/item/inv_item, slot_to_assign)
	return set_equipment_locations_by_flags(inv_item, slot_to_assign)

/datum/human_ai_module/inventory/proc/appraise_primary()
	gun_data = null
	if(!primary_weapon)
		return
	gun_data = get_available_firearm_profile(primary_weapon)
