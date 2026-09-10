// Shared Human AI weapon-use context.

/datum/human_ai_weapon_context
	var/datum/human_ai_brain/AI
	var/datum/human_ai_context/ai_context
	var/datum/human_tied_controller/controller
	var/obj/item/weapon_item
	var/atom/movable/current_target
	var/turf/target_turf

/datum/human_ai_weapon_context/New(datum/human_ai_brain/new_ai, obj/item/new_weapon_item = null, atom/movable/new_current_target = null, turf/new_target_turf = null)
	AI = new_ai
	ai_context = AI?.create_context()
	controller = ai_context?.controller
	weapon_item = new_weapon_item
	current_target = new_current_target
	target_turf = new_target_turf

/datum/human_ai_weapon_context/Destroy(force, ...)
	QDEL_NULL(ai_context)
	AI = null
	controller = null
	weapon_item = null
	current_target = null
	target_turf = null
	return ..()

/datum/human_ai_weapon_context/proc/get_inventory()
	RETURN_TYPE(/datum/human_ai_module/inventory)
	return ai_context?.get_module(/datum/human_ai_module/inventory)

/datum/human_ai_weapon_context/proc/is_valid()
	return AI?.can_continue_runtime_work() && controller

/datum/human_ai_weapon_context/proc/can_continue(obj/item/item = weapon_item)
	if(!is_valid())
		return FALSE
	if(item && QDELETED(item))
		return FALSE
	return TRUE

/datum/human_ai_weapon_context/proc/sleep_short()
	sleep(AI.get_action_delay())
	return can_continue()

/datum/human_ai_weapon_context/proc/sleep_micro()
	sleep(AI.get_micro_action_delay())
	return can_continue()
