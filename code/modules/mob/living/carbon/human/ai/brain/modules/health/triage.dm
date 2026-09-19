/datum/human_ai_module/health/proc/can_self_treat(datum/human_tied_controller/controller)
	if(!controller)
		return FALSE

	var/mob/living/carbon/human/self_target = controller.get_self_target()
	return has_applicable_treatment_for(self_target) && healing_start_check_controller(controller)

/datum/human_ai_module/health/proc/can_treat_ally(mob/living/carbon/human/target)
	if(!target || QDELETED(target) || target.stat == DEAD)
		return FALSE
	if(!brain.is_friendly_target(target))
		return FALSE
	return healing_start_check(target) && has_applicable_treatment_for(target)

/datum/human_ai_module/health/proc/get_ally_treatment_candidate()
	var/mob/living/carbon/human/injured_ally = get_injured_ally()
	if(!can_treat_ally(injured_ally))
		return null
	return injured_ally
