// Isolated Human AI firearm handler proposal. Not included in colonialmarines.dme yet.

/datum/human_ai_firearm_handler/shotgun_db
	gun_types = list(/obj/item/weapon/gun/shotgun/double)

/datum/human_ai_firearm_handler/shotgun_db/do_reload(datum/human_ai_firearm_context/context)
	if(can_use(context) && !context.reload_item)
		context.set_reload_item(find_reload_item(context))
	if(!can_use(context) || !context.mag)
		return FALSE
	context.prepare_primary_weapon()
	context.unwield_weapon()
	context.use_unique_action()
	context.swap_hand()
	context.sleep_short()
	if(!prepare_reload_item(context))
		return FALSE
	context.sleep_short()
	context.insert_ammo()
	context.sleep_micro()
	context.insert_ammo()
	if(!QDELETED(context.mag))
		var/storage_spot = context.AI.inventory.storage_has_room(context.mag)
		if(storage_spot)
			context.sleep_micro()
			context.AI.inventory.store_item(context.mag, storage_spot, HUMAN_AI_AMMUNITION)
	context.sleep_short()
	context.swap_hand()
	context.use_unique_action()
	context.wield_primary_sleep()
	return TRUE
