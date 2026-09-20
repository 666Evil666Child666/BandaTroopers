#define FRIENDLY_FIRE_ADJACENT_CHECK_START_INDEX 4

/datum/ai_action/fire_at_target
	name = "Fire At Target"
	action_flags = ACTION_USING_HANDS
	required_ai_modules = list(/datum/human_ai_module/combat, /datum/human_ai_module/guns, /datum/human_ai_module/inventory)
	var/rounds_burst_fired = 0
	var/currently_firing
	var/list/watched_turfs = list()
	var/atom/watched_fire_target

/datum/ai_action/fire_at_target/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return 0

	var/obj/item/weapon/gun/primary_weapon = brain.get_primary_weapon()
	var/datum/human_ai_firearm_profile/gun_data = brain.get_gun_data()
	if(!brain.can_attempt_ranged_fire(controller, primary_weapon, gun_data))
		return 0

	var/turf/target_turf = brain.get_ranged_fire_target_turf(gun_data)
	if(!firing_line_check(context, target_turf, gun_data))
		return 0

	var/datum/human_ai_firearm_context/firearm_context = new(primary_weapon, brain, brain.get_current_target(), target_turf)
	var/datum/human_ai_firearm_handler/handler = firearm_context.get_handler()
	var/can_queue_fire = handler?.can_queue_fire(firearm_context)
	qdel(firearm_context)
	if(!can_queue_fire)
		return 0

	return 10

/datum/ai_action/fire_at_target/Destroy(force, ...)
	stop_firing()
	return ..()

/datum/ai_action/fire_at_target/proc/stop_firing()
	currently_firing = FALSE
	rounds_burst_fired = 0
	clear_watched_turfs()

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain)
		return

	if(controller && brain.has_valid_tied_human())
		controller.unregister_signal_for(src, COMSIG_MOB_FIRED_GUN)
	brain.get_primary_weapon()?.set_target(null)

/datum/ai_action/fire_at_target/proc/clear_watched_turfs()
	if(!length(watched_turfs))
		watched_fire_target = null
		return
	for(var/turf/T as anything in watched_turfs)
		UnregisterSignal(T, COMSIG_TURF_ENTERED)
	watched_turfs.Cut()
	watched_fire_target = null

/datum/ai_action/fire_at_target/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return ONGOING_ACTION_COMPLETED

	var/obj/item/weapon/gun/primary_weapon = brain.get_primary_weapon()
	var/datum/human_ai_firearm_profile/gun_data = brain.get_gun_data()
	if(!brain.can_attempt_ranged_fire(controller, primary_weapon, gun_data, require_combat = FALSE, block_active_grenade = TRUE, check_view_distance = FALSE, check_reload = FALSE, check_tried_reload = FALSE))
		return ONGOING_ACTION_COMPLETED

	var/turf/target_turf = brain.get_ranged_fire_target_turf(gun_data)
	var/atom/aim_target = brain.get_ranged_fire_aim_target(controller, brain.get_current_target(), target_turf, gun_data)
	if(!aim_target)
		return ONGOING_ACTION_COMPLETED
	var/turf/aim_turf = get_turf(aim_target)
	var/should_fire_offscreen = brain.can_fire_offscreen(target_turf)
	if(currently_firing || !brain.can_continue_fire_burst())
		return ONGOING_ACTION_UNFINISHED

	brain.unholster_primary()

	var/datum/human_ai_firearm_context/firearm_context = new(primary_weapon, brain, brain.get_current_target(), aim_turf)
	var/datum/human_ai_firearm_handler/handler = firearm_context.get_handler()
	if(!handler?.before_fire(firearm_context))
		qdel(firearm_context)
		return ONGOING_ACTION_COMPLETED
	if(brain.should_reload())
		qdel(firearm_context)
		if(gun_data?.disposable)
			controller.drop_held_item(primary_weapon)
			brain.set_primary_weapon(null)
		return ONGOING_ACTION_COMPLETED

	if(!brain.can_reach_ranged_fire_atom(controller, aim_target, gun_data.maximum_range) && !should_fire_offscreen)
		qdel(firearm_context)
		return ONGOING_ACTION_COMPLETED

	if(!firing_line_check(context, aim_target, gun_data))
		qdel(firearm_context)
		return ONGOING_ACTION_COMPLETED

	controller.face_atom(aim_target)
	controller.set_combat_intent()

	controller.register_signal_for(src, COMSIG_MOB_FIRED_GUN, PROC_REF(on_gun_fire), TRUE)

	// Handling point-blank through attack()
	var/atom/movable/current_target = brain.get_current_target()
	if(current_target && (controller.get_distance_to(current_target) <= 1))
		currently_firing = FALSE
		primary_weapon.set_target(null)
		qdel(firearm_context)
		INVOKE_ASYNC(controller, TYPE_PROC_REF(/datum/human_tied_controller, do_click), current_target, "", list())
		return ONGOING_ACTION_UNFINISHED

	if(!handler.fire(firearm_context))
		qdel(firearm_context)
		return ONGOING_ACTION_COMPLETED
	var/keep_fire_action_active = handler.keeps_fire_action_active(firearm_context)
	qdel(firearm_context)
	if(!keep_fire_action_active)
		return ONGOING_ACTION_COMPLETED
	return ONGOING_ACTION_UNFINISHED

/datum/ai_action/fire_at_target/proc/firing_line_check(datum/human_ai_context/context, atom/target, datum/human_ai_firearm_profile/gun_data = null, listen = FALSE)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain?.can_continue_runtime_work() || !controller) // SS220 EDIT: avoid post-lifecycle signal work from upstream firing callbacks
		return FALSE
	var/list/turf_list = controller.get_line_from_current_turf_to(target)
	for(var/turf/tile in turf_list)
		var/tile_dist = controller.get_distance_to(tile)
		if(tile_dist > brain.get_view_distance())
			continue

		if(tile.density)
			return FALSE

		for(var/obj/thing in tile)
			if(!thing.unacidable || !thing.density)
				continue

			if((tile_dist <= 3) && (thing.projectile_coverage >= PROJECTILE_COVERAGE_HIGH)) // short range we allow for higher projectile coverage to be shot over
				return FALSE
			else if((tile_dist > 3) && thing.projectile_coverage >= PROJECTILE_COVERAGE_MEDIUM)
				return FALSE

	if(brain.get_fire_line_safety(target, gun_data) == HUMAN_AI_FIRE_LINE_BLOCKED)
		return FALSE

	if(listen)
		clear_watched_turfs()
		watched_fire_target = target

	var/list/checked_turfs = list()
	for(var/i in 2 to length(turf_list))
		var/turf/tile = turf_list[i]
		var/tile_dist = controller.get_distance_to(tile)
		if(tile_dist > brain.get_view_distance())
			continue

		var/list/turfs_to_check = list(tile)
		if(i > FRIENDLY_FIRE_ADJACENT_CHECK_START_INDEX)
			for(var/turf/neighbor in tile.AdjacentTurfs())
				turfs_to_check += neighbor

		for(var/turf/T as anything in turfs_to_check)
			if(checked_turfs[T])
				continue
			checked_turfs[T] = TRUE

			if(listen)
				RegisterSignal(T, COMSIG_TURF_ENTERED, PROC_REF(cheap_friendly_check))
				watched_turfs += T

	return TRUE

/datum/ai_action/fire_at_target/proc/cheap_friendly_check(datum/source, atom/movable/entering)
	SIGNAL_HANDLER
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain?.can_continue_runtime_work() || !controller)
		return
	if(controller.is_puppet(entering))
		return

	if(!istype(entering, /mob/living))
		return

	var/mob/living/possible_friendly = entering
	if(!brain.is_friendly_target(possible_friendly))
		return

	if(brain.get_fire_line_safety(watched_fire_target || brain.get_aim_target(), brain.get_gun_data()) == HUMAN_AI_FIRE_LINE_BLOCKED)
		stop_firing()
		qdel(src)

/datum/ai_action/fire_at_target/proc/on_gun_fire(datum/source, obj/item/weapon/gun/fired)
	SIGNAL_HANDLER

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain?.can_continue_runtime_work() || !controller) // SS220 EDIT: late gun callbacks can outlive active AI control for a tick
		qdel(src)
		return

	var/turf/target_turf = brain.get_target_turf()

	controller.set_combat_intent()

	brain.set_shot_at_turf(target_turf)
	controller.face_atom(target_turf)

	currently_firing = TRUE

	var/datum/human_ai_firearm_profile/gun_data = brain.get_gun_data()
	if(brain.should_reload()) // note that bullet removal comes after comsig is triggered
		if(gun_data?.disposable)
			var/obj/item/weapon/gun/current_primary_weapon = brain.get_primary_weapon()
			if(current_primary_weapon)
				controller.drop_held_item(current_primary_weapon)
			brain.set_primary_weapon(null)
		stop_firing()
		qdel(src)
		return

	var/should_fire_offscreen = brain.can_fire_offscreen(target_turf)
	var/atom/movable/current_target = brain.get_current_target()
	var/shoot_next = current_target

	if(QDELETED(current_target))
		if(!should_fire_offscreen)
			stop_firing()
			qdel(src)
			return
		shoot_next = target_turf

	else if(ismob(current_target))
		var/mob/mob_target = current_target
		if(mob_target.stat == DEAD)
			stop_firing()
			brain.lose_target()
			qdel(src)
			return

		var/is_unconscious = (mob_target.stat == UNCONSCIOUS || (locate(/datum/effects/crit) in mob_target.effects_list))
		if(!brain.should_shoot_to_kill() && is_unconscious)
			brain.lose_target()
			qdel(src)
			return

	if(brain.should_defer_ranged_fire_target(shoot_next))
		stop_firing()
		qdel(src)
		return

	var/obj/item/weapon/gun/primary_weapon = brain.get_primary_weapon()
	var/count_shot_against_burst_limit = ((primary_weapon.gun_firemode == GUN_FIREMODE_AUTOMATIC) || gun_data.count_every_shot_toward_burst_limit)
	if(count_shot_against_burst_limit)
		rounds_burst_fired++

	if(rounds_burst_fired >= gun_data.burst_amount_max)
		brain.start_fire_overload_cooldown()
		stop_firing()
		return

	current_target = brain.get_current_target()
	if(current_target && (controller.get_distance_to(current_target) <= 1))
		currently_firing = FALSE
		return

	shoot_next = brain.get_ranged_fire_aim_target(controller, current_target, target_turf, gun_data)
	if(!shoot_next)
		stop_firing()
		qdel(src)
		return

	if(!brain.can_reach_ranged_fire_atom(controller, shoot_next, gun_data.maximum_range) && !should_fire_offscreen)
		brain.lose_target()
		stop_firing()
		qdel(src)
		return

	if(!firing_line_check(context, shoot_next, gun_data, listen = TRUE))
		stop_firing()
		qdel(src)
		return

	var/turf/shoot_turf = get_turf(shoot_next)

	var/datum/human_ai_firearm_context/firearm_context = new(primary_weapon, brain, current_target, shoot_turf)
	var/datum/human_ai_firearm_handler/handler = firearm_context.get_handler()
	var/datum/human_ai_firearm_result/after_fire_result = handler?.after_fire(firearm_context)
	qdel(firearm_context)
	if(after_fire_result)
		if(after_fire_result.callback)
			addtimer(after_fire_result.callback, after_fire_result.callback_delay)
		if(after_fire_result.cooldown)
			brain.start_stop_fire_cooldown(after_fire_result.cooldown)
		if(after_fire_result.interrupt_burst)
			rounds_burst_fired = 0
		if(after_fire_result.stop_fire)
			currently_firing = FALSE
			stop_firing()
		if(after_fire_result.handled)
			return

	if(primary_weapon.gun_firemode == GUN_FIREMODE_SEMIAUTO)
		currently_firing = FALSE
		addtimer(CALLBACK(src, PROC_REF(delayed_start_fire), primary_weapon, shoot_next), primary_weapon.get_fire_delay())

	else if(primary_weapon.gun_firemode == GUN_FIREMODE_BURSTFIRE)
		currently_firing = FALSE
		addtimer(CALLBACK(src, PROC_REF(delayed_start_fire), primary_weapon, shoot_next), primary_weapon.get_burst_fire_delay())

	primary_weapon?.set_target(shoot_next)

/datum/ai_action/fire_at_target/proc/delayed_start_fire(obj/item/weapon/gun/primary_weapon, atom/current_target)
	if(!context?.can_continue() || QDELETED(primary_weapon))
		return FALSE
	primary_weapon.start_fire(null, current_target, null, null, null, TRUE)
	return TRUE

#undef FRIENDLY_FIRE_ADJACENT_CHECK_START_INDEX
