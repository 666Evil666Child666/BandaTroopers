/datum/ai_action/reload
	name = "Reload"
	action_flags = ACTION_USING_HANDS
	var/currently_reloading

/datum/ai_action/reload/get_weight(datum/human_ai_brain/brain)
	if(brain.guns.has_tried_reload())
		return 0

	if(!brain.inventory.has_gun_data())
		return 0

	if(!brain.guns.should_reload())
		return 0

	return 15

/datum/ai_action/reload/Destroy(force, ...)
	currently_reloading = FALSE
	return ..()

/datum/ai_action/reload/trigger_action()
	. = ..()

	if(currently_reloading)
		return ONGOING_ACTION_UNFINISHED

	var/obj/item/weapon/gun/primary_weapon = brain.inventory.get_primary_weapon()
	if(!primary_weapon || brain.guns.has_tried_reload() || !brain.guns.should_reload())
		return ONGOING_ACTION_COMPLETED

	reload()
	return ONGOING_ACTION_UNFINISHED

/datum/ai_action/reload/proc/reload()
	set waitfor = FALSE

	var/obj/item/weapon/gun/primary_weapon = brain.inventory.get_primary_weapon()
	var/datum/firearm_appraisal/gun_data = brain.inventory.get_gun_data()
	if(gun_data.disposable)
		brain.tied_controller.drop_held_item(primary_weapon)
		brain.inventory.remove_from_pickup(primary_weapon)
		brain.inventory.set_primary_weapon(null)
		qdel(src)
		return

	currently_reloading = TRUE

	/// Find ammo
	var/obj/item/ammo_magazine/mag = primary_ammo_search()
	if(!mag)
		brain.guns.mark_tried_reload()
		qdel(src)
		return

	brain.communication.say_reload_line()
	brain.tied_controller.do_reload(gun_data, primary_weapon, mag)

	/// When do_reload() stops sleeping, let us check things one last time
	currently_reloading = FALSE

/datum/ai_action/reload/proc/primary_ammo_search()
	var/obj/item/weapon/gun/primary_weapon = brain.inventory.get_primary_weapon()
	for(var/obj/item/ammo_magazine/mag as anything in brain.inventory.get_equipment_list(HUMAN_AI_AMMUNITION))
		if(istype(primary_weapon, mag.gun_type) && brain.tied_controller.can_use_item(mag))
			return mag
