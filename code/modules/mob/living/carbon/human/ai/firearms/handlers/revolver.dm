// Isolated Human AI firearm revolver handler proposal. Not included in colonialmarines.dme yet.

/datum/human_ai_firearm_handler/revolver
	gun_types = list(/obj/item/weapon/gun/revolver)

/datum/human_ai_firearm_handler/revolver/before_fire(datum/human_ai_firearm_context/context)
	. = ..()
	if(!.)
		return
	var/obj/item/weapon/gun/revolver/revolver = context.firearm
	if(revolver.current_mag?.chamber_closed == FALSE)
		context.controller.unload_weapon(revolver)

/datum/human_ai_firearm_handler/revolver/do_reload(datum/human_ai_firearm_context/context)
	if(can_use(context) && !context.reload_item)
		context.set_reload_item(find_reload_item(context))
	if(!can_use(context) || !context.mag)
		return FALSE
	var/obj/item/weapon/gun/revolver/revolver = context.firearm
	context.prepare_primary_weapon()
	context.unwield_weapon()
	context.sleep_short()
	if(!can_use(context))
		return FALSE
	if(revolver.current_mag?.chamber_closed)
		context.controller.unload_weapon(revolver)
	context.swap_hand()
	context.sleep_micro()
	if(!can_use(context) || !prepare_reload_item(context) || QDELETED(context.mag))
		return FALSE
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
	else
		context.insert_ammo()
	context.sleep_micro()
	if(revolver.current_mag && !revolver.current_mag.chamber_closed)
		context.controller.unload_weapon(revolver)
	context.swap_hand()
	context.wield_primary_sleep()
	return TRUE
