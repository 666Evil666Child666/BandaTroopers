/datum/ai_action/throw_back_nade
	name = "Throw Back Grenade"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/grenade, /datum/human_ai_module/inventory)
	var/min_safe_throw_distance = 4 // SS220 EDIT: throw-back should not deliberately choose turf inside the expected grenade danger radius
	var/throw_ready_time = 0 // SS220 EDIT: picked-up timed grenades roll a random hold window before the actual throw
	var/mid_throw = FALSE // SS220 EDIT: transient async state keeps trigger_action() no-sleep while the real throw runs separately
	var/throw_finished = FALSE // SS220 EDIT: transient async state completes the action on the next scheduler tick

/datum/ai_action/throw_back_nade/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return 0

	if(!brain.can_throw_back_grenade()) // SS220 EDIT: weak AI presets must not enter throw-back mode
		return 0

	var/obj/item/explosive/grenade/active_grenade_found = brain.get_active_grenade()
	if(QDELETED(active_grenade_found))
		return 0

	if(controller.get_distance_to(active_grenade_found) > 4)
		return 0

	return 50

/datum/ai_action/throw_back_nade/Destroy(force, ...)
	var/datum/human_ai_brain/brain = context?.brain
	brain?.clear_active_grenade()
	throw_ready_time = 0
	mid_throw = FALSE
	throw_finished = FALSE
	return ..()

/datum/ai_action/throw_back_nade/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	if(!brain)
		return ONGOING_ACTION_COMPLETED

	if(throw_finished)
		return ONGOING_ACTION_COMPLETED

	if(mid_throw)
		return ONGOING_ACTION_UNFINISHED

	var/obj/item/explosive/grenade/active_grenade_found = brain.get_active_grenade()
	var/datum/human_ai_throwable_context/throwable_context = new(brain, active_grenade_found)
	throwable_context.min_safe_throw_distance = min_safe_throw_distance
	var/result = GLOB.human_ai_grenade_throw_back_handler.continue_throw_back(throwable_context, src)
	qdel(throwable_context)
	return result
