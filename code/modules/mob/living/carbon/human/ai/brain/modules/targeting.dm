#define EXTRA_CHECK_DISTANCE_MULTIPLIER 0.20

/datum/human_ai_module/targeting
	module_id = "targeting"
	required_module_types = list(/datum/human_ai_module/faction, /datum/human_ai_module/profile)

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

/datum/human_ai_module/targeting/reset_module()
	clear_target_turf()
	lose_target()

/datum/human_ai_module/targeting/suspend_module(clear_inventory = FALSE)
	clear_target_turf()
	lose_target()

/datum/human_ai_module/targeting/process_module(delta_time)
	if(!has_current_target())
		set_target(get_target())

/datum/human_ai_module/targeting/on_ai_event(datum/human_ai_event/event)
	switch(event.event_type)
		if(HUMAN_AI_EVENT_PROJECTILE_THREAT)
			var/obj/projectile/bullet = event.data?["bullet"]
			on_projectile_threat(bullet, event.data?["from_direct_hit"])
		if(HUMAN_AI_EVENT_COMBAT_EXIT_STARTED)
			on_combat_exit_started(event.data?["should_holster_primary"])
		if(HUMAN_AI_EVENT_COMBAT_EXIT_FINISHED, HUMAN_AI_EVENT_COMBAT_EXIT_FORCE_CLEARED)
			on_combat_exit_finished(event.data?["combat_exit_context"])
		if(HUMAN_AI_EVENT_BODY_POSITION_CHANGED)
			on_body_position_changed(event.data?["new_position"], event.data?["old_position"])
		if(HUMAN_AI_EVENT_MOVED)
			on_moved(event.data?["oldloc"], event.data?["direction"], event.data?["forced"])

/datum/human_ai_module/targeting/on_projectile_threat(obj/projectile/bullet, from_direct_hit = FALSE)
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return

	var/atom/firer = bullet?.firer
	if(!firer)
		return

	if(brain.is_friendly_target(firer))
		return

	if(controller.get_distance_to(firer) <= brain.get_targeting_view_distance())
		set_target(firer)
	else
		set_target_turf(get_turf(firer), 4 SECONDS)

/datum/human_ai_module/targeting/on_combat_exit_started(should_holster_primary = TRUE)
	lose_target()

/datum/human_ai_module/targeting/on_combat_exit_finished(list/combat_exit_context)
	if(combat_exit_context?["force_clear"])
		lose_target()

	if(combat_exit_context?["clear_target_turf"])
		clear_target_turf()

/datum/human_ai_module/targeting/on_body_position_changed(new_position, old_position)
	if(has_current_target())
		update_target_pos() // SS220 EDIT: refresh transient combat targeting state after knockdown recovery

/datum/human_ai_module/targeting/on_moved(atom/oldloc, direction, forced)
	update_target_pos()

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
		brain.on_target_changed(null, current_target)

/datum/human_ai_module/targeting/proc/set_target_turf(turf/new_target_turf, duration = 4 SECONDS)
	if(!new_target_turf)
		return

	target_turf = new_target_turf
	COOLDOWN_START(src, fire_offscreen, duration)

/datum/human_ai_module/targeting/proc/set_target_turf_direct(turf/new_target_turf)
	target_turf = new_target_turf

/datum/human_ai_module/targeting/proc/clear_target_turf()
	target_turf = null

/datum/human_ai_module/targeting/proc/get_target_turf()
	RETURN_TYPE(/turf)
	return target_turf

/datum/human_ai_module/targeting/proc/has_target_turf()
	return !!target_turf

/datum/human_ai_module/targeting/proc/get_current_target()
	RETURN_TYPE(/atom/movable)
	return current_target

/datum/human_ai_module/targeting/proc/has_current_target()
	return !!current_target

/datum/human_ai_module/targeting/proc/get_aim_target()
	return current_target || target_turf

/datum/human_ai_module/targeting/proc/lose_target()
	var/atom/movable/old_target = current_target
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
		brain.on_target_changed(old_target, null)

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
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		target_turf = null
		return

	if(current_target)
		if(controller.is_in_view_of(current_target, brain.get_targeting_view_distance()))
			target_turf = get_turf(current_target)
		else
			COOLDOWN_START(src, fire_offscreen, 2 SECONDS)
			lose_target()

/datum/human_ai_module/targeting/proc/get_target()
	if(!has_valid_owner())
		return null
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return null

	var/list/viable_targets = list()
	var/atom/movable/closest_target
	var/smallest_distance = INFINITY

	var/list/dir_cone
	var/rear_view_penalty = 0

	if(brain.has_scope_vision())
		dir_cone = controller.get_reverse_dir_cone()
		rear_view_penalty = brain.get_targeting_view_distance() / 7 - 1

	for(var/atom/movable/potential_target in controller.get_view(brain.get_targeting_view_distance()))
		if(controller.is_puppet(potential_target))
			continue

		var/distance = controller.get_distance_to(potential_target)

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
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return FALSE

	if(!is_valid_target_ref(target))
		return FALSE

	if(!brain.has_scope_vision())
		return TRUE

	if((distance > 7) && !(controller.get_direction_to(target) in dir_cone))
		return FALSE

	if(istype(target, /mob/living))
		var/rear_view_check = (controller.get_direction_to(target) in controller.get_reverse_dir_cone())
		if(rear_view_check && (distance > brain.get_targeting_view_distance() - rear_view_penalty))
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

	if(brain.is_friendly_target(defense))
		return FALSE

	return path_check(defense)

/datum/human_ai_module/targeting/proc/can_target_vehicle(obj/vehicle/multitile/vehicle)
	if(!istype(vehicle))
		return FALSE

	if(vehicle.health <= 0)
		return FALSE

	if(brain.is_friendly_target(vehicle))
		return FALSE

	return path_check(vehicle)

/datum/human_ai_module/targeting/proc/can_target_mob(mob/living/target)
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return FALSE

	if(!istype(target))
		return FALSE

	if(target.stat == DEAD)
		return FALSE

	if(!brain.should_shoot_to_kill() && (target.stat == UNCONSCIOUS || (locate(/datum/effects/crit) in target.effects_list)))
		return FALSE

	if(brain.is_friendly_target(target))
		return FALSE

	var/distance = controller.get_distance_to(target)

	if(!brain.can_ignore_target_darkness() && distance > 1 && !can_detect_living_target(target))
		return FALSE

	if(HAS_TRAIT(target, TRAIT_CLOAKED) && controller.get_distance_to(target) > cloak_visible_range)
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
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return FALSE

	if(!is_valid_target_ref(target))
		return FALSE

	var/turf/source_turf = controller.get_current_turf()
	var/turf/target_turf = get_turf(target)
	if(!source_turf || !target_turf)
		return FALSE

	var/list/turf_list = get_line(source_turf, target_turf, FALSE)
	//проверка на препятствия на пути пули. ИИшке незачем стрелять в стену или непростреливаемые препятсвия за исключением разрушаемых.
	for(var/turf/tile in turf_list)
		if(tile.density)
			return FALSE
		for(var/atom/movable/obstacle in tile)
			if(obstacle.density && obstacle != target && !controller.is_puppet(obstacle) && !istype(obstacle, /mob))
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
				if(brain.is_friendly_target(possible_friendly))
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
				if(brain.is_friendly_target(possible_friendly))
					return FALSE
	return TRUE

/datum/human_ai_module/targeting/proc/has_valid_owner()
	return brain && brain.has_valid_tied_human()

/datum/human_ai_module/targeting/proc/is_valid_target_ref(atom/movable/target)
	return target && !QDELETED(target)

#undef EXTRA_CHECK_DISTANCE_MULTIPLIER
