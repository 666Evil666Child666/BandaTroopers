// Human AI health/treatment API.

/datum/human_ai_brain/proc/is_healing_someone()
	var/datum/human_ai_module/health/health_module = get_health_module()
	return health_module?.is_treating()

/datum/human_ai_brain/proc/can_retry_self_treatment()
	var/datum/human_ai_module/health/health_module = get_health_module()
	return health_module?.can_retry_self_treatment()

/datum/human_ai_brain/proc/cancel_treatment()
	var/datum/human_ai_module/health/health_module = get_health_module()
	health_module?.cancel_treatment()

/datum/human_ai_brain/proc/increment_treatment_stacks()
	var/datum/human_ai_module/health/health_module = get_health_module()
	health_module?.increment_treatment_stacks()

/datum/human_ai_brain/proc/can_start_self_treatment_now(datum/human_tied_controller/controller)
	var/datum/human_ai_module/health/health_module = get_health_module()
	return health_module?.can_start_self_treatment_now(controller)

/datum/human_ai_brain/proc/can_continue_self_treatment_now(datum/human_tied_controller/controller)
	var/datum/human_ai_module/health/health_module = get_health_module()
	return health_module?.can_continue_self_treatment_now(controller)

/datum/human_ai_brain/proc/start_healing_controller(datum/human_tied_controller/controller)
	var/datum/human_ai_module/health/health_module = get_health_module()
	return health_module?.start_healing_controller(controller)

/datum/human_ai_brain/proc/get_ally_treatment_candidate()
	RETURN_TYPE(/mob/living/carbon/human)
	var/datum/human_ai_module/health/health_module = get_health_module()
	return health_module?.get_ally_treatment_candidate()

/datum/human_ai_brain/proc/set_injured_ally(mob/living/carbon/human/ally)
	var/datum/human_ai_module/health/health_module = get_health_module()
	health_module?.set_injured_ally(ally)

/datum/human_ai_brain/proc/lose_injured_ally()
	var/datum/human_ai_module/health/health_module = get_health_module()
	health_module?.lose_injured_ally()

/datum/human_ai_brain/proc/can_start_ally_treatment_now(mob/living/carbon/human/ally)
	var/datum/human_ai_module/health/health_module = get_health_module()
	return health_module?.can_start_ally_treatment_now(ally)

/datum/human_ai_brain/proc/can_continue_ally_treatment_now(mob/living/carbon/human/ally)
	var/datum/human_ai_module/health/health_module = get_health_module()
	return health_module?.can_continue_ally_treatment_now(ally)

/datum/human_ai_brain/proc/start_healing(mob/living/carbon/human/target)
	var/datum/human_ai_module/health/health_module = get_health_module()
	return health_module?.start_healing(target)
