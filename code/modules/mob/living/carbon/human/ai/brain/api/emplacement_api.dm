// Human AI emplacement API.
// Stationary sniper and machinegunner home positions.

/datum/human_ai_brain/proc/has_sniper_home()
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	return emplacement_module?.has_sniper_home()

/datum/human_ai_brain/proc/set_sniper_home(turf/home, new_dir = SOUTH)
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	emplacement_module?.set_sniper_home(home, new_dir)

/datum/human_ai_brain/proc/get_sniper_home()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	return emplacement_module?.get_sniper_home()

/datum/human_ai_brain/proc/get_sniper_dir()
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	return emplacement_module?.get_sniper_dir()

/datum/human_ai_brain/proc/has_machinegunner_home()
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	return emplacement_module?.has_machinegunner_home()

/datum/human_ai_brain/proc/set_machinegunner_home(turf/home, new_dir = SOUTH)
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	emplacement_module?.set_machinegunner_home(home, new_dir)

/datum/human_ai_brain/proc/get_machinegunner_home()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	return emplacement_module?.get_machinegunner_home()

/datum/human_ai_brain/proc/get_machinegunner_dir()
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	return emplacement_module?.get_machinegunner_dir()

/datum/human_ai_brain/proc/is_stationary_fire_blocked()
	var/datum/human_ai_module/emplacement/emplacement_module = get_emplacement_module()
	if(!emplacement_module)
		return FALSE
	return emplacement_module.is_stationary_fire_blocked()
