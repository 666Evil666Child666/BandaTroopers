// Isolated Human AI firearm handler proposal. Not included in colonialmarines.dme yet.

/datum/human_ai_firearm_handler
	/// Weapon families handled by this handler. More specific paths should win registry lookup.
	var/list/gun_types = list(/obj/item/weapon/gun)

/datum/human_ai_firearm_handler/proc/matches(obj/item/weapon/gun/firearm)
	return firearm && is_type_in_list(firearm, gun_types)

/datum/human_ai_firearm_handler/proc/can_select(datum/human_ai_firearm_context/context)
	return can_use(context)

/datum/human_ai_firearm_handler/proc/can_use(datum/human_ai_firearm_context/context)
	return context?.can_use()

/datum/human_ai_firearm_handler/proc/can_queue_fire(datum/human_ai_firearm_context/context)
	return can_use(context)

/datum/human_ai_firearm_handler/proc/get_primary_weight(datum/human_ai_firearm_context/context)
	var/datum/human_ai_firearm_profile/profile = context?.get_profile()
	return profile?.primary_weight || 0

/datum/human_ai_firearm_handler/proc/get_reload_equipment_types(datum/human_ai_firearm_context/context)
	return list(HUMAN_AI_AMMUNITION)

/datum/human_ai_firearm_handler/proc/can_reload_with(datum/human_ai_firearm_context/context, obj/item/item)
	if(!can_use(context) || !item || !context.controller.can_use_item(item))
		return FALSE
	var/obj/item/ammo_magazine/magazine = item
	return istype(magazine) && istype(context.firearm, magazine.gun_type)

/datum/human_ai_firearm_handler/proc/find_reload_item(datum/human_ai_firearm_context/context)
	RETURN_TYPE(/obj/item)
	if(!context?.is_valid())
		return null
	for(var/equipment_type as anything in get_reload_equipment_types(context))
		for(var/obj/item/item as anything in context.AI.inventory.get_equipment_list(equipment_type))
			if(can_reload_with(context, item))
				return item
	return null

/datum/human_ai_firearm_handler/proc/get_reload_item_equipment_type(datum/human_ai_firearm_context/context, obj/item/item)
	if(!context?.is_valid() || !item)
		return null
	for(var/equipment_type as anything in get_reload_equipment_types(context))
		if(item in context.AI.inventory.get_equipment_list(equipment_type))
			return equipment_type
	return null

/datum/human_ai_firearm_handler/proc/before_fire(datum/human_ai_firearm_context/context)
	if(!can_use(context))
		return FALSE
	context.prepare_primary_weapon()
	if((context.firearm.flags_item & TWOHANDED) && !(context.firearm.flags_item & WIELDED))
		context.wield_primary()
	context.ensure_safety_off()
	return TRUE

/datum/human_ai_firearm_handler/proc/fire(datum/human_ai_firearm_context/context)
	if(!can_use(context))
		return FALSE
	return context.fire_at_target()

/datum/human_ai_firearm_handler/proc/keeps_fire_action_active(datum/human_ai_firearm_context/context)
	return TRUE

/datum/human_ai_firearm_handler/proc/after_fire(datum/human_ai_firearm_context/context)
	RETURN_TYPE(/datum/human_ai_firearm_result)
	if(!can_use(context))
		return null
	var/datum/callback/followup_fire_callback = context.get_followup_fire_callback()
	if(!followup_fire_callback)
		return null
	var/datum/human_ai_firearm_result/result = new()
	return result.queue_callback(
		followup_fire_callback,
		context.get_followup_fire_delay(),
		context.get_followup_fire_cooldown(),
	)

/datum/human_ai_firearm_handler/proc/do_reload(datum/human_ai_firearm_context/context)
	if(can_use(context) && !context.reload_item)
		context.set_reload_item(find_reload_item(context))
	if(!can_use(context) || !context.mag)
		return FALSE
	context.prepare_primary_weapon()
	context.unwield_weapon()
	context.sleep_short()
	if(!can_use(context))
		return FALSE
	if(!(context.firearm.flags_gun_features & GUN_INTERNAL_MAG) && context.firearm.current_mag)
		context.unload_for_reload()
	context.swap_hand()
	context.sleep_micro()
	if(!can_use(context) || QDELETED(context.mag))
		return FALSE
	context.AI.inventory.equip_item_from_equipment_map(HUMAN_AI_AMMUNITION, context.mag)
	context.sleep_short()
	if(!can_use(context) || QDELETED(context.mag))
		return FALSE
	if(istype(context.mag, /obj/item/ammo_magazine/handful))
		var/obj/item/ammo_magazine/handful/handful = context.mag
		for(var/i in 1 to handful.current_rounds)
			if(!can_use(context) || QDELETED(handful))
				return FALSE
			context.insert_ammo(handful)
			context.sleep_micro()
		if(!QDELETED(handful) && (handful.current_rounds > 0))
			var/storage_slot = context.AI.inventory.storage_has_room(handful)
			if(storage_slot)
				context.AI.inventory.store_item(handful, storage_slot, HUMAN_AI_AMMUNITION)
			else
				context.controller.drop_held_item(handful)
	else
		context.insert_ammo()
	context.sleep_short()
	if(!context.is_valid())
		return FALSE
	context.swap_hand()
	context.wield_primary_sleep()
	return TRUE
