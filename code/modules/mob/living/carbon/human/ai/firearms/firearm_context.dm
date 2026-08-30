// Isolated Human AI firearm context proposal. Not included in colonialmarines.dme yet.

/datum/human_ai_firearm_context
	var/datum/human_ai_brain/AI
	var/datum/human_tied_controller/controller
	var/obj/item/weapon/gun/firearm
	var/obj/item/ammo_magazine/mag
	var/obj/item/reload_item
	var/atom/movable/current_target
	var/turf/target_turf

/datum/human_ai_firearm_context/New(obj/item/weapon/gun/new_firearm, datum/human_ai_brain/new_ai, atom/movable/new_current_target = null, turf/new_target_turf = null, obj/item/ammo_magazine/new_mag = null, obj/item/new_reload_item = null)
	firearm = new_firearm
	AI = new_ai
	controller = AI?.tied_controller
	current_target = new_current_target
	target_turf = new_target_turf
	mag = new_mag
	reload_item = new_reload_item || new_mag

/datum/human_ai_firearm_context/proc/is_valid()
	return firearm && AI?.has_valid_tied_human() && controller

/datum/human_ai_firearm_context/proc/can_use()
	if(!is_valid())
		return FALSE
	return controller.can_ai_use_weapon(firearm)

/datum/human_ai_firearm_context/proc/get_profile()
	RETURN_TYPE(/datum/human_ai_firearm_profile)
	return GLOB.human_ai_firearm_registry?.get_profile(firearm)

/datum/human_ai_firearm_context/proc/get_handler()
	RETURN_TYPE(/datum/human_ai_firearm_handler)
	return GLOB.human_ai_firearm_registry?.get_handler(firearm)

/datum/human_ai_firearm_context/proc/set_reload_item(obj/item/new_reload_item)
	reload_item = new_reload_item
	if(istype(new_reload_item, /obj/item/ammo_magazine))
		mag = new_reload_item
	else
		mag = null
	return reload_item

/datum/human_ai_firearm_context/proc/prepare_primary_weapon()
	if(!is_valid())
		return FALSE
	AI.inventory.unholster_primary()
	AI.inventory.ensure_primary_hand(firearm)
	return TRUE

/datum/human_ai_firearm_context/proc/wield_primary()
	if(!is_valid())
		return FALSE
	AI.inventory.wield_primary()
	return TRUE

/datum/human_ai_firearm_context/proc/wield_primary_sleep()
	if(!is_valid())
		return FALSE
	AI.inventory.wield_primary_sleep()
	return TRUE

/datum/human_ai_firearm_context/proc/unwield_weapon()
	if(!is_valid())
		return FALSE
	return controller.unwield_weapon(firearm)

/datum/human_ai_firearm_context/proc/swap_hand()
	if(!is_valid())
		return FALSE
	return controller.swap_hand()

/datum/human_ai_firearm_context/proc/sleep_short()
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)

/datum/human_ai_firearm_context/proc/sleep_micro()
	sleep(AI.profile.micro_action_delay * AI.profile.action_delay_mult)

/datum/human_ai_firearm_context/proc/ensure_safety_off()
	if(!is_valid() || !(firearm.flags_gun_features & GUN_TRIGGER_SAFETY))
		return TRUE
	// Requires the controller API listed in controller_contract.dm before this subsystem is included.
	return controller.ensure_weapon_safety_off(firearm)

/datum/human_ai_firearm_context/proc/unload_for_reload()
	if(!is_valid())
		return FALSE
	// Requires the controller API listed in controller_contract.dm before this subsystem is included.
	return controller.unload_weapon_for_reload(firearm)

/datum/human_ai_firearm_context/proc/insert_ammo(obj/item/ammo_magazine/ammo = mag)
	if(!is_valid() || !ammo)
		return FALSE
	// Requires the controller API listed in controller_contract.dm before this subsystem is included.
	return controller.attackby_with_item(firearm, ammo)

/datum/human_ai_firearm_context/proc/equip_reload_item(equipment_type = HUMAN_AI_AMMUNITION)
	if(!is_valid() || !reload_item)
		return FALSE
	return AI.inventory.equip_item_from_equipment_map(equipment_type, reload_item)

/datum/human_ai_firearm_context/proc/insert_reload_item(obj/item/item = reload_item)
	if(!is_valid() || !item)
		return FALSE
	// Requires the controller API listed in controller_contract.dm before this subsystem is included.
	return controller.attackby_with_item(firearm, item)

/datum/human_ai_firearm_context/proc/use_unique_action()
	if(!is_valid())
		return FALSE
	// Requires the controller API listed in controller_contract.dm before this subsystem is included.
	return controller.use_weapon_unique_action(firearm)

/datum/human_ai_firearm_context/proc/start_unique_action(delay = 0)
	if(!is_valid())
		return FALSE
	return controller.start_weapon_unique_action(firearm, delay)

/datum/human_ai_firearm_context/proc/start_fire(delay = 0)
	if(!is_valid())
		return FALSE
	return controller.start_weapon_fire(firearm, delay)

/datum/human_ai_firearm_context/proc/fire_at_target()
	if(!is_valid() || !target_turf)
		return FALSE
	return controller.fire_weapon_at(firearm, target_turf)

/datum/human_ai_firearm_context/proc/fire_grenade_launcher_at_target()
	if(!is_valid() || !target_turf || !istype(firearm, /obj/item/weapon/gun/launcher/grenade))
		return FALSE
	var/obj/item/weapon/gun/launcher/grenade/grenade_launcher = firearm
	return controller.fire_grenade_launcher_at(grenade_launcher, target_turf)

/datum/human_ai_firearm_context/proc/alt_click_item()
	if(!is_valid())
		return FALSE
	// Requires the controller API listed in controller_contract.dm before this subsystem is included.
	return controller.alt_click_item(firearm)

/datum/human_ai_firearm_context/proc/open_weapon_chamber()
	if(!is_valid())
		return FALSE
	// Requires the controller API listed in controller_contract.dm before this subsystem is included.
	return controller.open_weapon_chamber(firearm)

/datum/human_ai_firearm_context/proc/get_followup_fire_callback()
	if(!is_valid())
		return null
	return controller.get_ai_followup_fire_callback(firearm, current_target)

/datum/human_ai_firearm_context/proc/get_followup_fire_delay()
	if(!is_valid())
		return 0
	return controller.get_ai_followup_fire_delay(firearm, current_target)

/datum/human_ai_firearm_context/proc/get_followup_fire_cooldown()
	if(!is_valid())
		return 0
	return controller.get_ai_followup_fire_cooldown(firearm, current_target)
