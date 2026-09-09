/datum/human_ai_module/health
	module_id = "health"
	required_module_types = list(/datum/human_ai_module/faction, /datum/human_ai_module/inventory, /datum/human_ai_module/profile)

	/// What items the AI considers when trying to heal brute damage
	var/static/list/brute_heal_items = list(
		/obj/item/stack/medical/advanced/bruise_pack,
		/obj/item/reagent_container/hypospray/autoinjector/bicaridine,
		/obj/item/reagent_container/hypospray/autoinjector/tricord,
		/obj/item/storage/pill_bottle/bicaridine,
		/obj/item/storage/pill_bottle/merabica,
		/obj/item/storage/pill_bottle/tricord,
		/obj/item/tool/weldingtool,
		/obj/item/stack/nanopaste,
	)

	/// What items the AI considers when trying to heal burn damage
	var/static/list/burn_heal_items = list(
		/obj/item/stack/medical/advanced/ointment,
		/obj/item/reagent_container/hypospray/autoinjector/kelotane,
		/obj/item/reagent_container/hypospray/autoinjector/tricord,
		/obj/item/storage/pill_bottle/kelotane,
		/obj/item/storage/pill_bottle/keloderm,
		/obj/item/storage/pill_bottle/tricord,
		/obj/item/stack/cable_coil,
		/obj/item/stack/nanopaste,
	)

	/// What items the AI considers when trying to heal toxin damage
	var/static/list/tox_heal_items = list(
		/obj/item/reagent_container/hypospray/autoinjector/antitoxin,
		/obj/item/reagent_container/hypospray/autoinjector/tricord,
		/obj/item/storage/pill_bottle/antitox,
		/obj/item/storage/pill_bottle/tricord,
	)

	/// What items the AI considers when trying to heal oxygen damage
	var/static/list/oxy_heal_items = list(
		/obj/item/reagent_container/hypospray/autoinjector/dexalinp,
		/obj/item/reagent_container/hypospray/autoinjector/tricord,
		/obj/item/storage/pill_bottle/dexalin,
		/obj/item/storage/pill_bottle/dexalinplus,
		/obj/item/storage/pill_bottle/tricord,
	)

	/// What items the AI considers when trying to fix bleeding
	var/static/list/bleed_heal_items = list(
		/obj/item/stack/medical/advanced/bruise_pack,
		/obj/item/stack/medical/bruise_pack,
	)

	/// What items the AI considers when trying to fix bonebreaks
	var/static/list/bonebreak_heal_items = list(
		/obj/item/stack/medical/splint,
	)

	/// What items the AI considers when trying to reduce pain
	var/static/list/painkiller_items = list(
		/obj/item/reagent_container/hypospray/autoinjector/tramadol,
		/obj/item/reagent_container/hypospray/autoinjector/oxycodone,
		/obj/item/storage/pill_bottle/tramadol,
	)

	/// At what percentage of max HP to start searching for medical treatment
	var/healing_start_threshold = 0.7
	/// Requires this much damage of one type to consider it a problem
	var/damage_problem_threshold = 5
	/// Pain percentage (out of 100) for the AI to consider using painkillers
	var/pain_percentage_threshold = 1

	/// Are we currently treating someone?
	var/healing_someone = FALSE
	var/treatment_generation = 0 // SS220 EDIT: cancellation invalidates every suspended frame of this treatment

	/// Reference for found injured ally
	var/mob/living/carbon/human/found_injured_ally

	/// Cooldown on using pills to avoid OD. This isn't the best solution as it prevents the AI from using more than 1 pill of any kind every 20s, but it'll work for now
	COOLDOWN_DECLARE(pill_use_cooldown)

	/// How many stacks of "wasn't able to treat" this AI has. If these stacks pass a certain threshold, the AI can no longer be treated by others for a small period of time. Stacks decay when not being accumulated
	var/cant_be_treated_stacks = 0

	/// How many stacks are required to stop this AI from recieving treatment
	var/treatment_stack_threshold = 10

/datum/human_ai_module/health/Destroy(force, ...)
	cancel_treatment() // SS220 EDIT: invalidate sleeping work before clearing the owning brain
	lose_injured_ally()
	return ..()

/datum/human_ai_module/health/reset_module()
	cancel_treatment() // SS220 EDIT: reset invalidates suspended treatment before clearing actions
	lose_injured_ally()

/datum/human_ai_module/health/suspend_module(clear_inventory = FALSE)
	lose_injured_ally()
	cancel_treatment() // SS220 EDIT: resumed AI must not inherit an old treatment continuation

/datum/human_ai_module/health/proc/set_injured_ally(mob/living/new_target)
	if(!new_target)
		return

	RegisterSignal(new_target, COMSIG_PARENT_QDELETING, PROC_REF(lose_injured_ally), TRUE)
	RegisterSignal(new_target, COMSIG_MOB_DEATH, PROC_REF(lose_injured_ally), TRUE)
	found_injured_ally = new_target

/datum/human_ai_module/health/proc/lose_injured_ally()
	if(found_injured_ally)
		UnregisterSignal(found_injured_ally, COMSIG_PARENT_QDELETING)
		UnregisterSignal(found_injured_ally, COMSIG_MOB_DEATH)
	found_injured_ally = null

/datum/human_ai_module/health/proc/get_injured_ally()
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return null

	var/list/viable_targets = list()
	var/atom/movable/closest_target
	var/smallest_distance = INFINITY

	for(var/mob/living/carbon/human/possible_buddy as anything in GLOB.alive_human_list)
		if(controller.is_puppet(possible_buddy))
			continue

		if(controller.get_z() != possible_buddy.z)
			continue

		if(!brain.is_friendly_target(possible_buddy))
			continue

		if(!controller.is_in_view_of(possible_buddy, brain.get_view_distance()))
			continue

		var/distance = controller.get_distance_to(possible_buddy)
		if(distance > brain.get_view_distance())
			continue

		if(!healing_start_check(possible_buddy))
			continue

		viable_targets += possible_buddy

		if(smallest_distance <= distance)
			continue

		closest_target = possible_buddy
		smallest_distance = distance

	if(length(viable_targets) > 1)
		return pick(viable_targets)

	return closest_target

/datum/human_ai_module/health/proc/healing_start_check(mob/living/carbon/human/target)
	return ((target.health / target.maxHealth) <= healing_start_threshold) || target.is_bleeding() || target.has_broken_limbs()

/datum/human_ai_module/health/proc/increment_treatment_stacks()
	cant_be_treated_stacks++
	addtimer(CALLBACK(src, PROC_REF(clear_treatment_stacks)), 5 SECONDS, TIMER_UNIQUE | TIMER_NO_HASH_WAIT | TIMER_OVERRIDE)

/datum/human_ai_module/health/proc/clear_treatment_stacks()
	cant_be_treated_stacks = 0

// SS220 EDIT - START: one owner and one continuation predicate for the complete treatment operation
/datum/human_ai_module/health/proc/cancel_treatment()
	treatment_generation++
	healing_someone = FALSE

/datum/human_ai_module/health/proc/can_continue_treatment(mob/living/carbon/human/target, treatment_id = null)
	if(!isnull(treatment_id) && treatment_id != treatment_generation)
		return FALSE
	if(QDELETED(src) || !brain?.can_continue_runtime_work() || QDELETED(target) || target.stat == DEAD)
		cancel_treatment()
		return FALSE
	return TRUE

/datum/human_ai_module/health/proc/get_treatment_check(mob/living/carbon/human/target)
	return CALLBACK(src, PROC_REF(can_continue_treatment), target, treatment_generation)

/datum/human_ai_module/health/proc/start_healing(mob/living/carbon/human/target)
	set waitfor = FALSE
	if(!can_continue_treatment(target) || healing_someone)
		return FALSE

	var/treatment_id = ++treatment_generation
	var/datum/callback/treatment_check = get_treatment_check(target)
	healing_someone = TRUE
	. = FALSE
	// Keep treatment priority explicit; re-evaluate damage after each preceding treatment.
	for(var/stage in 1 to 7)
		if(!treatment_check.Invoke())
			break
		var/list/item_types
		switch(stage)
			if(1)
				if(target.getBruteLoss() > damage_problem_threshold)
					item_types = brute_heal_items
			if(2)
				if(target.is_bleeding())
					item_types = bleed_heal_items
			if(3)
				if(target.has_broken_limbs())
					item_types = bonebreak_heal_items
			if(4)
				if(target.getFireLoss() > damage_problem_threshold)
					item_types = burn_heal_items
			if(5)
				if(target.pain.get_pain_percentage() > pain_percentage_threshold)
					item_types = painkiller_items
			if(6)
				if(target.getToxLoss() > damage_problem_threshold)
					item_types = tox_heal_items
			if(7)
				if(target.getOxyLoss() > damage_problem_threshold)
					item_types = oxy_heal_items
		if(item_types && use_treatment_item(target, item_types, treatment_check))
			. = TRUE

	if(treatment_id == treatment_generation)
		healing_someone = FALSE
	qdel(treatment_check)

/datum/human_ai_module/health/proc/use_treatment_item(mob/living/carbon/human/target, list/item_types, datum/callback/treatment_check)
	var/datum/human_tied_controller/controller = context?.controller
	if(!controller)
		return FALSE

	var/obj/item/item = brain.find_usable_equipment_by_type_list(item_types, HUMAN_AI_HEALTHITEMS, target)
	if(!item)
		return FALSE
	brain.clear_main_hand()
	if(!brain.equip_item_from_equipment_map(HUMAN_AI_HEALTHITEMS, item))
		return FALSE

	sleep(brain.get_action_delay())
	if(!treatment_check.Invoke() || QDELETED(item))
		return FALSE
	controller.ai_use(item, target)
	if(!treatment_check.Invoke() || QDELETED(item))
		return TRUE

	var/storage_slot = brain.storage_has_room(item)
	if(storage_slot)
		brain.store_item(item, storage_slot, HUMAN_AI_HEALTHITEMS)
	else
		controller.drop_held_item(item)
	return TRUE
// SS220 EDIT - END
