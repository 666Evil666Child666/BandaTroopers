/datum/firearm_appraisal/covenant
	gun_types = list()
	disposable = FALSE

/datum/firearm_appraisal/covenant/get_primary_weight(mob/living/carbon/human/user)
	if(isunggoy(user) || issangheili(user) || isruuhtian(user))
		return primary_weight * 3
	return ..()

/datum/firearm_appraisal/covenant/plasma
	gun_types = list(
		/obj/item/weapon/gun/energy/plasma,
	)
	primary_weight = 7
	burst_amount_max = 4
	count_every_shot_toward_burst_limit = TRUE

/datum/firearm_appraisal/covenant/plasma/pistol
	minimum_range = 1
	optimal_range = 4
	maximum_range = 9
	burst_amount_max = 2
	count_every_shot_toward_burst_limit = TRUE
	gun_types = list(
		/obj/item/weapon/gun/energy/plasma/plasma_pistol,
	)
	primary_weight = 6

/datum/firearm_appraisal/covenant/plasma/rifle
	minimum_range = 2
	optimal_range = 5
	maximum_range = 11
	burst_amount_max = 3
	count_every_shot_toward_burst_limit = TRUE
	gun_types = list(
		/obj/item/weapon/gun/energy/plasma/plasma_rifle,
	)
	primary_weight = 7

/datum/firearm_appraisal/covenant/needler
	minimum_range = 1
	optimal_range = 4
	maximum_range = 9
	burst_amount_max = 2
	count_every_shot_toward_burst_limit = TRUE
	gun_types = list(
		/obj/item/weapon/gun/smg/covenant_needler,
	)
	primary_weight = 7

#define PLASMA_VENT_CHANCE_DIRECT_COMBAT 6
#define PLASMA_VENT_CHANCE_INDIRECT_COMBAT 12

/datum/firearm_appraisal/covenant/plasma/before_fire(obj/item/weapon/gun/energy/plasma/firearm, mob/living/carbon/user, datum/human_ai_brain/AI)
	. = ..()
	if(firearm.dispersing)
		AI.cover.try_cover()
		return
	if(firearm.heat < 60)
		return
	var/vent_decision = 0
	if(AI.targeting.current_target)
		vent_decision = max(0, -20 + (PLASMA_VENT_CHANCE_DIRECT_COMBAT * AI.tied_controller.get_distance_to(AI.targeting.current_target)))
	else if(AI.targeting.target_turf)
		vent_decision = max(0, -20 + (PLASMA_VENT_CHANCE_INDIRECT_COMBAT * AI.tied_controller.get_distance_to(AI.targeting.target_turf)))
	vent_decision += max(0, firearm.heat - 65)
	if(prob(max(0, vent_decision)))
		AI.inventory.unholster_primary()
		AI.inventory.ensure_primary_hand(firearm)
		firearm.unwield(user)
		sleep(AI.profile.micro_action_delay * AI.profile.action_delay_mult)
		user.swap_hand()
		sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
		firearm.unload(user)
		sleep(AI.profile.micro_action_delay * AI.profile.action_delay_mult)
		user.swap_hand()
		AI.inventory.wield_primary_sleep()

/datum/firearm_appraisal/covenant/plasma/can_queue_fire(obj/item/weapon/gun/energy/plasma/firearm, datum/human_ai_brain/AI)
	if(!..())
		return FALSE
	return !firearm.dispersing

/datum/firearm_appraisal/covenant/plasma/handle_after_fire(obj/item/weapon/gun/energy/plasma/firearm, datum/human_ai_brain/AI, atom/movable/current_target, turf/target_turf)
	if(!firearm || !AI?.has_valid_tied_human())
		return null
	if(firearm.heat < 60)
		return ..()

	var/vent_decision = 0
	if(current_target)
		vent_decision = max(0, -20 + (PLASMA_VENT_CHANCE_DIRECT_COMBAT * AI.tied_controller.get_distance_to(current_target)))
	else if(target_turf)
		vent_decision = max(0, -20 + (PLASMA_VENT_CHANCE_INDIRECT_COMBAT * AI.tied_controller.get_distance_to(target_turf)))

	vent_decision += max(0, firearm.heat - 65)
	var/datum/human_ai_fire_after_fire_result/result
	if(prob(max(0, vent_decision)))
		result = new()
		result.handled = TRUE
		result.currently_firing = FALSE
		AI.inventory.unholster_primary()
		AI.inventory.ensure_primary_hand(firearm)
		AI.tied_controller.unload_weapon(firearm)
		return result
	else if(firearm.heat >= 100)
		result = ..()
		if(!result)
			result = new()
		result.currently_firing = FALSE
		return result

	return ..()

#undef PLASMA_VENT_CHANCE_DIRECT_COMBAT
#undef PLASMA_VENT_CHANCE_INDIRECT_COMBAT

/datum/firearm_appraisal/halo_plasma_pistol
	parent_type = /datum/firearm_appraisal/covenant/plasma/pistol
	gun_types = list()

/datum/firearm_appraisal/halo_plasma_rifle
	parent_type = /datum/firearm_appraisal/covenant/plasma/rifle
	gun_types = list()

/datum/firearm_appraisal/halo_needler
	parent_type = /datum/firearm_appraisal/covenant/needler
	gun_types = list()

/datum/firearm_appraisal/halo_carbine
	minimum_range = 2
	optimal_range = 6
	maximum_range = 12
	burst_amount_max = 3
	count_every_shot_toward_burst_limit = TRUE
	gun_types = list(
		/obj/item/weapon/gun/rifle/covenant_carbine,
	)
	primary_weight = 5

/datum/firearm_appraisal/halo_carbine/get_primary_weight(mob/living/carbon/human/user)
	if(isunggoy(user) || issangheili(user) || isruuhtian(user))
		return primary_weight * 3
	return ..()

/datum/firearm_appraisal/halo_spnkr
	minimum_range = 3
	optimal_range = 7
	maximum_range = 14
	burst_amount_max = 1
	gun_types = list(
		/obj/item/weapon/gun/halo_launcher/spnkr,
	)
	primary_weight = 15

/datum/firearm_appraisal/halo_spnkr/before_fire(obj/item/weapon/gun/halo_launcher/spnkr/firearm, mob/living/carbon/user, datum/human_ai_brain/AI)
	. = ..()
	if(firearm.cover_open)
		firearm.toggle_cover(user)
		sleep(AI.profile.micro_action_delay * AI.profile.action_delay_mult)
	if(!firearm.in_chamber && firearm.current_mag?.current_rounds > 0)
		firearm.cock(user)

/datum/firearm_appraisal/halo_spnkr/do_reload(obj/item/weapon/gun/halo_launcher/spnkr/firearm, obj/item/ammo_magazine/spnkr/mag, mob/living/carbon/user, datum/human_ai_brain/AI)
	if(QDELETED(firearm) || QDELETED(mag) || QDELETED(user) || !AI || !AI.has_valid_tied_human())
		return
	AI.inventory.unholster_primary()
	AI.inventory.ensure_primary_hand(firearm)
	firearm.unwield(user)
	if(!firearm.cover_open)
		firearm.toggle_cover(user)
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	if(QDELETED(firearm) || QDELETED(mag) || QDELETED(user) || !AI.has_valid_tied_human())
		return
	if(firearm.current_mag)
		firearm.unload(user, FALSE, TRUE, FALSE)
	user.swap_hand()
	sleep(AI.profile.micro_action_delay * AI.profile.action_delay_mult)
	if(QDELETED(firearm) || QDELETED(mag) || QDELETED(user) || !AI.has_valid_tied_human())
		return
	AI.inventory.equip_item_from_equipment_map(HUMAN_AI_AMMUNITION, mag)
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	if(QDELETED(firearm) || QDELETED(mag) || QDELETED(user) || !AI.has_valid_tied_human())
		return
	firearm.attackby(mag, user)
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	if(QDELETED(firearm) || QDELETED(user) || !AI.has_valid_tied_human())
		return
	if(firearm.cover_open)
		firearm.toggle_cover(user)
	sleep(AI.profile.micro_action_delay * AI.profile.action_delay_mult)
	if(QDELETED(user) || !AI.has_valid_tied_human())
		return
	user.swap_hand()
	AI.inventory.wield_primary_sleep()
