#define EXTRA_CHECK_DISTANCE_MULTIPLIER 0.20

/datum/human_ai_module/targeting
	/// Ref to the currently focused (and shooting at) target
	var/atom/movable/current_target
	/// Last turf our target was seen at
	var/turf/target_turf
	/// At how far out the AI can see cloaked enemies
	var/cloak_visible_range = 3
	/// If TRUE, we care about the target being in view after shooting at them. If not, then we only do a line check instead
	var/requires_vision = TRUE

	COOLDOWN_DECLARE(fire_offscreen)

/datum/human_ai_module/targeting/Destroy(force, ...)
	lose_target()
	. = ..()

/datum/human_ai_module/targeting/proc/set_target(atom/movable/new_target)
	lose_target()

	if(!is_valid_target_ref(new_target))
		return

	RegisterSignal(new_target, COMSIG_PARENT_QDELETING, PROC_REF(on_target_delete), TRUE)
	RegisterSignal(new_target, COMSIG_MOVABLE_MOVED, PROC_REF(on_target_move), TRUE)
	if(istype(new_target, /mob/living))
		RegisterSignal(new_target, COMSIG_MOB_DEATH, PROC_REF(on_target_death), TRUE)
	if(istype(new_target, /obj/structure/machinery/defenses))
		RegisterSignal(new_target, COMSIG_SENTRY_DESTROYED_ALERT, PROC_REF(on_target_destroy), TRUE)
	// Vehicles do not currently expose a destroyed signal; target validity is checked by can_target_vehicle().
	/*
	if(istype(new_target, /obj/vehicle/multitile))
		RegisterSignal(new_target, COMSIG_VEHICLE_DESTROYED_ALERT, PROC_REF(on_target_destroy), TRUE)
	*/

	current_target = new_target
	target_turf = get_turf(current_target)

	if(brain)
		brain.inventory.invalidate_nearby_item_search()

/datum/human_ai_module/targeting/proc/set_target_turf(turf/new_target_turf, duration = 4 SECONDS)
	if(!new_target_turf)
		return

	target_turf = new_target_turf
	COOLDOWN_START(src, fire_offscreen, duration)

/datum/human_ai_module/targeting/proc/lose_target()
	if(current_target)
		UnregisterSignal(current_target, COMSIG_PARENT_QDELETING)
		UnregisterSignal(current_target, COMSIG_MOVABLE_MOVED)
		if(istype(current_target, /mob/living))
			UnregisterSignal(current_target, COMSIG_MOB_DEATH)
		if(istype(current_target, /obj/structure/machinery/defenses))
			UnregisterSignal(current_target, COMSIG_SENTRY_DESTROYED_ALERT)
		// Vehicles do not currently expose a destroyed signal; target validity is checked by can_target_vehicle().
		/*
		if(istype(current_target, /obj/vehicle/multitile))
			UnregisterSignal(current_target, COMSIG_VEHICLE_DESTROYED_ALERT)
		*/

	current_target = null
	target_turf = null

	if(brain)
		brain.inventory.invalidate_nearby_item_search()

/datum/human_ai_module/targeting/proc/on_target_delete(datum/source, force)
	SIGNAL_HANDLER
	lose_target()

/datum/human_ai_module/targeting/proc/on_target_death(datum/source)
	SIGNAL_HANDLER
	lose_target()

/datum/human_ai_module/targeting/proc/on_target_destroy(datum/source)
	SIGNAL_HANDLER
	lose_target()

/datum/human_ai_module/targeting/proc/on_target_move(atom/oldloc, dir, forced)
	SIGNAL_HANDLER
	update_target_pos()

/datum/human_ai_module/targeting/proc/update_target_pos()
	if(!brain || !brain.has_valid_tied_human())
		target_turf = null
		return

	if(current_target)
		if(brain.tied_human in viewers(brain.profile.view_distance, current_target))
			target_turf = get_turf(current_target)
		else
			COOLDOWN_START(src, fire_offscreen, 2 SECONDS)
			lose_target()

/datum/human_ai_module/targeting/proc/get_target()
	if(!has_valid_owner())
		return null

	var/list/viable_targets = list()
	var/atom/movable/closest_target
	var/smallest_distance = INFINITY

	var/list/dir_cone
	var/rear_view_penalty = 0

	if(brain.profile.scope_vision)
		dir_cone = reverse_nearby_direction(reverse_direction(brain.tied_human.dir))
		rear_view_penalty = brain.profile.view_distance / 7 - 1

	for(var/atom/movable/potential_target in view(brain.profile.view_distance, brain.tied_human))
		if(potential_target == brain.tied_human)
			continue

		var/distance = get_dist(brain.tied_human, potential_target)

		if(!can_acquire_from_direction(potential_target, distance, dir_cone, rear_view_penalty))
			continue

		if(!can_target(potential_target))
			continue

		viable_targets += potential_target

		if(smallest_distance <= distance)
			continue

		closest_target = potential_target
		smallest_distance = distance

	return pick_target_near_closest(viable_targets, closest_target, smallest_distance)

/datum/human_ai_module/targeting/proc/pick_target_near_closest(list/viable_targets, atom/movable/closest_target, smallest_distance)
	if(!closest_target || !length(viable_targets))
		return null

	var/extra_check_distance = round(smallest_distance * EXTRA_CHECK_DISTANCE_MULTIPLIER)
	if(extra_check_distance < 1)
		return closest_target

	var/list/final_targets = list()
	for(var/atom/movable/target as anything in viable_targets)
		if(target == closest_target)
			continue

		if(get_dist(target, closest_target) <= extra_check_distance)
			final_targets += target

	return length(final_targets) ? pick(final_targets) : closest_target

/datum/human_ai_module/targeting/proc/can_acquire_from_direction(atom/movable/target, distance, list/dir_cone, rear_view_penalty)
	if(!has_valid_owner())
		return FALSE

	if(!is_valid_target_ref(target))
		return FALSE

	if(!brain.profile.scope_vision)
		return TRUE

	if((distance > 7) && !(get_dir(brain.tied_human, target) in dir_cone))
		return FALSE

	if(istype(target, /mob/living))
		var/rear_view_check = (get_dir(brain.tied_human, target) in reverse_nearby_direction(brain.tied_human.dir))
		if(rear_view_check && (distance > brain.profile.view_distance - rear_view_penalty))
			return FALSE

	return TRUE

/datum/human_ai_module/targeting/proc/can_target(atom/movable/target)
	if(!has_valid_owner())
		return FALSE

	if(!is_valid_target_ref(target))
		return FALSE

	if(istype(target, /mob/living))
		return can_target_mob(target)

	if(istype(target, /obj/vehicle/multitile))
		return can_target_vehicle(target)

	if(istype(target, /obj/structure/machinery/defenses))
		return can_target_defense(target)

	return FALSE

/datum/human_ai_module/targeting/proc/can_target_defense(obj/structure/machinery/defenses/defense)
	if(!istype(defense))
		return FALSE

	if(defense.stat & DEFENSE_DESTROYED)
		return FALSE

	if(brain.tied_human.faction in defense.faction_group)
		return FALSE

	return path_check(defense)

/datum/human_ai_module/targeting/proc/can_target_vehicle(obj/vehicle/multitile/vehicle)
	if(!istype(vehicle))
		return FALSE

	if(vehicle.health <= 0)
		return FALSE

	if(brain.faction.faction_check(vehicle))
		return FALSE

	return path_check(vehicle)

/datum/human_ai_module/targeting/proc/can_target_mob(mob/living/target)
	if(!istype(target))
		return FALSE

	if(target.stat == DEAD)
		return FALSE

	if(!brain.profile.shoot_to_kill && (target.stat == UNCONSCIOUS || (locate(/datum/effects/crit) in target.effects_list)))
		return FALSE

	if(brain.faction.faction_check(target))
		return FALSE

	var/distance = get_dist(brain.tied_human, target)

	if(!brain.inventory.has_nightvision && distance > 1 && !can_detect_living_target(target))
		return FALSE

	if(HAS_TRAIT(target, TRAIT_CLOAKED) && get_dist(brain.tied_human, target) > cloak_visible_range)
		return FALSE

	if(!path_check(target))
		return FALSE

	return TRUE

/datum/human_ai_module/targeting/proc/can_detect_living_target(mob/living/target)
	for(var/turf/tile in range(1, target))
		if(tile.luminosity || (tile.dynamic_lumcount >= 1))
			return TRUE

	return FALSE

/datum/human_ai_module/targeting/proc/path_check(atom/movable/target)
	if(!has_valid_owner())
		return FALSE

	if(!is_valid_target_ref(target))
		return FALSE

	var/turf/source_turf = get_turf(brain.tied_human)
	var/turf/target_turf = get_turf(target)
	if(!source_turf || !target_turf)
		return FALSE

	var/list/turf_list = get_line(source_turf, target_turf, FALSE)
	//проверка на препятствия на пути пули. ИИшке незачем стрелять в стену или непростреливаемые препятсвия за исключением разрушаемых.
	for(var/turf/tile in turf_list)
		if(tile.density)
			return FALSE
		for(var/atom/movable/obstacle in tile)
			if(obstacle.density && obstacle != target && obstacle != brain.tied_human && !istype(obstacle, /mob))
				if(istype(obstacle, /obj/structure/window) || istype(obstacle, /obj/structure/grille) || istype(obstacle, /obj/structure/barricade))
					continue
				return FALSE
	//модифицируем список для проверки на союзников, добавляя соседние тайлы и уберая тайл стрелка.
	turf_list.Cut(1, 2) // starting turf
	var/list/checked_turfs = list()// SS220 EDIT AI
	for(var/i in 1 to length(turf_list))
		var/turf/tile = turf_list[i]
		if(!checked_turfs[tile])
			checked_turfs[tile] = TRUE
			for(var/mob/living/carbon/human/possible_friendly in tile)
				if(possible_friendly.body_position == LYING_DOWN)
					continue
				if(brain.faction.faction_check(possible_friendly))
					return FALSE

		if(i <= 3)
			continue

		for(var/turf/neighbor in tile.AdjacentTurfs())
			if(checked_turfs[neighbor])
				continue
			checked_turfs[neighbor] = TRUE
			for(var/mob/living/carbon/human/possible_friendly in neighbor)
				if(possible_friendly.body_position == LYING_DOWN)
					continue
				if(brain.faction.faction_check(possible_friendly))
					return FALSE
	return TRUE

/datum/human_ai_module/targeting/proc/has_valid_owner()
	return brain && brain.has_valid_tied_human()

/datum/human_ai_module/targeting/proc/is_valid_target_ref(atom/movable/target)
	return target && !QDELETED(target)

#undef EXTRA_CHECK_DISTANCE_MULTIPLIER
