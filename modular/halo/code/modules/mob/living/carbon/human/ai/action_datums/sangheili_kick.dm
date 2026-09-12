/datum/ai_action/sangheili_kick
	name = "Пинок сангхейли"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/melee, /datum/human_ai_module/halo_covenant, /datum/human_ai_module/halo_sangheili)

/datum/ai_action/sangheili_kick/Added()
	var/datum/human_ai_module/melee/melee = context?.get_module(/datum/human_ai_module/melee)
	melee?.halo_sangheili_on_unarmed_action_added()

/datum/ai_action/sangheili_kick/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_module/melee/melee = context?.get_module(/datum/human_ai_module/melee)
	return melee?.halo_sangheili_get_kick_weight() || 0

/datum/ai_action/sangheili_kick/Destroy(force, ...)
	var/datum/human_ai_module/melee/melee = context?.get_module(/datum/human_ai_module/melee)
	melee?.halo_sangheili_cleanup_unarmed_action()
	return ..()

/datum/ai_action/sangheili_kick/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_module/melee/melee = context?.get_module(/datum/human_ai_module/melee)
	return melee?.halo_sangheili_run_kick_step() || ONGOING_ACTION_COMPLETED
