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
	if(. == ONGOING_ACTION_COMPLETED)
		return .

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
	var/datum/human_ai_firearm_profile/gun_data = brain.inventory.get_gun_data()
	if(gun_data.disposable)
		brain.tied_controller.drop_held_item(primary_weapon)
		brain.inventory.remove_from_pickup(primary_weapon)
		brain.inventory.set_primary_weapon(null)
		qdel(src)
		return

	currently_reloading = TRUE

	/// Find ammo
	var/datum/human_ai_firearm_context/context = new(primary_weapon, brain)
	var/datum/human_ai_firearm_handler/handler = context.get_handler()
	var/obj/item/reload_item = handler?.find_reload_item(context)
	if(!reload_item)
		qdel(context)
		brain.guns.mark_tried_reload()
		qdel(src)
		return

	context.set_reload_item(reload_item)
	brain.communication.say_reload_line()
	handler.do_reload(context)
	qdel(context)

	/// When do_reload() stops sleeping, let us check things one last time
	currently_reloading = FALSE

/datum/ai_action/reload/proc/primary_ammo_search()
	var/obj/item/weapon/gun/primary_weapon = brain.inventory.get_primary_weapon()
	var/datum/human_ai_firearm_context/context = new(primary_weapon, brain)
	var/datum/human_ai_firearm_handler/handler = context.get_handler()
	var/obj/item/reload_item = handler?.find_reload_item(context)
	qdel(context)
	return reload_item
