/datum/human_ai_module/cover
	module_id = "cover"
	required_module_types = list(/datum/human_ai_module/faction, /datum/human_ai_module/targeting, /datum/human_ai_module/profile, /datum/human_ai_module/perception)

	/// If TRUE, AI is currently in some form of cover
	var/in_cover = FALSE
	/// Reference to atom currently selected as a cover place
	var/atom/current_cover
	COOLDOWN_DECLARE(cover_search_cooldown)

	/// If this AI can seek cover while not possessing a gun
	var/cover_without_gun = FALSE
	/// The chance that the AI will leave cover when exiting combat
	var/peek_cover_chance = 60

/datum/human_ai_module/cover/proc/is_in_cover()
	return in_cover

/datum/human_ai_module/cover/proc/has_cover()
	return !!current_cover

/datum/human_ai_module/cover/proc/get_current_cover()
	RETURN_TYPE(/turf)
	return current_cover

/datum/human_ai_module/cover/proc/enter_cover()
	in_cover = TRUE

/datum/human_ai_module/cover/proc/end_cover()
#if defined(TESTING) || defined(HUMAN_AI_TESTING)
	if(current_cover)
		current_cover.color = null
		current_cover.maptext = null
#endif
	current_cover = null
	in_cover = FALSE

/datum/human_ai_module/cover/reset_module()
	end_cover()

/datum/human_ai_module/cover/suspend_module(clear_inventory = FALSE)
	end_cover()

/datum/human_ai_module/cover/on_ai_event(datum/human_ai_event/event)
	switch(event.event_type)
		if(HUMAN_AI_EVENT_PROJECTILE_THREAT)
			var/obj/projectile/bullet = event.data?["bullet"]
			on_projectile_threat(bullet, event.data?["from_direct_hit"])
		if(HUMAN_AI_EVENT_COMBAT_ENTERED)
			on_combat_entered(event.data?["was_in_combat"])
		if(HUMAN_AI_EVENT_COMBAT_EXIT_FINISHED, HUMAN_AI_EVENT_COMBAT_EXIT_FORCE_CLEARED)
			on_combat_exit_finished(event.data?["combat_exit_context"])
		if(HUMAN_AI_EVENT_MOVED)
			on_moved(event.data?["oldloc"], event.data?["direction"], event.data?["forced"])

/datum/human_ai_module/cover/on_projectile_threat(obj/projectile/bullet, from_direct_hit = FALSE)
	if(!from_direct_hit)
		return
	if(!brain.has_recent_projectile_threat())
		return
	var/atom/movable/threat_source = brain.get_recent_projectile_threat_source()
	var/threat_angle = brain.get_recent_projectile_threat_angle()
	if(!threat_source || isnull(threat_angle))
		return

	react_to_incoming_fire(threat_angle, threat_source)

/datum/human_ai_module/cover/on_combat_exit_finished(list/combat_exit_context)
	if(combat_exit_context?["force_clear"])
		end_cover()
		return

	if(has_cover())
		if(!prob(peek_cover_chance))
			combat_exit_context["clear_target_turf"] = TRUE
		end_cover()
	else
		combat_exit_context["clear_target_turf"] = TRUE

/datum/human_ai_module/cover/on_combat_entered(was_in_combat)
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return

	var/atom/movable/current_target = brain.get_current_target()
	if(isxeno(current_target))
		try_cover(controller.get_angle_from(current_target), current_target)

/datum/human_ai_module/cover/on_moved(atom/oldloc, direction, forced)
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return

	if(is_in_cover() && (controller.get_distance_to(get_current_cover()) > brain.get_gun_data()?.minimum_range))
		end_cover()

/datum/human_ai_module/cover/proc/react_to_incoming_fire(angle, atom/firer)
	if(!brain?.has_valid_tied_human())
		return

	if(!current_cover)
		try_cover(angle, firer)
	else if(in_cover)
		on_shot_inside_cover(angle, firer)

/// Try to get the AI to find a suitable cover tile based on the angle a projectile came from.
/datum/human_ai_module/cover/proc/try_cover(angle, atom/source)
	if(!COOLDOWN_FINISHED(src, cover_search_cooldown))
		return

	if(!(cover_without_gun || brain.has_primary_weapon()))
		return

	COOLDOWN_START(src, cover_search_cooldown, 10 SECONDS)
	brain?.on_cover_scan_started()

	var/list/turf_dict = list()
	var/cover_dir = reverse_direction(angle2dir4ai(angle))
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return

	recursive_turf_cover_scan(controller.get_current_turf(), turf_dict, cover_dir)

#ifdef TESTING
	addtimer(CALLBACK(src, PROC_REF(clear_cover_value_debug), turf_dict.Copy()), 60 SECONDS)
#endif

	cover_processing(turf_dict)

/datum/human_ai_module/cover/proc/on_shot_inside_cover(angle, atom/source)
	// Cover isn't working. Charge!
	end_cover()

/datum/human_ai_module/cover/proc/cover_processing(list/turf_dict, from_squad = FALSE)
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return

	var/most_weight = -INFINITY
	var/turf/best_cover
	for(var/turf/T as anything in turf_dict)
		var/weight = turf_dict[T]
		if(weight > most_weight)
			most_weight = weight
			best_cover = T

	if(best_cover && best_cover != controller.get_current_turf())
		turf_dict -= best_cover
		// insert cover atom deletion/move comsigs here
		current_cover = best_cover
		// SS220 EDIT: forward the resolved cover scan once with the correct turf_dict payload
		if(!from_squad)
			squad_cover_processing(turf_dict)

/// If an AI decides to go into cover, any squadmates in their view range will process on the same view dictionary so as to help with performance
/datum/human_ai_module/cover/proc/squad_cover_processing(list/turf_dict)
	if(!brain.has_squad())
		return

	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return

	for(var/datum/human_ai_brain/squaddie as anything in brain.get_squad_members())
		if(squaddie == brain)
			continue

		if(!squaddie.has_valid_tied_human())
			continue

		var/datum/human_ai_context/squaddie_context = squaddie.create_context()
		var/datum/human_tied_controller/squaddie_controller = squaddie_context.controller
		if(!squaddie_controller || controller.get_distance_to(squaddie_controller.get_current_turf()) > brain.get_view_distance())
			qdel(squaddie_context)
			continue

		if(squaddie_controller.is_incapacitated())
			qdel(squaddie_context)
			continue

		qdel(squaddie_context)
		squaddie.start_cover_search_cooldown(15 SECONDS)
		squaddie.apply_cover_processing(turf_dict, TRUE)

/// Recursively searches each tile nearby (up to 198 tiles, nearly BYOND's recursion limit) and determines how suitable it is as cover, giving it a numerical score and adding it to turf_dict
/datum/human_ai_module/cover/proc/recursive_turf_cover_scan(turf/scan_turf, list/turf_dict, cover_dir, first_iteration = TRUE)
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return FALSE

	if(length(turf_dict) > 198) // Slightly lower than byond recursion limit (200)
		return FALSE // abort if the room is too large

	if(scan_turf in turf_dict)
		return TRUE // abort if we've already been scanned

	turf_dict[scan_turf] = 0

	for(var/atom/movable/thing as anything in scan_turf.contents)
		if(thing.density && !istype(thing, /obj/structure/barricade))
			turf_dict[scan_turf] -= 1000
			if(first_iteration)
				break // We don't wanna end our cover search on self
			return TRUE // If it has something dense on it, don't bother

	var/obj/structure/barricade/cade = locate() in scan_turf.contents
	if(cade?.density && (cade?.dir in get_related_directions(cover_dir)))
		turf_dict[scan_turf] += cade.projectile_coverage / 2

	var/obj/item/explosive/mine/mine = locate() in scan_turf.contents
	if(mine)
		if(!brain.is_friendly_target(mine.iff_signal))
			turf_dict[scan_turf] -= 50
		else
			turf_dict[scan_turf] -= 5 // even if it's our mine, we don't really want to stand on it

	turf_dict[scan_turf] -= controller.get_distance_to(scan_turf)
	var/atom/movable/current_target = brain.get_current_target()
	if(current_target) // Might be smarter to hide in a different direction
		turf_dict[scan_turf] += get_dist(current_target, scan_turf) * 0.5

		if(get_dir(current_target, scan_turf) in get_related_directions(cover_dir))
			turf_dict[scan_turf] -= 20

	for(var/cardinal in shuffle(GLOB.cardinals))
		var/turf/nearby_turf = get_step(scan_turf, cardinal)
		if(!nearby_turf)
			continue

		if(istype(nearby_turf, /turf/closed))
			turf_dict[scan_turf] += 2 // Near a wall is a bit safer
			if(cardinal in get_related_directions(cover_dir))
				turf_dict[scan_turf] += 8
			continue

		var/obj/structure/reagent_dispensers/fueltank/tank = locate() in nearby_turf.contents
		if(tank)
			turf_dict[scan_turf] -= 10 // ideally not near any highly explosive fuel tanks if we can help it

#ifdef TESTING
		scan_turf.maptext = "<h2>[turf_dict[scan_turf]]</h2>"
#endif

		if(!recursive_turf_cover_scan(nearby_turf, turf_dict, cover_dir, FALSE))
			return FALSE

#ifdef TESTING
	scan_turf.maptext = "<h2>[turf_dict[scan_turf]]</h2>"
#endif

	return TRUE

/datum/human_ai_module/cover/proc/clear_cover_value_debug(list/turf_list)
	for(var/turf/T as anything in turf_list)
		T.maptext = null
