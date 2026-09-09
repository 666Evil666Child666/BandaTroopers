/datum/human_ai_module/emplacement
	module_id = "emplacement"
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

/datum/human_ai_module/emplacement/proc/has_machinegunner_home()
	return machinegunner_home && !QDELETED(machinegunner_home)

/datum/human_ai_module/emplacement/proc/has_stationary_role()
	return has_sniper_home() || has_machinegunner_home()
