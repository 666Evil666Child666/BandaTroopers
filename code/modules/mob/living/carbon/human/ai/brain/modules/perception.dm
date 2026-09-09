/datum/human_ai_module/perception
	module_id = "perception"
	required_module_types = list(/datum/human_ai_module/combat)

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

	brain.on_projectile_threat(bullet)

/datum/human_ai_module/perception/proc/on_shot(datum/source, damage_result, ammo_flags, obj/projectile/bullet)
	SIGNAL_HANDLER

	if(!can_process_detection())
		return

	if(!bullet || !bullet.firer)
		return

	brain.on_projectile_threat(bullet, TRUE)

/datum/human_ai_module/perception/proc/can_process_detection()
	return brain?.can_continue_runtime_work()

/datum/human_ai_module/perception/proc/is_projectile_debounced(obj/projectile/bullet)
	return (last_detected_projectile == bullet) && (last_detected_projectile_time == world.time)

/datum/human_ai_module/perception/proc/remember_projectile(obj/projectile/bullet)
	last_detected_projectile = bullet
	last_detected_projectile_time = world.time
