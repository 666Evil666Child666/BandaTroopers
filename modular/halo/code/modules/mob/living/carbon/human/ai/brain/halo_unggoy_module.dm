/datum/human_ai_module/halo_unggoy/proc/configure(new_role, new_panic_health_pct = 0, new_panics_without_leader = FALSE, new_ignore_panic = FALSE, new_overheat_retreat = TRUE)
	runtime = TRUE
	role = new_role
	panic_health_pct = new_panic_health_pct
	panics_without_leader = new_panics_without_leader
	ignore_panic = new_ignore_panic
	overheat_retreat = new_overheat_retreat
	invalidate_runtime_caches()

/datum/human_ai_module/halo_unggoy/proc/configure_suicide_bomber(new_suicide_prime_range = 5)
	runtime = TRUE
	suicide_bomber = TRUE
	suicide_prime_range = new_suicide_prime_range

/datum/human_ai_module/halo_unggoy/proc/invalidate_runtime_caches()
	cached_squad_anchor_time = -1
	cached_squad_anchor = null

/datum/human_ai_module/halo_unggoy/proc/is_active()
	return runtime

/datum/human_ai_module/halo_unggoy/proc/is_suicide_bomber()
	return suicide_bomber

/datum/human_ai_module/halo_unggoy/proc/get_suicide_prime_range()
	return suicide_prime_range

/datum/human_ai_module/halo_unggoy/proc/get_squad()
	return brain.get_squad_datum()

/datum/human_ai_module/halo_unggoy/proc/get_squad_leader()
	return brain.get_squad_leader()

/datum/human_ai_module/halo_unggoy/proc/has_active_squad_leader()
	var/datum/human_ai_brain/leader = get_squad_leader()
	if(!leader)
		return FALSE
	if(leader == brain)
		return TRUE
	if(!leader.has_valid_tied_human())
		return FALSE
	var/datum/human_tied_controller/leader_controller = leader.halo_get_controller()
	if(!leader_controller)
		return FALSE
	if(leader_controller.is_dead())
		return FALSE
	if(leader_controller.is_incapacitated())
		return FALSE
	return TRUE

/datum/human_ai_module/halo_unggoy/proc/get_squad_anchor()
	if(!runtime)
		return null

	if(cached_squad_anchor_time == world.time)
		return cached_squad_anchor

	var/datum/human_ai_brain/leader = get_squad_leader()
	var/datum/human_tied_controller/leader_controller = leader?.halo_get_controller()
	var/turf/anchor = leader_controller?.get_current_turf()
	if(anchor)
		cached_squad_anchor_time = world.time
		cached_squad_anchor = anchor
		return anchor

	var/list/squad_members = brain.get_squad_members()
	if(!length(squad_members))
		cached_squad_anchor_time = world.time
		cached_squad_anchor = null
		return null

	var/anchor_x = 0
	var/anchor_y = 0
	var/anchor_z = 0
	var/valid_members = 0
	for(var/datum/human_ai_brain/member as anything in squad_members)
		if(!member?.has_valid_tied_human())
			continue
		var/datum/human_tied_controller/member_controller = member.halo_get_controller()
		if(!member_controller)
			continue

		var/turf/member_turf = member_controller.get_current_turf()
		if(!member_turf)
			continue

		if(member_controller.is_dead() || member_controller.is_incapacitated())
			continue

		anchor_x += member_turf.x
		anchor_y += member_turf.y
		anchor_z = member_turf.z
		valid_members++

	if(!valid_members)
		cached_squad_anchor_time = world.time
		cached_squad_anchor = null
		return null

	cached_squad_anchor_time = world.time
	cached_squad_anchor = locate(round(anchor_x / valid_members), round(anchor_y / valid_members), anchor_z)
	return cached_squad_anchor

/datum/human_ai_module/halo_unggoy/proc/get_health_pct()
	if(!brain.has_valid_tied_human())
		return 1
	var/datum/human_tied_controller/controller = brain.halo_get_controller()
	if(!controller)
		return 1
	return controller.get_health_ratio()

/datum/human_ai_module/halo_unggoy/proc/should_panic()
	if(!runtime || ignore_panic || !brain.has_valid_tied_human())
		return FALSE

	if((panic_health_pct > 0) && (get_health_pct() <= panic_health_pct))
		return TRUE

	if(!panics_without_leader || !brain.has_squad() || brain.is_squad_leader())
		return FALSE

	return !has_active_squad_leader()

/datum/human_ai_module/halo_unggoy/proc/should_retreat_on_overheat()
	if(!runtime || !overheat_retreat || !brain.has_valid_tied_human())
		return FALSE

	if(!brain.halo_covenant_get_threat_atom())
		return FALSE

	return brain.halo_covenant_weapon_is_cooling(brain.halo_get_inventory()?.get_primary_weapon())

/datum/human_ai_module/halo_unggoy/proc/should_hold_anchor_on_overheat()
	if(!should_retreat_on_overheat())
		return FALSE

	return has_active_squad_leader()

/datum/human_ai_module/halo_unggoy/proc/should_flee_on_overheat()
	if(!should_retreat_on_overheat())
		return FALSE

	return !has_active_squad_leader()

/datum/human_ai_module/halo_unggoy/proc/should_use_cover_retreat()
	if(brain.halo_should_disable_cover_retreat())
		return FALSE

	return should_panic() || should_hold_anchor_on_overheat()

/datum/human_ai_module/halo_unggoy/proc/should_retreat()
