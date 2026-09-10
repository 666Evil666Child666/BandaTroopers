/datum/ai_action/throw_grenade
	name = "Throw Grenade"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS // SS220 EDIT: grenade priming/throwing should own both hand and movement slots until it resolves
	required_ai_modules = list(/datum/human_ai_module/grenade, /datum/human_ai_module/inventory, /datum/human_ai_module/targeting, /datum/human_ai_module/combat, /datum/human_ai_module/guns, /datum/human_ai_module/action_runtime)
	var/obj/item/explosive/grenade/throwing
	var/mid_throw = FALSE
	var/throw_finished = FALSE
	var/throw_range_override = null

/datum/ai_action/throw_grenade/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !controller || !inventory)
		return 0

	if(!brain.can_throw_grenades())
		return 0

	if(!brain.is_in_combat())
		return 0

	var/turf/target_turf = brain.get_target_turf()
	if(!target_turf)
		return 0

	if(!inventory.find_grenade_for_throw())
		return 0

	if(!inventory.has_primary_weapon())
		return 10

	if(locate(/turf/closed) in controller.get_line_to(target_turf))
		return 10

	return 0

/datum/ai_action/throw_grenade/get_context_conflicts(datum/human_ai_context/context)
	. = ..()
	. += /datum/ai_action/chase_target
	. += /datum/ai_action/sniper_nest

/datum/ai_action/throw_grenade/Added()
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !inventory)
		return

	var/datum/human_ai_throwable_context/throwable_context = new(brain)
	throwing = GLOB.human_ai_grenade_throw_handler.prepare_grenade_for_throw(throwable_context, inventory.find_grenade_for_throw())
	throw_range_override = isnum(throwing?.throw_range) ? throwing.throw_range : null
	log_game("AI GRENADE: throw action created - grenade=[throwing] ([throwing?.type]), available=[inventory.get_equipment_summary(HUMAN_AI_GRENADES)], throw_range=[throw_range_override], mob=[controller?.get_key_name()]")
	qdel(throwable_context)
	cancel_conflicting_actions()

/datum/ai_action/throw_grenade/Destroy(force, ...)
	throwing = null
	mid_throw = FALSE
	throw_finished = FALSE
	throw_range_override = null
	return ..()

/datum/ai_action/throw_grenade/proc/cancel_conflicting_actions()
	var/datum/human_ai_brain/brain = context?.brain
	if(!brain)
		return

	brain.cancel_ongoing_actions_by_type(get_context_conflicts(context), src)

/datum/ai_action/throw_grenade/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain)
		return ONGOING_ACTION_COMPLETED

	if(throw_finished)
		return ONGOING_ACTION_COMPLETED

	if(mid_throw)
		return ONGOING_ACTION_UNFINISHED_BLOCK

	var/turf/target_turf = brain.get_target_turf()
	if(QDELETED(throwing) || !target_turf)
		log_game("AI GRENADE: throw action aborted - grenade missing or no target, QDELETED=[QDELETED(throwing)], target=[target_turf], mob=[controller?.get_key_name()]")
		return ONGOING_ACTION_COMPLETED

	var/datum/human_ai_throwable_context/throwable_context = new(brain, throwing, brain.get_current_target(), target_turf, throw_range_override)
	cancel_conflicting_actions() // SS220 EDIT: cancel any already-running move/fire/reload actions before the grenade is primed
	if(!GLOB.human_ai_grenade_throw_handler.start_throw(throwable_context, src))
		qdel(throwable_context)
		return ONGOING_ACTION_COMPLETED

	throw_range_override = throwable_context.throw_range_override
	qdel(throwable_context)
	return ONGOING_ACTION_UNFINISHED_BLOCK
