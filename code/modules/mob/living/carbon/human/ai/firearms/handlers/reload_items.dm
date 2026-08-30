// Isolated Human AI firearm item-reload handlers proposal. Not included in colonialmarines.dme yet.

/datum/human_ai_firearm_handler/flare
	gun_types = list(/obj/item/weapon/gun/flare)

/datum/human_ai_firearm_handler/flare/get_reload_equipment_types(datum/human_ai_firearm_context/context)
	return list(HUMAN_AI_AMMUNITION, HUMAN_AI_TOOLS)

/datum/human_ai_firearm_handler/flare/can_reload_with(datum/human_ai_firearm_context/context, obj/item/item)
	if(!can_use(context) || !item || !context.controller.can_use_item(item))
		return FALSE
	return istype(item, /obj/item/device/flashlight/flare)

/datum/human_ai_firearm_handler/flare/do_reload(datum/human_ai_firearm_context/context)
	if(can_use(context) && !context.reload_item)
		context.set_reload_item(find_reload_item(context))
	if(!can_use(context) || !context.reload_item)
		return FALSE
	context.prepare_primary_weapon()
	context.unwield_weapon()
	context.swap_hand()
	context.sleep_micro()
	if(!context.equip_reload_item(HUMAN_AI_TOOLS))
		return FALSE
	context.sleep_short()
	return context.insert_reload_item()

/datum/human_ai_firearm_handler/grenade_launcher
	gun_types = list(/obj/item/weapon/gun/launcher/grenade)

/datum/human_ai_firearm_handler/grenade_launcher/can_use(datum/human_ai_firearm_context/context)
	if(!context?.is_valid())
		return FALSE
	var/obj/item/weapon/gun/launcher/grenade/grenade_launcher = context.firearm
	if(grenade_launcher.has_ammunition())
		return ..()
	return !!find_reload_item(context)

/datum/human_ai_firearm_handler/grenade_launcher/get_reload_equipment_types(datum/human_ai_firearm_context/context)
	return list(HUMAN_AI_GRENADES, HUMAN_AI_AMMUNITION)

/datum/human_ai_firearm_handler/grenade_launcher/can_reload_with(datum/human_ai_firearm_context/context, obj/item/item)
	if(!context?.is_valid() || !item || !context.controller.can_use_item(item))
		return FALSE
	var/obj/item/weapon/gun/launcher/grenade/grenade_launcher = context.firearm
	return grenade_launcher.allowed_ammo_type(item)

/datum/human_ai_firearm_handler/grenade_launcher/fire(datum/human_ai_firearm_context/context)
	if(!can_use(context))
		return FALSE
	return context.fire_grenade_launcher_at_target()

/datum/human_ai_firearm_handler/grenade_launcher/keeps_fire_action_active(datum/human_ai_firearm_context/context)
	return FALSE

/datum/human_ai_firearm_handler/grenade_launcher/do_reload(datum/human_ai_firearm_context/context)
	if(can_use(context) && !context.reload_item)
		context.set_reload_item(find_reload_item(context))
	if(!can_use(context) || !context.reload_item)
		return FALSE
	var/obj/item/weapon/gun/launcher/grenade/grenade_launcher = context.firearm
	context.prepare_primary_weapon()
	context.unwield_weapon()
	if(!grenade_launcher.open_chamber)
		context.open_weapon_chamber()
	context.swap_hand()
	context.sleep_micro()
	var/reload_equipment_type = get_reload_item_equipment_type(context, context.reload_item)
	if(!reload_equipment_type || !context.equip_reload_item(reload_equipment_type))
		return FALSE
	context.sleep_short()
	return context.insert_reload_item()
