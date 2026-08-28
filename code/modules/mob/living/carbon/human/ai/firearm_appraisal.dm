GLOBAL_LIST_INIT_TYPED(firearm_appraisals, /datum/firearm_appraisal, build_firearm_appraisal_list())

/datum/human_ai_fire_after_fire_result
	var/handled = FALSE
	var/currently_firing
	var/stop_firing = FALSE
	var/delete_action = FALSE
	var/cooldown = 0
	var/datum/callback/callback
	var/callback_delay = 0

// SS220 EDIT - START: keep subtype-specific appraisals ahead of generic bases so modular HALO guns resolve correctly
/proc/get_firearm_appraisal_specificity(datum/firearm_appraisal/appraisal)
	var/max_specificity = 0
	for(var/gun_type as anything in appraisal.gun_types)
		max_specificity = max(max_specificity, length(splittext("[gun_type]", "/")))
	return max_specificity

/proc/cmp_firearm_appraisal_specificity(datum/firearm_appraisal/a, datum/firearm_appraisal/b)
	return get_firearm_appraisal_specificity(b) - get_firearm_appraisal_specificity(a)
// SS220 EDIT - END

/proc/build_firearm_appraisal_list()
	. = list()
	for(var/type in subtypesof(/datum/firearm_appraisal))
		. += new type
	. = sortTim(., GLOBAL_PROC_REF(cmp_firearm_appraisal_specificity)) // SS220 EDIT: prefer most-specific firearm appraisal matches before generic weapon families

/proc/get_firearm_appraisal(obj/item/weapon/gun/firearm) as /datum/firearm_appraisal
	for(var/datum/firearm_appraisal/appraisal as anything in GLOB.firearm_appraisals)
		if(is_type_in_list(firearm, appraisal.gun_types))
			return appraisal

/datum/firearm_appraisal
	/// Minimum engagement range with weapon type
	var/minimum_range = 2
	/// Optimal engagement range, try to stay at this distance
	var/optimal_range = 6
	/// Maximum engagement range, stop firing at this distance
	var/maximum_range = 16
	/// How many rounds to fire in 1 burst at most
	var/burst_amount_max = 8
	/// If TRUE, every fired shot counts toward the burst cap even for semiauto or burstfire weapons.
	var/count_every_shot_toward_burst_limit = FALSE
	/// List of types that set the human AI to this appraisal type
	var/list/gun_types = list()
	/// If TRUE, this gun is disposable and isn't worth trying to reload
	var/disposable = FALSE
	/// The selection weight of the weapon type. If an AI has multiple weapons, it'll use weighting to determine its primary. In short, higher weight = more powerful
	var/primary_weight = 1

// SS220 EDIT - START: modular primary weapon selection hook
/datum/firearm_appraisal/proc/get_primary_weight(mob/living/carbon/human/user)
	return primary_weight
// SS220 EDIT - END

/datum/firearm_appraisal/proc/can_queue_fire(obj/item/weapon/gun/firearm, datum/human_ai_brain/AI)
	return firearm && AI?.has_valid_tied_human()

/// List of things we do before beginning to spray bullets based off weapon type
/datum/firearm_appraisal/proc/before_fire(obj/item/weapon/gun/firearm, mob/living/carbon/user, datum/human_ai_brain/AI)
	SHOULD_CALL_PARENT(TRUE) // Every weapon may be twohanded or have safety
	set waitfor = FALSE

	AI.inventory.ensure_primary_hand(firearm)
	if((firearm.flags_item & TWOHANDED) && !(firearm.flags_item & WIELDED))
		AI.inventory.wield_primary_sleep()

	if(firearm.flags_gun_features & GUN_TRIGGER_SAFETY)
		firearm.flags_gun_features ^= GUN_TRIGGER_SAFETY
		firearm.gun_safety_handle(user)

/// Reload sequence per weapon type, override as needed
/datum/firearm_appraisal/proc/do_reload(obj/item/weapon/gun/firearm, obj/item/ammo_magazine/mag, mob/living/carbon/user, datum/human_ai_brain/AI)
	if(QDELETED(firearm) || QDELETED(mag) || QDELETED(user) || !AI || !AI.has_valid_tied_human())
		return
	AI.inventory.unholster_primary()
	AI.inventory.ensure_primary_hand(firearm)
	firearm.unwield(user)
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	if(QDELETED(firearm) || QDELETED(user) || !AI.has_valid_tied_human())
		return
	if(!(firearm?.flags_gun_features & GUN_INTERNAL_MAG) && firearm?.current_mag)
		firearm?.unload(user, FALSE, TRUE, FALSE)
	AI.tied_controller.swap_hand()
	sleep(AI.profile.micro_action_delay * AI.profile.action_delay_mult)
	if(QDELETED(firearm) || QDELETED(mag) || QDELETED(user) || !AI.has_valid_tied_human())
		return
	AI.inventory.equip_item_from_equipment_map(HUMAN_AI_AMMUNITION, mag)
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	if(QDELETED(firearm) || QDELETED(mag) || QDELETED(user) || !AI.has_valid_tied_human())
		return
	if(istype(mag, /obj/item/ammo_magazine/handful))
		for(var/i in 1 to mag.current_rounds)
			if(QDELETED(firearm) || QDELETED(mag) || QDELETED(user) || !AI.has_valid_tied_human())
				return
			firearm?.attackby(mag, user)
			sleep(AI.profile.micro_action_delay * AI.profile.action_delay_mult)
		if(!QDELETED(mag) && (mag.current_rounds > 0))
			var/storage_slot = AI.inventory.storage_has_room(mag)
			if(storage_slot)
				AI.inventory.store_item(mag, storage_slot, HUMAN_AI_AMMUNITION)
			else
				AI.tied_controller.drop_held_item(mag)
	else
		firearm?.attackby(mag, user)
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	if(QDELETED(user) || !AI.has_valid_tied_human())
		return
	AI.tied_controller.swap_hand()
	AI.inventory.wield_primary_sleep()

/datum/firearm_appraisal/proc/handle_after_fire(obj/item/weapon/gun/firearm, datum/human_ai_brain/AI, atom/movable/current_target, turf/target_turf)
	RETURN_TYPE(/datum/human_ai_fire_after_fire_result)
	if(!firearm || !AI?.has_valid_tied_human())
		return null

	var/datum/callback/followup_fire_callback = AI.tied_controller.get_ai_followup_fire_callback(firearm, current_target)
	if(!followup_fire_callback)
		return null

	var/datum/human_ai_fire_after_fire_result/result = new()
	result.handled = TRUE
	result.currently_firing = FALSE
	result.stop_firing = TRUE
	result.delete_action = TRUE
	result.callback = followup_fire_callback
	result.callback_delay = AI.tied_controller.get_ai_followup_fire_delay(firearm, current_target)
	var/followup_fire_cooldown = AI.tied_controller.get_ai_followup_fire_cooldown(firearm, current_target)
	result.cooldown = max(followup_fire_cooldown, result.callback_delay)
	return result

/datum/firearm_appraisal/sniper
	optimal_range = 7
	maximum_range = 30
	burst_amount_max = 1
	gun_types = list(
		/obj/item/weapon/gun/rifle/sniper,
	)
	primary_weight = 8

/datum/firearm_appraisal/xm51
	burst_amount_max = 1
	minimum_range = 1
	optimal_range = 1 // point-blank our beloved
	maximum_range = 3
	gun_types = list(
		/obj/item/weapon/gun/rifle/xm51,
	)
	primary_weight = 4

/datum/firearm_appraisal/xm51/before_fire(obj/item/weapon/gun/shotgun/firearm, mob/living/carbon/user, datum/human_ai_brain/AI)
	. = ..()
	if(firearm.in_chamber)
		return
	firearm.unique_action(user)

/datum/firearm_appraisal/xm51/handle_after_fire(obj/item/weapon/gun/rifle/xm51/firearm, datum/human_ai_brain/AI, atom/movable/current_target, turf/target_turf)
	if(!firearm || !AI?.has_valid_tied_human())
		return null
	var/datum/human_ai_fire_after_fire_result/result = new()
	result.handled = TRUE
	result.currently_firing = FALSE
	result.stop_firing = TRUE
	result.delete_action = TRUE
	AI.tied_controller.start_weapon_unique_action(firearm, firearm.pump_delay)
	result.cooldown = max(firearm.pump_delay, firearm.get_fire_delay()) + 1
	return result

/datum/firearm_appraisal/rifle
	burst_amount_max = 8
	gun_types = list(
		/obj/item/weapon/gun/rifle,
	)
	primary_weight = 5

/datum/firearm_appraisal/smartgun
	burst_amount_max = 18
	gun_types = list(
		/obj/item/weapon/gun/smartgun,
		/obj/item/weapon/gun/pkp,
	)
	primary_weight = 10

/datum/firearm_appraisal/smartgun/do_reload(obj/item/weapon/gun/firearm, obj/item/ammo_magazine/mag, mob/living/carbon/user, datum/human_ai_brain/AI)
	AI.inventory.unholster_primary()
	AI.inventory.ensure_primary_hand(firearm)
	firearm.unwield(user)
	AI.tied_controller.swap_hand()
	firearm.clicked(user, list("alt" = TRUE))
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	AI.tied_controller.swap_hand()
	if(!(firearm?.flags_gun_features & GUN_INTERNAL_MAG) && firearm?.current_mag)
		firearm?.unload(user, FALSE, TRUE, FALSE)
	AI.tied_controller.swap_hand()
	sleep(AI.profile.micro_action_delay * AI.profile.action_delay_mult)
	AI.inventory.equip_item_from_equipment_map(HUMAN_AI_AMMUNITION, mag)
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	firearm?.attackby(mag, user)
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	firearm.clicked(user, list("alt" = TRUE))
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	AI.tied_controller.swap_hand()
	AI.inventory.wield_primary_sleep()

/datum/firearm_appraisal/smg
	burst_amount_max = 10
	minimum_range = 1
	optimal_range = 5
	maximum_range = 10
	gun_types = list(
		/obj/item/weapon/gun/smg,
	)
	primary_weight = 4

/datum/firearm_appraisal/shotgun_db
	burst_amount_max = 2
	minimum_range = 1
	optimal_range = 1
	maximum_range = 3
	gun_types = list(
		/obj/item/weapon/gun/shotgun/double,
	)

/datum/firearm_appraisal/shotgun_db/do_reload(obj/item/weapon/gun/firearm, obj/item/ammo_magazine/mag, mob/living/carbon/user, datum/human_ai_brain/AI)
	AI.inventory.unholster_primary()
	AI.inventory.ensure_primary_hand(firearm)
	firearm.unwield(user)
	firearm.unique_action()
	AI.tied_controller.swap_hand()
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	AI.inventory.equip_item_from_equipment_map(HUMAN_AI_AMMUNITION, mag)
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	firearm.attackby(mag, user)
	sleep(AI.profile.micro_action_delay * AI.profile.action_delay_mult)
	firearm.attackby(mag, user)
	if(!QDELETED(mag))
		var/storage_spot = AI.inventory.storage_has_room(mag)
		if(storage_spot)
			sleep(AI.profile.micro_action_delay * AI.profile.action_delay_mult)
			AI.inventory.store_item(mag, storage_spot, HUMAN_AI_AMMUNITION)
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	AI.tied_controller.swap_hand()
	firearm.unique_action()
	AI.inventory.wield_primary_sleep()

/datum/firearm_appraisal/shotgun
	burst_amount_max = 2
	minimum_range = 1
	optimal_range = 1 // point-blank our beloved
	maximum_range = 3
	gun_types = list(
		/obj/item/weapon/gun/shotgun,
	)
	primary_weight = 4

/datum/firearm_appraisal/shotgun/before_fire(obj/item/weapon/gun/shotgun/firearm, mob/living/carbon/user, datum/human_ai_brain/AI)
	. = ..()
	if(firearm.in_chamber)
		return
	firearm.unique_action(user)

/datum/firearm_appraisal/shotgun/handle_after_fire(obj/item/weapon/gun/shotgun/firearm, datum/human_ai_brain/AI, atom/movable/current_target, turf/target_turf)
	if(!firearm || !AI?.has_valid_tied_human())
		return null
	var/datum/human_ai_fire_after_fire_result/result = new()
	result.handled = TRUE
	result.currently_firing = FALSE
	result.stop_firing = TRUE
	result.delete_action = TRUE
	if(istype(firearm, /obj/item/weapon/gun/shotgun/pump))
		var/obj/item/weapon/gun/shotgun/pump/pump_shotgun = firearm
		AI.tied_controller.start_weapon_unique_action(pump_shotgun, pump_shotgun.pump_delay)
		result.cooldown = max(pump_shotgun.pump_delay, pump_shotgun.get_fire_delay()) + 1
		return result
	AI.tied_controller.start_weapon_fire(firearm, firearm.get_fire_delay()*3)
	result.cooldown = max(firearm.get_fire_delay()) + 3
	return result

/datum/firearm_appraisal/boltaction
	optimal_range = 7
	maximum_range = 30
	burst_amount_max = 1
	gun_types = list(
		/obj/item/weapon/gun/boltaction,
	)
	primary_weight = 4

/datum/firearm_appraisal/boltaction/before_fire(obj/item/weapon/gun/boltaction/firearm, mob/living/carbon/user, datum/human_ai_brain/AI)
	. = ..()
	if(firearm.in_chamber)
		return
	firearm.unique_action(user)
	firearm.recent_cycle = world.time - firearm.bolt_delay
	firearm.unique_action(user)
	firearm.recent_cycle = world.time - firearm.bolt_delay

/datum/firearm_appraisal/boltaction/handle_after_fire(obj/item/weapon/gun/boltaction/firearm, datum/human_ai_brain/AI, atom/movable/current_target, turf/target_turf)
	if(!firearm || !AI?.has_valid_tied_human())
		return null
	var/datum/human_ai_fire_after_fire_result/result = new()
	result.handled = TRUE
	result.currently_firing = FALSE
	result.stop_firing = TRUE
	result.delete_action = TRUE
	AI.tied_controller.start_weapon_unique_action(firearm, 1)
	AI.tied_controller.start_weapon_unique_action(firearm, firearm.bolt_delay + 1)
	result.cooldown = max(firearm.bolt_delay * 2, firearm.get_fire_delay()) + 1
	return result

/datum/firearm_appraisal/flamer
	burst_amount_max = 1
	minimum_range = 3
	optimal_range = 4
	maximum_range = 5
	gun_types = list(
		/obj/item/weapon/gun/flamer,
	)
	primary_weight = 7

/datum/firearm_appraisal/rpg
	minimum_range = 2
	optimal_range = 6
	gun_types = list(
		/obj/item/weapon/gun/launcher/rocket/anti_tank/disposable,
	)
	disposable = TRUE
	primary_weight = 15

/datum/firearm_appraisal/rpg/multi_use
	gun_types = list(
		/obj/item/weapon/gun/launcher/rocket,
	)
	disposable = FALSE

/datum/firearm_appraisal/pistol
	maximum_range = 9
	gun_types = list(
		/obj/item/weapon/gun/pistol,
		/obj/item/weapon/gun/revolver,
	)
	primary_weight = 1
