#define EXTRA_CHECK_DISTANCE_MULTIPLIER 0.20

/datum/human_ai_module/targeting
	module_id = "targeting"
	required_module_types = list(/datum/human_ai_module/perception, /datum/human_ai_module/profile)

	/// Ref to the currently focused (and shooting at) target
	var/atom/movable/current_target
	/// Current focused target turf or explicit target turf.
	var/turf/target_turf
	/// Recent turf where a live target was last seen before being lost.
	var/turf/last_known_target_turf
	/// World time when `last_known_target_turf` was stored.
	var/last_known_target_time = 0
	/// How long a lost visible target remains worth investigating.
	var/last_known_target_memory_duration = 10 SECONDS
	/// If TRUE, we care about the target being in view after shooting at them. If not, then we only do a line check instead
	var/requires_vision = TRUE

/datum/human_ai_module/targeting/Destroy(force, ...)
	lose_target(FALSE)
	. = ..()

/datum/human_ai_module/targeting/reset_module()
	clear_target_turf()
	lose_target(FALSE)

/datum/human_ai_module/targeting/suspend_module(clear_inventory = FALSE)
	clear_target_turf()
	lose_target(FALSE)

/datum/human_ai_module/targeting/proc/can_continue_targeting_work()
	return brain?.can_continue_runtime_work()

/datum/human_ai_module/targeting/process_module(delta_time)
	if(!can_continue_targeting_work())
		return
	if(!has_current_target())
		set_target(get_target())

/datum/human_ai_module/targeting/on_ai_event(datum/human_ai_event/event)
	switch(event.event_type)
		if(HUMAN_AI_EVENT_PROJECTILE_THREAT)
			var/obj/projectile/bullet = event.data?["bullet"]
			on_projectile_threat(bullet, event.data?["from_direct_hit"], event.data?["threat_source"])
		if(HUMAN_AI_EVENT_COMBAT_EXIT_STARTED)
			on_combat_exit_started(event.data?["should_holster_primary"])
		if(HUMAN_AI_EVENT_COMBAT_EXIT_FINISHED, HUMAN_AI_EVENT_COMBAT_EXIT_FORCE_CLEARED)
			on_combat_exit_finished(event.data?["combat_exit_context"])
		if(HUMAN_AI_EVENT_BODY_POSITION_CHANGED)
			on_body_position_changed(event.data?["new_position"], event.data?["old_position"])
		if(HUMAN_AI_EVENT_MOVED)
			on_moved(event.data?["oldloc"], event.data?["direction"], event.data?["forced"])

/datum/human_ai_module/targeting/on_projectile_threat(obj/projectile/bullet, from_direct_hit = FALSE, atom/movable/firer = null)
	if(!can_continue_targeting_work())
		return

	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return

	if(!firer)
		return

	if(!brain.can_target(firer))
		return

	if(controller.get_distance_to(firer) <= brain.get_targeting_view_distance())
		set_target(firer)

/datum/human_ai_module/targeting/on_combat_exit_started(should_holster_primary = TRUE)
	if(!can_continue_targeting_work())
		return
	lose_target(FALSE)

/datum/human_ai_module/targeting/on_combat_exit_finished(list/combat_exit_context)
	if(!can_continue_targeting_work())
		return

	if(combat_exit_context?["force_clear"])
		lose_target(FALSE)

	if(combat_exit_context?["clear_target_turf"])
		clear_target_turf()

/datum/human_ai_module/targeting/on_body_position_changed(new_position, old_position)
	if(!can_continue_targeting_work())
		return
	if(has_current_target())
		update_target_pos() // SS220 EDIT: refresh transient combat targeting state after knockdown recovery

/datum/human_ai_module/targeting/on_moved(atom/oldloc, direction, forced)
	if(!can_continue_targeting_work())
		return
	update_target_pos()

/datum/human_ai_module/targeting/proc/set_target(atom/movable/new_target)
	if(!can_continue_targeting_work())
		return

	lose_target(FALSE)

	if(!is_valid_target_ref(new_target))
		return

	RegisterSignal(new_target, COMSIG_PARENT_QDELETING, PROC_REF(on_target_delete), TRUE)
	RegisterSignal(new_target, COMSIG_MOVABLE_MOVED, PROC_REF(on_target_move), TRUE)
	if(istype(new_target, /mob/living))
		RegisterSignal(new_target, COMSIG_MOB_DEATH, PROC_REF(on_target_death), TRUE)
	if(istype(new_target, /obj/structure/machinery/defenses))
		RegisterSignal(new_target, COMSIG_SENTRY_DESTROYED_ALERT, PROC_REF(on_target_destroy), TRUE)
	// Vehicles do not currently expose a destroyed signal; target validity is checked by perception.
	/*
	if(istype(new_target, /obj/vehicle/multitile))
		RegisterSignal(new_target, COMSIG_VEHICLE_DESTROYED_ALERT, PROC_REF(on_target_destroy), TRUE)
	*/

	current_target = new_target
	target_turf = get_turf(current_target)
	clear_last_known_target()

	if(brain)
		brain.on_target_changed(null, current_target)

/datum/human_ai_module/targeting/proc/set_target_turf_direct(turf/new_target_turf)
	target_turf = new_target_turf
	clear_last_known_target()

/datum/human_ai_module/targeting/proc/clear_target_turf()
	target_turf = null
	clear_last_known_target()

/datum/human_ai_module/targeting/proc/get_target_turf()
	RETURN_TYPE(/turf)
	return target_turf || get_last_known_target_turf()

/datum/human_ai_module/targeting/proc/has_target_turf()
	return !!get_target_turf()

/datum/human_ai_module/targeting/proc/get_target_or_threat_turf()
	RETURN_TYPE(/turf)
	var/turf/current_target_turf = get_target_turf()
	if(current_target_turf)
		return current_target_turf
	return brain.get_recent_projectile_threat_turf()

/datum/human_ai_module/targeting/proc/has_target_or_threat_turf()
	if(has_target_turf())
		return TRUE
	return brain.has_recent_projectile_threat()

/datum/human_ai_module/targeting/proc/get_shared_combat_target_turf()
	RETURN_TYPE(/turf)
	return get_current_target_turf()

/datum/human_ai_module/targeting/proc/has_shared_combat_target_turf()
	return !!get_shared_combat_target_turf()

/datum/human_ai_module/targeting/proc/get_chase_target_turf()
	RETURN_TYPE(/turf)
	var/turf/shared_target_turf = get_shared_combat_target_turf()
	if(shared_target_turf)
		return shared_target_turf
	return brain.get_recent_projectile_threat_turf()

/datum/human_ai_module/targeting/proc/get_current_target_turf()
	RETURN_TYPE(/turf)
	return target_turf

/datum/human_ai_module/targeting/proc/get_last_known_target_turf()
	RETURN_TYPE(/turf)
	if(!has_recent_lost_target())
		return null
	return last_known_target_turf

/datum/human_ai_module/targeting/proc/has_recent_lost_target()
	if(!last_known_target_turf)
		return FALSE
	if((world.time - last_known_target_time) > last_known_target_memory_duration)
		return FALSE
	return TRUE

/datum/human_ai_module/targeting/proc/remember_last_known_target_turf(turf/new_target_turf = null)
	var/turf/remembered_turf = new_target_turf
	if(!remembered_turf)
		remembered_turf = target_turf
	if(!remembered_turf && current_target)
		remembered_turf = get_turf(current_target)
	if(!remembered_turf)
		return FALSE

	last_known_target_turf = remembered_turf
	last_known_target_time = world.time
	return TRUE

/datum/human_ai_module/targeting/proc/clear_last_known_target()
	last_known_target_turf = null
	last_known_target_time = 0

/datum/human_ai_module/targeting/proc/get_current_target()
	RETURN_TYPE(/atom/movable)
	return current_target

/datum/human_ai_module/targeting/proc/has_current_target()
	return !!current_target

/datum/human_ai_module/targeting/proc/get_aim_target()
	return current_target || target_turf || get_last_known_target_turf()

/datum/human_ai_module/targeting/proc/lose_target(remember_last_known = TRUE)
	var/atom/movable/old_target = current_target
	if(remember_last_known && current_target)
		remember_last_known_target_turf()

	if(current_target)
		UnregisterSignal(current_target, COMSIG_PARENT_QDELETING)
		UnregisterSignal(current_target, COMSIG_MOVABLE_MOVED)
		if(istype(current_target, /mob/living))
			UnregisterSignal(current_target, COMSIG_MOB_DEATH)
		if(istype(current_target, /obj/structure/machinery/defenses))
			UnregisterSignal(current_target, COMSIG_SENTRY_DESTROYED_ALERT)
		// Vehicles do not currently expose a destroyed signal; target validity is checked by perception.
		/*
		if(istype(current_target, /obj/vehicle/multitile))
			UnregisterSignal(current_target, COMSIG_VEHICLE_DESTROYED_ALERT)
		*/

	current_target = null
	target_turf = null
	if(!remember_last_known)
		clear_last_known_target()

	if(brain)
		brain.on_target_changed(old_target, null)

/datum/human_ai_module/targeting/proc/on_target_delete(datum/source, force)
	SIGNAL_HANDLER
	lose_target(FALSE)

/datum/human_ai_module/targeting/proc/on_target_death(datum/source)
	SIGNAL_HANDLER
	lose_target(FALSE)

/datum/human_ai_module/targeting/proc/on_target_destroy(datum/source)
	SIGNAL_HANDLER
	lose_target(FALSE)

/datum/human_ai_module/targeting/proc/can_handle_runtime_target_signal()
	return can_continue_targeting_work()

/datum/human_ai_module/targeting/proc/on_target_move(atom/oldloc, dir, forced)
	SIGNAL_HANDLER
	if(!can_handle_runtime_target_signal())
		return
	update_target_pos()

/datum/human_ai_module/targeting/proc/update_target_pos()
	if(!can_continue_targeting_work() || !brain.has_valid_tied_human())
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
			lose_target()

/datum/human_ai_module/targeting/proc/get_target()
	if(!can_continue_targeting_work() || !has_valid_owner())
		return null
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return null

	var/list/viable_targets = brain.get_visible_target_candidates()
	var/atom/movable/closest_target
	var/smallest_distance = INFINITY

	for(var/atom/movable/potential_target as anything in viable_targets)
		var/distance = controller.get_distance_to(potential_target)

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

/datum/human_ai_module/targeting/proc/has_valid_owner()
	return brain && brain.has_valid_tied_human()

/datum/human_ai_module/targeting/proc/is_valid_target_ref(atom/movable/target)
	return target && !QDELETED(target)

#undef EXTRA_CHECK_DISTANCE_MULTIPLIER
