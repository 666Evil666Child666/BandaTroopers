// Isolated Human AI firearm handler proposal. Not included in colonialmarines.dme yet.

/datum/human_ai_firearm_handler/smartgun
	gun_types = list(
		/obj/item/weapon/gun/smartgun,
		/obj/item/weapon/gun/pkp,
	)

/datum/human_ai_firearm_handler/smartgun/do_reload(datum/human_ai_firearm_context/context)
	if(can_use(context) && !context.reload_item)
		context.set_reload_item(find_reload_item(context))
	if(!can_use(context) || !context.mag)
		return FALSE
	context.prepare_primary_weapon()
	context.unwield_weapon()
	context.swap_hand()
	context.alt_click_item()
	context.sleep_short()
	context.swap_hand()
	if(context.firearm.current_mag)
		context.unload_for_reload()
	context.swap_hand()
	context.sleep_micro()
	context.AI.inventory.equip_item_from_equipment_map(HUMAN_AI_AMMUNITION, context.mag)
	context.sleep_short()
	context.insert_ammo()
	context.sleep_short()
	context.alt_click_item()
	context.sleep_short()
	context.swap_hand()
	context.wield_primary_sleep()
	return TRUE
