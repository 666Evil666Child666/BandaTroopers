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

	if(brain.guns.tried_reload)
		return 0

	if(!brain.inventory.primary_weapon)
		return 0

	if(!COOLDOWN_FINISHED(brain.guns, stop_fire_cooldown))
		return 0

	var/should_fire_offscreen = (brain.targeting.target_turf && !COOLDOWN_FINISHED(brain, targeting.fire_offscreen) && (brain.inventory.gun_data.maximum_range > brain.profile.view_distance))

	if(!brain.targeting.current_target && !should_fire_offscreen)
		return 0

	if((get_dist(brain.tied_human, brain.targeting.target_turf) > brain.profile.view_distance) && !should_fire_offscreen)
		return 0

	if(brain.halo_should_defer_ranged_fire(brain.targeting.current_target || brain.targeting.target_turf))
		return 0

	if(!firing_line_check(brain, brain.targeting.target_turf))
		return 0

	if(brain.guns.should_reload())
		return 0

	// SS220 EDIT - START: HALO plasma weapons should not queue fire actions while their vent cycle is still active
	if(istype(brain.inventory.primary_weapon, /obj/item/weapon/gun/energy/plasma))
		var/obj/item/weapon/gun/energy/plasma/plasma_weapon = brain.inventory.primary_weapon
		if(plasma_weapon.dispersing)
			return 0
	// SS220 EDIT - END

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
		UnregisterSignal(brain.tied_human, COMSIG_MOB_FIRED_GUN)
	brain.inventory.primary_weapon?.set_target(null)

/datum/ai_action/fire_at_target/proc/clear_watched_turfs()
	if(!length(watched_turfs))
		return
	for(var/turf/T as anything in watched_turfs)
		UnregisterSignal(T, COMSIG_TURF_ENTERED)
	watched_turfs.Cut()

/datum/ai_action/fire_at_target/trigger_action()
	. = ..()
	if(!brain || !brain.has_valid_tied_human()) // SS220 EDIT: firing action exits cleanly if the modular AI owner disappears mid-combat
		return ONGOING_ACTION_COMPLETED

	var/obj/item/weapon/gun/primary_weapon = brain.inventory.primary_weapon
	if(!primary_weapon || brain.grenade.active_grenade_found || !COOLDOWN_FINISHED(brain.guns, stop_fire_cooldown))
		return ONGOING_ACTION_COMPLETED

	var/should_fire_offscreen = (brain.targeting.target_turf && !COOLDOWN_FINISHED(brain, targeting.fire_offscreen))
	if(!brain.targeting.current_target && !should_fire_offscreen)
		return ONGOING_ACTION_COMPLETED

	if(brain.halo_should_defer_ranged_fire(brain.targeting.current_target || brain.targeting.target_turf))
		return ONGOING_ACTION_COMPLETED

	if(currently_firing || !COOLDOWN_FINISHED(brain.guns, fire_overload_cooldown))
		return ONGOING_ACTION_UNFINISHED

	var/mob/living/carbon/tied_human = brain.tied_human
	brain.inventory.unholster_primary()

	var/datum/firearm_appraisal/gun_data = brain.inventory.gun_data
	gun_data.before_fire(primary_weapon, tied_human, brain)
	if(brain.guns.should_reload())
		if(gun_data?.disposable)
			tied_human.drop_held_item(primary_weapon)
			brain.inventory.set_primary_weapon(null)
		return ONGOING_ACTION_COMPLETED

	var/turf/target_turf = brain.targeting.target_turf
	if((get_dist(tied_human, target_turf) > gun_data.maximum_range) && !should_fire_offscreen)
		return ONGOING_ACTION_COMPLETED

	if(!firing_line_check(brain, target_turf))
		return ONGOING_ACTION_COMPLETED

	tied_human.face_atom(target_turf)
	tied_human.a_intent_change(INTENT_HARM)

	RegisterSignal(tied_human, COMSIG_MOB_FIRED_GUN, PROC_REF(on_gun_fire), TRUE)

	// Handling point-blank through attack()
	var/atom/movable/current_target = brain.targeting.current_target
	if(current_target && (get_dist(tied_human, current_target) <= 1))
		currently_firing = FALSE
		primary_weapon.set_target(null)
		INVOKE_ASYNC(tied_human, TYPE_PROC_REF(/mob, do_click), current_target, "", list())
		return ONGOING_ACTION_UNFINISHED

	primary_weapon?.set_target(target_turf)
	primary_weapon?.start_fire(object = target_turf, bypass_checks = TRUE)
	return ONGOING_ACTION_UNFINISHED

/datum/ai_action/fire_at_target/proc/firing_line_check(datum/human_ai_brain/brain, atom/target, listen = FALSE)
	if(!brain.has_valid_tied_human()) // SS220 EDIT: avoid post-delete signal work from upstream firing callbacks
		return FALSE
	var/mob/living/carbon/tied_human = brain.tied_human
	var/list/turf_list = get_line(get_turf(tied_human), get_turf(target))
	for(var/turf/tile in turf_list)
		var/tile_dist = get_dist(tied_human, tile)
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
		var/tile_dist = get_dist(tied_human, tile)
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
				if(possible_friendly == tied_human)
					continue

				if(possible_friendly.body_position == LYING_DOWN)
					continue

				if(brain.faction.faction_check(possible_friendly))
					return FALSE

	return TRUE

/datum/ai_action/fire_at_target/proc/cheap_friendly_check(datum/source, atom/movable/entering)
	SIGNAL_HANDLER
	if(!brain)
		return
	if(entering == brain.tied_human)
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

	if(!brain || !brain.has_valid_tied_human()) // SS220 EDIT: late gun callbacks can outlive the modular AI owner for a tick
		qdel(src)
		return

	var/turf/target_turf = brain.targeting.target_turf

	var/mob/living/carbon/tied_human = brain.tied_human
	tied_human.a_intent_change(INTENT_HARM)

	brain.combat.shot_at = get_turf(target_turf)
	tied_human.face_atom(target_turf)

	currently_firing = TRUE

	var/datum/firearm_appraisal/gun_data = brain.inventory.gun_data
	if(brain.guns.should_reload()) // note that bullet removal comes after comsig is triggered
		if(gun_data?.disposable)
			tied_human.drop_held_item(brain.inventory.primary_weapon)
			brain.inventory.set_primary_weapon(null)
		stop_firing(brain)
		qdel(src)
		return

	var/should_fire_offscreen = (target_turf && !COOLDOWN_FINISHED(brain, targeting.fire_offscreen))
	var/shoot_next = brain.targeting.current_target

	if(QDELETED(brain.targeting.current_target))
		if(!should_fire_offscreen)
			stop_firing(brain)
			qdel(src)
			return
		shoot_next = target_turf

	else if(ismob(brain.targeting.current_target))
		var/mob/mob_target = brain.targeting.current_target
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

	var/count_shot_against_burst_limit = ((brain.inventory.primary_weapon.gun_firemode == GUN_FIREMODE_AUTOMATIC) || gun_data.count_every_shot_toward_burst_limit)
	if(count_shot_against_burst_limit)
		rounds_burst_fired++

	if(rounds_burst_fired >= gun_data.burst_amount_max)
		var/short_action_delay = brain.profile.short_action_delay
		COOLDOWN_START(brain.guns, fire_overload_cooldown, max(short_action_delay, short_action_delay * brain.profile.action_delay_mult))
		stop_firing(brain)
		return

	if((get_dist(tied_human, shoot_next) > gun_data.maximum_range) && !should_fire_offscreen)
		brain.targeting.lose_target()
		stop_firing(brain)
		qdel(src)
		return

	if(brain.targeting.current_target && (get_dist(tied_human, brain.targeting.current_target) <= 1))
		currently_firing = FALSE
		return

	if(!firing_line_check(brain, shoot_next, listen = TRUE))
		stop_firing(brain)
		qdel(src)
		return

	// SS220 EDIT - START: HALO covenant AI vents overheating plasma guns before they hard-lock in sustained fire
	if(istype(brain.inventory.primary_weapon, /obj/item/weapon/gun/energy/plasma))
		var/obj/item/weapon/gun/energy/plasma/plasma_weapon = brain.inventory.primary_weapon
		if(plasma_weapon.heat >= 60)
			var/vent_decision = 0
			if(brain.targeting.current_target)
				vent_decision = max(0, -20 + (6 * get_dist(tied_human, brain.targeting.current_target)))
			else if(target_turf)
				vent_decision = max(0, -20 + (12 * get_dist(tied_human, target_turf)))

			vent_decision += max(0, plasma_weapon.heat - 65)
			if(prob(max(0, vent_decision)))
				currently_firing = FALSE
				brain.inventory.unholster_primary()
				brain.inventory.ensure_primary_hand(plasma_weapon)
				plasma_weapon.unload(tied_human)
				return
			else if(plasma_weapon.heat >= 100)
				currently_firing = FALSE
	// SS220 EDIT - END

	if(istype(brain.inventory.primary_weapon, /obj/item/weapon/gun/shotgun))
		currently_firing = FALSE
		if(istype(brain.inventory.primary_weapon, /obj/item/weapon/gun/shotgun/pump))
			var/obj/item/weapon/gun/shotgun/pump/shotgun = brain.inventory.primary_weapon
			addtimer(CALLBACK(shotgun, TYPE_PROC_REF(/obj/item/weapon/gun/shotgun/pump, pump_shotgun), tied_human), shotgun.pump_delay)
			COOLDOWN_START(brain.guns, stop_fire_cooldown, max(shotgun.pump_delay, shotgun.get_fire_delay()) + 1)
			stop_firing(brain)
			qdel(src)
			return
		else
			var/obj/item/weapon/gun/shotgun/autoshotty = brain.inventory.primary_weapon
			addtimer(CALLBACK(autoshotty, TYPE_PROC_REF(/obj/item/weapon/gun/shotgun, start_fire), tied_human), autoshotty.get_fire_delay()*3)
			COOLDOWN_START(brain.guns, stop_fire_cooldown, max(autoshotty.get_fire_delay()) + 3)
			stop_firing(brain)
			qdel(src)
			return

	else if(istype(brain.inventory.primary_weapon, /obj/item/weapon/gun/rifle/xm51))
		currently_firing = FALSE
		var/obj/item/weapon/gun/rifle/xm51/scattergun = brain.inventory.primary_weapon
		addtimer(CALLBACK(scattergun, TYPE_PROC_REF(/obj/item/weapon/gun/rifle/xm51, unique_action), tied_human), scattergun.pump_delay)
		COOLDOWN_START(brain.guns, stop_fire_cooldown, max(scattergun.pump_delay, scattergun.get_fire_delay()) + 1)
		stop_firing(brain)
		qdel(src)
		return

	else if(istype(brain.inventory.primary_weapon, /obj/item/weapon/gun/boltaction))
		var/obj/item/weapon/gun/boltaction/bolt = brain.inventory.primary_weapon
		currently_firing = FALSE
		addtimer(CALLBACK(bolt, TYPE_PROC_REF(/obj/item/weapon/gun/boltaction, unique_action), tied_human), 1)
		addtimer(CALLBACK(bolt, TYPE_PROC_REF(/obj/item/weapon/gun/boltaction, unique_action), tied_human), bolt.bolt_delay + 1)
		COOLDOWN_START(brain.guns, stop_fire_cooldown, max(bolt.bolt_delay * 2, bolt.get_fire_delay()) + 1)
		stop_firing(brain)
		qdel(src)
		return

	// SS220 EDIT - START
	// else if(istype(brain.inventory.primary_weapon, /obj/item/weapon/gun/energy/plasma/plasma_pistol))
	// else if(istype(brain.inventory.primary_weapon, /obj/item/weapon/gun/rifle/covenant_carbine))
	var/datum/callback/followup_fire_callback = brain.inventory.primary_weapon.get_ai_followup_fire_callback(tied_human, brain.targeting.current_target)
	if(followup_fire_callback)
		currently_firing = FALSE
		var/followup_fire_delay = brain.inventory.primary_weapon.get_ai_followup_fire_delay(tied_human, brain.targeting.current_target)
		var/followup_fire_cooldown = brain.inventory.primary_weapon.get_ai_followup_fire_cooldown(tied_human, brain.targeting.current_target)
		addtimer(followup_fire_callback, followup_fire_delay)
		COOLDOWN_START(brain.guns, stop_fire_cooldown, max(followup_fire_cooldown, followup_fire_delay))
		stop_firing(brain)
		qdel(src)
		return
	// SS220 EDIT - END

	else if(brain.inventory.primary_weapon.gun_firemode == GUN_FIREMODE_SEMIAUTO)
		currently_firing = FALSE
		addtimer(CALLBACK(brain.inventory.primary_weapon, TYPE_PROC_REF(/obj/item/weapon/gun, start_fire), null, brain.targeting.current_target, null, null, null, TRUE), brain.inventory.primary_weapon.get_fire_delay())

	else if(brain.inventory.primary_weapon.gun_firemode == GUN_FIREMODE_BURSTFIRE)
		currently_firing = FALSE
		addtimer(CALLBACK(brain.inventory.primary_weapon, TYPE_PROC_REF(/obj/item/weapon/gun, start_fire), null, brain.targeting.current_target, null, null, null, TRUE), brain.inventory.primary_weapon.get_burst_fire_delay())

	brain.inventory.primary_weapon?.set_target(shoot_next)

#undef FRIENDLY_FIRE_ADJACENT_CHECK_START_INDEX
