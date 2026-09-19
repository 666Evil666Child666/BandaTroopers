/datum/ai_action/treat_ally
	name = "Treat Ally"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/health, /datum/human_ai_module/inventory, /datum/human_ai_module/navigation)
	var/mob/living/carbon/human/ally_to_treat

/datum/ai_action/treat_ally/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	var/datum/human_ai_module/health/health = context?.get_module(/datum/human_ai_module/health)
	if(!brain || !controller || !health)
		return 0

	if(controller.is_zombie())
		return 0

	if(brain.is_healing_someone())
		return 0

	if(brain.has_current_target() || brain.has_offscreen_fire_target())
		return 0

	if(brain.has_pickup_queue())
		return 0

	if(!health.get_ally_treatment_candidate())
		return 0

	return 5

/datum/ai_action/treat_ally/Added()
	var/datum/human_ai_module/health/health = context?.get_module(/datum/human_ai_module/health)
	if(!health)
		return

	ally_to_treat = health.get_ally_treatment_candidate()
	if(ally_to_treat)
		health.set_injured_ally(ally_to_treat)

/datum/ai_action/treat_ally/Destroy(force, ...)
	var/datum/human_ai_module/health/health = context?.get_module(/datum/human_ai_module/health)
	health?.lose_injured_ally()
	brain?.cancel_treatment()
	ally_to_treat = null
	return ..()

/datum/ai_action/treat_ally/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	var/datum/human_ai_module/health/health = context?.get_module(/datum/human_ai_module/health)
	if(!brain || !controller || !health)
		return ONGOING_ACTION_COMPLETED

	if(brain.has_current_target())
		return ONGOING_ACTION_COMPLETED

	if(brain.is_healing_someone())
		return ONGOING_ACTION_UNFINISHED

	if(!health.can_treat_ally(ally_to_treat))
		return ONGOING_ACTION_COMPLETED

	if(controller.get_distance_to(ally_to_treat) > 1)
		if(!brain.move_to_atom(ally_to_treat))
			return ONGOING_ACTION_COMPLETED
		if(controller.get_distance_to(ally_to_treat) > 1)
			return ONGOING_ACTION_UNFINISHED

	if(!health.start_healing(ally_to_treat) && !brain.is_healing_someone())
		return ONGOING_ACTION_COMPLETED

	return ONGOING_ACTION_UNFINISHED
