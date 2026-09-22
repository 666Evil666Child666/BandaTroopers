/datum/human_ai_module/emplacement
	module_id = "emplacement"
	required_module_types = list(
		/datum/human_ai_module/cover,
		/datum/human_ai_module/guns,
		/datum/human_ai_module/health,
	)
	var/turf/sniper_home
	var/sniper_dir = SOUTH
	var/turf/machinegunner_home
	var/machinegunner_dir = SOUTH

/datum/human_ai_module/emplacement/proc/set_sniper_home(turf/home, new_dir = SOUTH)
	sniper_home = home
	sniper_dir = new_dir

/datum/human_ai_module/emplacement/proc/set_machinegunner_home(turf/home, new_dir = SOUTH)
	machinegunner_home = home
	machinegunner_dir = new_dir

/datum/human_ai_module/emplacement/proc/has_sniper_home()
	return sniper_home && !QDELETED(sniper_home)

/datum/human_ai_module/emplacement/proc/get_sniper_home()
	RETURN_TYPE(/turf)
	return sniper_home

/datum/human_ai_module/emplacement/proc/get_sniper_dir()
	return sniper_dir

/datum/human_ai_module/emplacement/proc/has_machinegunner_home()
	return machinegunner_home && !QDELETED(machinegunner_home)

/datum/human_ai_module/emplacement/proc/get_machinegunner_home()
	RETURN_TYPE(/turf)
	return machinegunner_home

/datum/human_ai_module/emplacement/proc/get_machinegunner_dir()
	return machinegunner_dir

/datum/human_ai_module/emplacement/proc/has_stationary_role()
	return has_sniper_home() || has_machinegunner_home()

/datum/human_ai_module/emplacement/proc/has_owner_tried_reload()
	return brain.has_tried_reload()

/datum/human_ai_module/emplacement/proc/should_owner_block_stationary_fire_for_cover()
	return brain.should_block_stationary_fire_for_cover()

/datum/human_ai_module/emplacement/proc/is_owner_healing_someone()
	return brain.is_healing_someone()

/datum/human_ai_module/emplacement/proc/is_stationary_fire_blocked()
	return has_owner_tried_reload() || should_owner_block_stationary_fire_for_cover() || is_owner_healing_someone()
