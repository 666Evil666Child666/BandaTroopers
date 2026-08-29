// Raw weapon callback primitives

/datum/human_tied_controller/proc/unload_weapon(obj/item/weapon/gun/gun)
	if(!can_directly_control() || !gun)
		return FALSE
	gun.unload(tied_human)
	return TRUE

/datum/human_tied_controller/proc/start_weapon_fire(obj/item/weapon/gun/weapon, delay = 0)
	if(!can_directly_control() || !weapon)
		return FALSE
	addtimer(CALLBACK(weapon, TYPE_PROC_REF(/obj/item/weapon/gun, start_fire), tied_human), delay)
	return TRUE

/datum/human_tied_controller/proc/start_weapon_unique_action(obj/item/weapon/weapon, delay = 0)
	if(!can_directly_control() || !weapon)
		return FALSE
	addtimer(CALLBACK(weapon, TYPE_PROC_REF(/obj/item/weapon, unique_action), tied_human), delay)
	return TRUE

/datum/human_tied_controller/proc/get_ai_followup_fire_callback(obj/item/weapon/gun/weapon, atom/movable/current_target)
	if(!can_read_puppet() || !weapon)
		return null
	return weapon.get_ai_followup_fire_callback(tied_human, current_target)

/datum/human_tied_controller/proc/get_ai_followup_fire_delay(obj/item/weapon/gun/weapon, atom/movable/current_target)
	if(!can_read_puppet() || !weapon)
		return 0
	return weapon.get_ai_followup_fire_delay(tied_human, current_target)

/datum/human_tied_controller/proc/get_ai_followup_fire_cooldown(obj/item/weapon/gun/weapon, atom/movable/current_target)
	if(!can_read_puppet() || !weapon)
		return 0
	return weapon.get_ai_followup_fire_cooldown(tied_human, current_target)

/datum/human_tied_controller/proc/can_ai_use_weapon(obj/item/weapon/gun/weapon)
	if(!can_read_puppet() || !weapon)
		return FALSE
	return weapon.ai_can_use(tied_human, brain)

/datum/human_tied_controller/proc/do_reload(datum/firearm_appraisal/gun_data, obj/item/weapon/gun/weapon, obj/item/ammo_magazine/mag)
	if(!can_directly_control() || !gun_data || !weapon || !mag)
		return FALSE
	gun_data.do_reload(weapon, mag, tied_human, brain)
	return TRUE

/datum/human_tied_controller/proc/before_fire(datum/firearm_appraisal/gun_data, obj/item/weapon/gun/weapon)
	if(!can_directly_control() || !gun_data || !weapon)
		return FALSE
	gun_data.before_fire(weapon, tied_human, brain)
	return TRUE

/datum/human_tied_controller/proc/get_firearm_primary_weight(datum/firearm_appraisal/gun_data)
	if(!can_read_puppet() || !gun_data)
		return 0
	return gun_data.get_primary_weight(tied_human)
