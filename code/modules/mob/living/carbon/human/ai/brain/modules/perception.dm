/datum/human_ai_module/perception
	/// Nearby turfs that we're watching for bullets
	var/list/detection_turfs = list()
	/// Prevent repeated projectile detection re-entry in the same tick
	var/atom/movable/last_detected_projectile
	var/last_detected_projectile_time = -1

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

/datum/human_ai_module/perception/proc/suspend()
	clear_detection_radius()

/datum/human_ai_module/perception/proc/register_signals()
	if(!brain?.has_valid_tied_human())
		return

	RegisterSignal(brain.tied_human, COMSIG_HUMAN_BULLET_ACT, PROC_REF(on_shot))

/datum/human_ai_module/perception/proc/unregister_signals()
	if(brain?.tied_human)
		UnregisterSignal(brain.tied_human, COMSIG_HUMAN_BULLET_ACT)

/datum/human_ai_module/perception/proc/setup_detection_radius()
	if(!brain?.has_valid_tied_human())
		clear_detection_radius()
		return

	if(length(detection_turfs))
		clear_detection_radius()

	for(var/turf/open/floor in range(1, brain.tied_human))
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

/datum/human_ai_module/perception/proc/on_detection_turf_enter(datum/source, atom/movable/entering)
	SIGNAL_HANDLER

	if(!can_process_detection())
		return

	if(entering == brain.tied_human)
		return

	if(!istype(entering, /obj/projectile))
		return

	var/obj/projectile/bullet = entering
	if(is_projectile_debounced(bullet))
		return

	remember_projectile(bullet)

	if(!bullet.firer)
		return

	handle_projectile_threat(bullet)

/datum/human_ai_module/perception/proc/on_shot(datum/source, damage_result, ammo_flags, obj/projectile/bullet)
	SIGNAL_HANDLER

	if(!can_process_detection())
		return

	if(!bullet || !bullet.firer)
		return

	handle_projectile_threat(bullet)
	brain.cover.react_to_incoming_fire(bullet.angle, bullet.firer)

/datum/human_ai_module/perception/proc/handle_projectile_threat(obj/projectile/bullet)
	var/atom/firer = bullet.firer
	if(!firer)
		return

	brain.combat.enter_combat()
	brain.faction.react_to_attacker_faction(firer)

	if(brain.faction.faction_check(firer))
		return

	if(get_dist(brain.tied_human, firer) <= brain.profile.view_distance)
		brain.targeting.set_target(firer)
	else
		brain.targeting.set_target_turf(get_turf(firer), 4 SECONDS)

/datum/human_ai_module/perception/proc/can_process_detection()
	return brain?.has_valid_tied_human() && !brain.tied_human.client

/datum/human_ai_module/perception/proc/is_projectile_debounced(obj/projectile/bullet)
	return (last_detected_projectile == bullet) && (last_detected_projectile_time == world.time)

/datum/human_ai_module/perception/proc/remember_projectile(obj/projectile/bullet)
	last_detected_projectile = bullet
	last_detected_projectile_time = world.time
