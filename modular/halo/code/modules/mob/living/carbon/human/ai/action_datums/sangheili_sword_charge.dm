/datum/ai_action/sangheili_sword_charge
	name = "Рывок сангхейли с мечом"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/melee)

/datum/ai_action/sangheili_sword_charge/Added()
	var/datum/human_ai_module/melee/melee = context?.get_module(/datum/human_ai_module/melee)
	melee?.halo_sangheili_on_sword_charge_added()

/datum/ai_action/sangheili_sword_charge/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_module/melee/melee = context?.get_module(/datum/human_ai_module/melee)
	return melee?.halo_sangheili_get_sword_charge_weight() || 0

/datum/ai_action/sangheili_sword_charge/Destroy(force, ...)
	var/datum/human_ai_module/melee/melee = context?.get_module(/datum/human_ai_module/melee)
	melee?.halo_sangheili_cleanup_sword_charge()
	return ..()

/datum/ai_action/sangheili_sword_charge/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_module/melee/melee = context?.get_module(/datum/human_ai_module/melee)
	return melee?.halo_sangheili_run_sword_charge_step() || ONGOING_ACTION_COMPLETED
