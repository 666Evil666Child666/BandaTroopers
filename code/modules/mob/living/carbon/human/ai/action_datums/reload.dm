/datum/ai_action/reload
	name = "Reload"
	action_flags = ACTION_USING_HANDS
	required_ai_modules = list(/datum/human_ai_module/guns, /datum/human_ai_module/inventory)
	var/currently_reloading

/datum/ai_action/reload/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !inventory)
		return 0

	if(brain.has_tried_reload())
		return 0

	if(!inventory.has_gun_data())
		return 0

	if(!brain.should_reload())
		return 0

	return 15

/datum/ai_action/reload/Destroy(force, ...)
	currently_reloading = FALSE
	return ..()

/datum/ai_action/reload/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !inventory)
		return ONGOING_ACTION_COMPLETED

	if(currently_reloading)
		return ONGOING_ACTION_UNFINISHED

	var/obj/item/weapon/gun/primary_weapon = inventory.get_primary_weapon()
	if(!primary_weapon || brain.has_tried_reload() || !brain.should_reload())
		return ONGOING_ACTION_COMPLETED

	reload()
	return ONGOING_ACTION_UNFINISHED

/datum/ai_action/reload/proc/reload()
	set waitfor = FALSE

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !controller || !inventory)
		return

	var/obj/item/weapon/gun/primary_weapon = inventory.get_primary_weapon()
	var/datum/human_ai_firearm_profile/gun_data = inventory.get_gun_data()
	if(gun_data.disposable)
		controller.drop_held_item(primary_weapon)
		inventory.unqueue_pickup(primary_weapon)
		inventory.set_primary_weapon(null)
		qdel(src)
		return

	currently_reloading = TRUE

	/// Find ammo
	var/datum/human_ai_firearm_context/firearm_context = new(primary_weapon, brain)
	var/datum/human_ai_firearm_handler/handler = firearm_context.get_handler()
	var/obj/item/reload_item = handler?.find_reload_item(firearm_context)
	if(!reload_item)
		qdel(firearm_context)
		brain.mark_tried_reload()
		qdel(src)
		return

	firearm_context.set_reload_item(reload_item)
	brain.say_reload_line()
	handler.do_reload(firearm_context)
	qdel(firearm_context)

	if(!context?.can_continue())
		return

	/// When do_reload() stops sleeping, let us check things one last time
	currently_reloading = FALSE

/datum/ai_action/reload/proc/primary_ammo_search()
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !inventory)
		return

	var/obj/item/weapon/gun/primary_weapon = inventory.get_primary_weapon()
	var/datum/human_ai_firearm_context/firearm_context = new(primary_weapon, brain)
	var/datum/human_ai_firearm_handler/handler = firearm_context.get_handler()
	var/obj/item/reload_item = handler?.find_reload_item(firearm_context)
	qdel(firearm_context)
	return reload_item
