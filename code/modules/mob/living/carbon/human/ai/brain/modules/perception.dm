/datum/human_ai_module/perception
	module_id = "perception"
	required_module_types = list(/datum/human_ai_module/faction, /datum/human_ai_module/profile)

	/// Nearby turfs that we're watching for bullets
	var/list/detection_turfs = list()
	/// Prevent repeated projectile detection re-entry in the same tick
	var/atom/movable/last_detected_projectile
	var/last_detected_projectile_time = -1
	/// Recent hostile projectile source remembered for offscreen response.
	var/atom/movable/recent_threat_source
	/// Recent hostile projectile source turf remembered for offscreen response.
	var/turf/recent_threat_turf
	/// Recent projectile angle remembered for cover response.
	var/recent_threat_angle

	COOLDOWN_DECLARE(threat_memory)

/datum/human_ai_module/perception/Destroy(force, ...)
	unregister_signals()
	clear_detection_radius()

	return ..()

/datum/human_ai_module/perception/process_module(delta_time)
	if(!can_process_detection())
		clear_detection_radius()
		return

	if(!length(detection_turfs))
		setup_detection_radius()

/datum/human_ai_module/perception/on_ai_event(datum/human_ai_event/event)
	if(event.event_type == HUMAN_AI_EVENT_MOVED)
		on_moved(event.data?["oldloc"], event.data?["direction"], event.data?["forced"])

/datum/human_ai_module/perception/on_moved(atom/oldloc, direction, forced)
	setup_detection_radius()

/datum/human_ai_module/perception/proc/suspend()
	clear_detection_radius()

/datum/human_ai_module/perception/reset_module()
	reset_detection()

/datum/human_ai_module/perception/suspend_module(clear_inventory = FALSE)
	suspend()

/datum/human_ai_module/perception/proc/register_signals()
	if(!brain?.has_valid_tied_human())
		return
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return

	controller.register_signal_for(src, COMSIG_HUMAN_BULLET_ACT, PROC_REF(on_shot))

/datum/human_ai_module/perception/proc/unregister_signals()
	var/datum/human_tied_controller/controller = context?.controller
	if(controller)
		controller.unregister_signal_for(src, COMSIG_HUMAN_BULLET_ACT)

/datum/human_ai_module/perception/proc/setup_detection_radius()
	if(!brain?.has_valid_tied_human())
		clear_detection_radius()
		return

	if(length(detection_turfs))
		clear_detection_radius()
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return

	for(var/turf/open/floor in controller.get_range(1))
		RegisterSignal(floor, COMSIG_TURF_ENTERED, PROC_REF(on_detection_turf_enter))
		detection_turfs += floor

/datum/human_ai_module/perception/proc/clear_detection_radius()
	for(var/turf/open/floor as anything in detection_turfs)
		UnregisterSignal(floor, COMSIG_TURF_ENTERED)

	detection_turfs.Cut()

/datum/human_ai_module/perception/proc/reset_detection()
	clear_detection_radius()
	last_detected_projectile = null
	last_detected_projectile_time = -1
	clear_recent_threat()

/datum/human_ai_module/perception/proc/on_detection_turf_enter(datum/source, atom/movable/entering)
	SIGNAL_HANDLER

	if(!can_process_detection())
		return

	var/datum/human_tied_controller/controller = context?.controller
	if(!controller || controller.is_puppet(entering))
		return

	if(!istype(entering, /obj/projectile))
		return

	var/obj/projectile/bullet = entering
	if(is_projectile_debounced(bullet))
		return

	remember_projectile(bullet)

	if(!bullet.firer)
		return

	remember_projectile_threat(bullet)
	brain.on_projectile_threat(bullet, FALSE, get_recent_threat_source(), get_recent_threat_turf(), get_recent_threat_angle())

/datum/human_ai_module/perception/proc/on_shot(datum/source, damage_result, ammo_flags, obj/projectile/bullet)
	SIGNAL_HANDLER

	if(!can_process_detection())
		return

	if(!bullet || !bullet.firer)
		return

	remember_projectile_threat(bullet)
	brain.on_projectile_threat(bullet, TRUE, get_recent_threat_source(), get_recent_threat_turf(), get_recent_threat_angle())

/datum/human_ai_module/perception/proc/can_process_detection()
	return brain?.can_continue_runtime_work()

/datum/human_ai_module/perception/proc/is_projectile_debounced(obj/projectile/bullet)
	return (last_detected_projectile == bullet) && (last_detected_projectile_time == world.time)

/datum/human_ai_module/perception/proc/remember_projectile(obj/projectile/bullet)
	last_detected_projectile = bullet
	last_detected_projectile_time = world.time

/datum/human_ai_module/perception/proc/remember_projectile_threat(obj/projectile/bullet, duration = 4 SECONDS)
	if(!bullet?.firer)
		return FALSE
	var/atom/movable/firer = bullet.firer
	if(!can_remember_threat_source(firer))
		return FALSE
	var/turf/firer_turf = get_turf(firer)
	if(!firer_turf)
		return FALSE

	recent_threat_source = firer
	recent_threat_turf = firer_turf
	recent_threat_angle = bullet.angle
	COOLDOWN_START(src, threat_memory, duration)
	return TRUE

/datum/human_ai_module/perception/proc/clear_recent_threat()
	recent_threat_source = null
	recent_threat_turf = null
	recent_threat_angle = null

/datum/human_ai_module/perception/proc/has_recent_threat()
	return recent_threat_turf && !COOLDOWN_FINISHED(src, threat_memory)

/datum/human_ai_module/perception/proc/get_recent_threat_turf()
	RETURN_TYPE(/turf)
	if(!has_recent_threat())
		return null
	return recent_threat_turf

/datum/human_ai_module/perception/proc/get_recent_threat_source()
	RETURN_TYPE(/atom/movable)
	if(!has_recent_threat())
		return null
	return recent_threat_source

/datum/human_ai_module/perception/proc/get_recent_threat_angle()
	if(!has_recent_threat())
		return null
	return recent_threat_angle

/datum/human_ai_module/perception/proc/clear_projectile_threat()
	clear_recent_threat()

/datum/human_ai_module/perception/proc/has_recent_projectile_threat()
	return has_recent_threat()

/datum/human_ai_module/perception/proc/get_recent_projectile_threat_turf()
	RETURN_TYPE(/turf)
	return get_recent_threat_turf()

/datum/human_ai_module/perception/proc/get_recent_projectile_threat_source()
	RETURN_TYPE(/atom/movable)
	return get_recent_threat_source()

/datum/human_ai_module/perception/proc/get_recent_projectile_threat_angle()
	return get_recent_threat_angle()

/datum/human_ai_module/perception/proc/can_remember_projectile_threat_source(atom/movable/source)
	return can_remember_threat_source(source)

/datum/human_ai_module/perception/proc/can_remember_threat_source(atom/movable/source)
	if(!has_valid_owner())
		return FALSE
	if(!is_valid_target_ref(source))
		return FALSE
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller || controller.is_puppet(source))
		return FALSE
	return TRUE

/datum/human_ai_module/perception/proc/get_visible_target_candidates()
	if(!has_valid_owner())
		return list()
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return list()

	var/list/viable_targets = list()
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

	return viable_targets

/datum/human_ai_module/perception/proc/can_acquire_from_direction(atom/movable/target, distance, list/dir_cone, rear_view_penalty)
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

/datum/human_ai_module/perception/proc/can_target(atom/movable/target)
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

/datum/human_ai_module/perception/proc/can_target_defense(obj/structure/machinery/defenses/defense)
	if(!istype(defense))
		return FALSE

	if(defense.stat & DEFENSE_DESTROYED)
		return FALSE

	if(brain.is_friendly_target(defense))
		return FALSE

	return path_check(defense)

/datum/human_ai_module/perception/proc/can_target_vehicle(obj/vehicle/multitile/vehicle)
	if(!istype(vehicle))
		return FALSE

	if(vehicle.health <= 0)
		return FALSE

	if(brain.is_friendly_target(vehicle))
		return FALSE

	return path_check(vehicle)

/datum/human_ai_module/perception/proc/can_target_mob(mob/living/target)
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

	if(HAS_TRAIT(target, TRAIT_CLOAKED) && controller.get_distance_to(target) > get_cloak_visible_range())
		return FALSE

	if(!path_check(target))
		return FALSE

	return TRUE

/datum/human_ai_module/perception/proc/can_detect_living_target(mob/living/target)
	for(var/turf/tile in range(1, target))
		if(tile.luminosity || (tile.dynamic_lumcount >= 1))
			return TRUE

	return FALSE

/datum/human_ai_module/perception/proc/path_check(atom/movable/target)
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
	for(var/turf/tile in turf_list)
		if(tile.density)
			return FALSE
		for(var/atom/movable/obstacle in tile)
			if(obstacle.density && obstacle != target && !controller.is_puppet(obstacle) && !istype(obstacle, /mob))
				if(istype(obstacle, /obj/structure/window) || istype(obstacle, /obj/structure/grille) || istype(obstacle, /obj/structure/barricade))
					continue
				return FALSE

	turf_list.Cut(1, 2)
	var/list/checked_turfs = list()
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

/datum/human_ai_module/perception/proc/get_cloak_visible_range()
	return 3

/datum/human_ai_module/perception/proc/has_valid_owner()
	return brain && brain.has_valid_tied_human()

/datum/human_ai_module/perception/proc/is_valid_target_ref(atom/movable/target)
	return target && !QDELETED(target)
