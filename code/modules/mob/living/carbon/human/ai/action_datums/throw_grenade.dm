/datum/ai_action/throw_grenade
	name = "Throw Grenade"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS // SS220 EDIT: grenade priming/throwing should own both hand and movement slots until it resolves
	var/obj/item/explosive/grenade/throwing
	var/mid_throw = FALSE
	var/throw_finished = FALSE
	var/throw_range_override = null

/datum/ai_action/throw_grenade/get_weight(datum/human_ai_brain/brain)
	if(!brain.grenade.can_throw_grenades())
		return 0

	if(!brain.combat.in_combat)
		return 0

	var/turf/target_turf = brain.targeting.get_target_turf()
	if(!target_turf)
		return 0

	if(!brain.inventory.find_grenade_for_throw())
		return 0

	if(!brain.inventory.has_primary_weapon())
		return 10

	if(locate(/turf/closed) in brain.tied_controller.get_line_to(target_turf))
		return 10

	return 0

/datum/ai_action/throw_grenade/get_conflicts(datum/human_ai_brain/brain)
	. = ..()
	. += /datum/ai_action/chase_target
	. += /datum/ai_action/sniper_nest

/datum/ai_action/throw_grenade/Added()
	var/datum/human_ai_throwable_context/context = new(brain)
	throwing = GLOB.human_ai_grenade_throw_handler.prepare_grenade_for_throw(context, brain.inventory.find_grenade_for_throw())
	throw_range_override = isnum(throwing?.throw_range) ? throwing.throw_range : null
	log_game("AI GRENADE: throw action created - grenade=[throwing] ([throwing?.type]), available=[brain?.inventory?.get_equipment_summary(HUMAN_AI_GRENADES)], throw_range=[throw_range_override], mob=[brain?.tied_controller?.get_key_name()]")
	qdel(context)
	cancel_conflicting_actions()

/datum/ai_action/throw_grenade/Destroy(force, ...)
	throwing = null
	mid_throw = FALSE
	throw_finished = FALSE
	throw_range_override = null
	return ..()

/datum/ai_action/throw_grenade/proc/cancel_conflicting_actions()
	if(!brain)
		return

	var/list/conflicts = get_conflicts(brain)
	for(var/datum/ai_action/conflicting_action as anything in brain.action_runtime.ongoing_actions)
		if((conflicting_action != src) && (conflicting_action.type in conflicts))
			qdel(conflicting_action)

/datum/ai_action/throw_grenade/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	if(throw_finished)
		return ONGOING_ACTION_COMPLETED

	if(mid_throw)
		return ONGOING_ACTION_UNFINISHED_BLOCK

	var/turf/target_turf = brain.targeting.get_target_turf()
	if(QDELETED(throwing) || !target_turf)
		log_game("AI GRENADE: throw action aborted - grenade missing or no target, QDELETED=[QDELETED(throwing)], target=[target_turf], mob=[brain?.tied_controller?.get_key_name()]")
		return ONGOING_ACTION_COMPLETED

	var/datum/human_ai_throwable_context/context = new(brain, throwing, brain.targeting.get_current_target(), target_turf, throw_range_override)
	cancel_conflicting_actions() // SS220 EDIT: cancel any already-running move/fire/reload actions before the grenade is primed
	if(!GLOB.human_ai_grenade_throw_handler.start_throw(context, src))
		qdel(context)
		return ONGOING_ACTION_COMPLETED

	throw_range_override = context.throw_range_override
	qdel(context)
	return ONGOING_ACTION_UNFINISHED_BLOCK
