/datum/human_ai_module/health/proc/can_self_treat(datum/human_tied_controller/controller)
	if(!controller)
		return FALSE

	var/mob/living/carbon/human/self_target = controller.get_self_target()
	return has_applicable_treatment_for(self_target) && healing_start_check_controller(controller)

/datum/human_ai_module/health/proc/can_treat_under_current_combat_pressure()
	return brain && !has_owner_current_target() && !has_owner_offscreen_fire_target()

/datum/human_ai_module/health/proc/can_start_self_treatment_now(datum/human_tied_controller/controller)
	return can_treat_under_current_combat_pressure() && can_self_treat(controller)

/datum/human_ai_module/health/proc/can_continue_self_treatment_now(datum/human_tied_controller/controller)
	if(!can_treat_under_current_combat_pressure())
		return FALSE
	var/mob/living/carbon/human/self_target = controller?.get_self_target()
	return self_target && !QDELETED(self_target) && self_target.stat != DEAD

/datum/human_ai_module/health/proc/can_treat_ally(mob/living/carbon/human/target)
	if(!target || QDELETED(target) || target.stat == DEAD)
		return FALSE
	if(!is_owner_friendly_target(target))
		return FALSE
	return healing_start_check(target) && has_applicable_treatment_for(target)

/datum/human_ai_module/health/proc/can_start_ally_treatment_now(mob/living/carbon/human/target)
	return can_treat_under_current_combat_pressure() && can_treat_ally(target)

/datum/human_ai_module/health/proc/can_continue_ally_treatment_now(mob/living/carbon/human/target)
	if(!can_treat_under_current_combat_pressure())
		return FALSE
	if(!target || QDELETED(target) || target.stat == DEAD)
		return FALSE
	return is_owner_friendly_target(target)

/datum/human_ai_module/health/proc/get_ally_treatment_priority(mob/living/carbon/human/target, distance = 0)
	if(!target || !target.maxHealth)
		return -INFINITY

	var/health_ratio = target.health / target.maxHealth
	var/score = 0

	if(target.health <= HEALTH_THRESHOLD_CRIT)
		score += 120
	if(health_ratio <= 0.25)
		score += 100
	else if(health_ratio <= 0.5)
		score += 60
	else if(health_ratio <= healing_start_threshold)
		score += 25

	if(target.is_bleeding())
		score += 45
	if(target.has_broken_limbs())
		score += 30

	score += min(target.getBruteLoss(), 40)
	score += min(target.getFireLoss(), 40)
	score += min(target.getToxLoss(), 25)
	score += min(target.getOxyLoss(), 25)
	score -= min(distance * 2, 30)

	return score

/datum/human_ai_module/health/proc/get_ally_treatment_candidate()
	var/mob/living/carbon/human/injured_ally = get_injured_ally()
	if(!can_start_ally_treatment_now(injured_ally))
		return null
	return injured_ally
