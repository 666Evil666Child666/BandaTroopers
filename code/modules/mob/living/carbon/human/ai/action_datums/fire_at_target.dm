#define FRIENDLY_FIRE_ADJACENT_CHECK_START_INDEX 4

/datum/ai_action/fire_at_target
	name = "Fire At Target"
	action_flags = ACTION_USING_HANDS
	var/rounds_burst_fired = 0
	var/currently_firing
	var/list/watched_turfs = list()

/datum/ai_action/fire_at_target/get_weight(datum/human_ai_brain/brain)
	if(!brain.has_valid_tied_human()) // SS220 EDIT: upstream action glue must not schedule work for detached modular AI owners
		return 0

	if(!brain.combat.in_combat)
		return 0

	if(brain.guns.has_tried_reload())
		return 0

	var/obj/item/weapon/gun/primary_weapon = brain.inventory.get_primary_weapon()
	if(!primary_weapon)
		return 0

	if(!COOLDOWN_FINISHED(brain.guns, stop_fire_cooldown))
		return 0

	var/turf/target_turf = brain.targeting.get_target_turf()
	var/datum/human_ai_firearm_profile/gun_data = brain.inventory.get_gun_data()
	var/should_fire_offscreen = (target_turf && !COOLDOWN_FINISHED(brain, targeting.fire_offscreen) && (gun_data.maximum_range > brain.profile.view_distance))

	if(!brain.targeting.has_current_target() && !should_fire_offscreen)
		return 0

	if((brain.tied_controller.get_distance_to(target_turf) > brain.profile.view_distance) && !should_fire_offscreen)
		return 0

	if(brain.halo_should_defer_ranged_fire(brain.targeting.get_aim_target()))
		return 0

	if(!firing_line_check(brain, target_turf))
		return 0

	if(brain.guns.should_reload())
		return 0

	var/datum/human_ai_firearm_context/context = new(primary_weapon, brain, brain.targeting.get_current_target(), target_turf)
	var/datum/human_ai_firearm_handler/handler = context.get_handler()
	var/can_queue_fire = handler?.can_queue_fire(context)
	qdel(context)
	if(!can_queue_fire)
		return 0

	return 10

/datum/ai_action/fire_at_target/Destroy(force, ...)
	stop_firing(brain)
	return ..()

/datum/ai_action/fire_at_target/proc/stop_firing(datum/human_ai_brain/brain)
	currently_firing = FALSE
	rounds_burst_fired = 0
	clear_watched_turfs()

	if(!brain)
		return

	if(brain.has_valid_tied_human())
		brain.tied_controller.unregister_signal_for(src, COMSIG_MOB_FIRED_GUN)
	brain.inventory.get_primary_weapon()?.set_target(null)

/datum/ai_action/fire_at_target/proc/clear_watched_turfs()
	if(!length(watched_turfs))
		return
	for(var/turf/T as anything in watched_turfs)
		UnregisterSignal(T, COMSIG_TURF_ENTERED)
	watched_turfs.Cut()

/datum/ai_action/fire_at_target/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/obj/item/weapon/gun/primary_weapon = brain.inventory.get_primary_weapon()
	if(!primary_weapon || brain.grenade.has_active_grenade() || !COOLDOWN_FINISHED(brain.guns, stop_fire_cooldown))
		return ONGOING_ACTION_COMPLETED

	var/turf/target_turf = brain.targeting.get_target_turf()
	var/should_fire_offscreen = (target_turf && !COOLDOWN_FINISHED(brain, targeting.fire_offscreen))
	if(!brain.targeting.has_current_target() && !should_fire_offscreen)
		return ONGOING_ACTION_COMPLETED

	if(brain.halo_should_defer_ranged_fire(brain.targeting.get_aim_target()))
		return ONGOING_ACTION_COMPLETED

	if(currently_firing || !COOLDOWN_FINISHED(brain.guns, fire_overload_cooldown))
		return ONGOING_ACTION_UNFINISHED

	brain.inventory.unholster_primary()

	var/datum/human_ai_firearm_profile/gun_data = brain.inventory.get_gun_data()
	var/datum/human_ai_firearm_context/context = new(primary_weapon, brain, brain.targeting.get_current_target(), target_turf)
	var/datum/human_ai_firearm_handler/handler = context.get_handler()
	if(!handler?.before_fire(context))
		qdel(context)
		return ONGOING_ACTION_COMPLETED
	if(brain.guns.should_reload())
		qdel(context)
		if(gun_data?.disposable)
			brain.tied_controller.drop_held_item(primary_weapon)
			brain.inventory.set_primary_weapon(null)
		return ONGOING_ACTION_COMPLETED

	if((brain.tied_controller.get_distance_to(target_turf) > gun_data.maximum_range) && !should_fire_offscreen)
		qdel(context)
		return ONGOING_ACTION_COMPLETED

	if(!firing_line_check(brain, target_turf))
		qdel(context)
		return ONGOING_ACTION_COMPLETED

	brain.tied_controller.face_atom(target_turf)
	brain.tied_controller.set_combat_intent()

	brain.tied_controller.register_signal_for(src, COMSIG_MOB_FIRED_GUN, PROC_REF(on_gun_fire), TRUE)

	// Handling point-blank through attack()
	var/atom/movable/current_target = brain.targeting.get_current_target()
	if(current_target && (brain.tied_controller.get_distance_to(current_target) <= 1))
		currently_firing = FALSE
		primary_weapon.set_target(null)
		qdel(context)
		INVOKE_ASYNC(brain.tied_controller, TYPE_PROC_REF(/datum/human_tied_controller, do_click), current_target, "", list())
		return ONGOING_ACTION_UNFINISHED

	if(!handler.fire(context))
		qdel(context)
		return ONGOING_ACTION_COMPLETED
	var/keep_fire_action_active = handler.keeps_fire_action_active(context)
	qdel(context)
	if(!keep_fire_action_active)
		return ONGOING_ACTION_COMPLETED
	return ONGOING_ACTION_UNFINISHED

/datum/ai_action/fire_at_target/proc/firing_line_check(datum/human_ai_brain/brain, atom/target, listen = FALSE)
	if(!brain?.can_continue_runtime_work()) // SS220 EDIT: avoid post-lifecycle signal work from upstream firing callbacks
		return FALSE
	var/list/turf_list = brain.tied_controller.get_line_from_current_turf_to(target)
	for(var/turf/tile in turf_list)
		var/tile_dist = brain.tied_controller.get_distance_to(tile)
		if(tile_dist > brain.profile.view_distance)
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

	if(listen)
		clear_watched_turfs()

	var/list/checked_turfs = list()
	for(var/i in 2 to length(turf_list))
		var/turf/tile = turf_list[i]
		var/tile_dist = brain.tied_controller.get_distance_to(tile)
		if(tile_dist > brain.profile.view_distance)
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

			for(var/mob/living/possible_friendly in T)
				if(brain.tied_controller.is_puppet(possible_friendly))
					continue

				if(possible_friendly.body_position == LYING_DOWN)
					continue

				if(brain.faction.faction_check(possible_friendly))
					return FALSE

	return TRUE

/datum/ai_action/fire_at_target/proc/cheap_friendly_check(datum/source, atom/movable/entering)
	SIGNAL_HANDLER
	if(!brain?.can_continue_runtime_work())
		return
	if(brain.tied_controller.is_puppet(entering))
		return

	if(!istype(entering, /mob/living))
		return

	var/mob/living/H = entering
	if(H.body_position == LYING_DOWN)
		return

	if(brain.faction.faction_check(H))
		stop_firing(brain)
		qdel(src)

/datum/ai_action/fire_at_target/proc/on_gun_fire(datum/source, obj/item/weapon/gun/fired)
	SIGNAL_HANDLER

	if(!brain?.can_continue_runtime_work()) // SS220 EDIT: late gun callbacks can outlive active AI control for a tick
		qdel(src)
		return

	var/turf/target_turf = brain.targeting.get_target_turf()

	brain.tied_controller.set_combat_intent()

	brain.combat.shot_at = get_turf(target_turf)
	brain.tied_controller.face_atom(target_turf)

	currently_firing = TRUE

	var/datum/human_ai_firearm_profile/gun_data = brain.inventory.get_gun_data()
	if(brain.guns.should_reload()) // note that bullet removal comes after comsig is triggered
		if(gun_data?.disposable)
			brain.tied_controller.drop_held_item(brain.inventory.get_primary_weapon())
			brain.inventory.set_primary_weapon(null)
		stop_firing(brain)
		qdel(src)
		return

	var/should_fire_offscreen = (target_turf && !COOLDOWN_FINISHED(brain, targeting.fire_offscreen))
	var/atom/movable/current_target = brain.targeting.get_current_target()
	var/shoot_next = current_target

	if(QDELETED(current_target))
		if(!should_fire_offscreen)
			stop_firing(brain)
			qdel(src)
			return
		shoot_next = target_turf

	else if(ismob(current_target))
		var/mob/mob_target = current_target
		if(mob_target.stat == DEAD)
			stop_firing(brain)
			brain.targeting.lose_target()
			qdel(src)
			return

		var/is_unconscious = (mob_target.stat == UNCONSCIOUS || (locate(/datum/effects/crit) in mob_target.effects_list))
		if(!brain.profile.shoot_to_kill && is_unconscious)
			brain.targeting.lose_target()
			qdel(src)
			return

	if(brain.halo_should_defer_ranged_fire(shoot_next))
		stop_firing(brain)
		qdel(src)
		return

	var/obj/item/weapon/gun/primary_weapon = brain.inventory.get_primary_weapon()
	var/count_shot_against_burst_limit = ((primary_weapon.gun_firemode == GUN_FIREMODE_AUTOMATIC) || gun_data.count_every_shot_toward_burst_limit)
	if(count_shot_against_burst_limit)
		rounds_burst_fired++

	if(rounds_burst_fired >= gun_data.burst_amount_max)
		var/short_action_delay = brain.profile.short_action_delay
		COOLDOWN_START(brain.guns, fire_overload_cooldown, max(short_action_delay, short_action_delay * brain.profile.action_delay_mult))
		stop_firing(brain)
		return

	if((brain.tied_controller.get_distance_to(shoot_next) > gun_data.maximum_range) && !should_fire_offscreen)
		brain.targeting.lose_target()
		stop_firing(brain)
		qdel(src)
		return

	current_target = brain.targeting.get_current_target()
	if(current_target && (brain.tied_controller.get_distance_to(current_target) <= 1))
		currently_firing = FALSE
		return

	if(!firing_line_check(brain, shoot_next, listen = TRUE))
		stop_firing(brain)
		qdel(src)
		return

	var/datum/human_ai_firearm_context/context = new(primary_weapon, brain, current_target, target_turf)
	var/datum/human_ai_firearm_handler/handler = context.get_handler()
	var/datum/human_ai_firearm_result/after_fire_result = handler?.after_fire(context)
	qdel(context)
	if(after_fire_result)
		if(after_fire_result.callback)
			addtimer(after_fire_result.callback, after_fire_result.callback_delay)
		if(after_fire_result.cooldown)
			COOLDOWN_START(brain.guns, stop_fire_cooldown, after_fire_result.cooldown)
		if(after_fire_result.interrupt_burst)
			rounds_burst_fired = 0
		if(after_fire_result.stop_fire)
			currently_firing = FALSE
			stop_firing(brain)
		if(after_fire_result.handled)
			return

	if(primary_weapon.gun_firemode == GUN_FIREMODE_SEMIAUTO)
		currently_firing = FALSE
		addtimer(CALLBACK(src, PROC_REF(delayed_start_fire), primary_weapon, current_target), primary_weapon.get_fire_delay())

	else if(primary_weapon.gun_firemode == GUN_FIREMODE_BURSTFIRE)
		currently_firing = FALSE
		addtimer(CALLBACK(src, PROC_REF(delayed_start_fire), primary_weapon, current_target), primary_weapon.get_burst_fire_delay())

	primary_weapon?.set_target(shoot_next)

/datum/ai_action/fire_at_target/proc/delayed_start_fire(obj/item/weapon/gun/primary_weapon, atom/movable/current_target)
	if(!brain?.can_continue_runtime_work() || QDELETED(primary_weapon))
		return FALSE
	primary_weapon.start_fire(null, current_target, null, null, null, TRUE)
	return TRUE

#undef FRIENDLY_FIRE_ADJACENT_CHECK_START_INDEX
