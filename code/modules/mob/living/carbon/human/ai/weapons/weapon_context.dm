// Shared Human AI weapon-use context.

/datum/human_ai_weapon_context
	var/datum/human_ai_brain/AI
	var/datum/human_tied_controller/controller
	var/obj/item/weapon_item
	var/atom/movable/current_target
	var/turf/target_turf

/datum/human_ai_weapon_context/New(datum/human_ai_brain/new_ai, obj/item/new_weapon_item = null, atom/movable/new_current_target = null, turf/new_target_turf = null)
	AI = new_ai
	controller = AI?.tied_controller
	weapon_item = new_weapon_item
	current_target = new_current_target
	target_turf = new_target_turf

/datum/human_ai_weapon_context/proc/is_valid()
	return AI?.can_continue_runtime_work() && controller

/datum/human_ai_weapon_context/proc/can_continue(obj/item/item = weapon_item)
	if(!is_valid())
		return FALSE
	if(item && QDELETED(item))
		return FALSE
	return TRUE

/datum/human_ai_weapon_context/proc/sleep_short()
	sleep(AI.profile.short_action_delay * AI.profile.action_delay_mult)
	return can_continue()

/datum/human_ai_weapon_context/proc/sleep_micro()
	sleep(AI.profile.micro_action_delay * AI.profile.action_delay_mult)
	return can_continue()
