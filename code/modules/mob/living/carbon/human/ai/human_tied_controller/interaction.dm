// Raw movement interaction primitives

/datum/human_tied_controller/proc/get_move_blockers(turf/next_turf)
	if(!is_tied_human_loaded() || !next_turf)
		return null
	var/list/blockers = LinkBlocked(tied_human, tied_human.loc, next_turf, list(tied_human), TRUE)
	blockers += SSpathfinding.check_special_blockers(tied_human, next_turf)
	return blockers

/datum/human_tied_controller/proc/get_obstacle_cost(atom/obstacle, direction, turf/target)
	if(!can_read_puppet() || !obstacle)
		return INFINITY
	return obstacle.human_ai_obstacle(tied_human, brain, direction, target)

/datum/human_tied_controller/proc/act_on(atom/target)
	if(!can_directly_control() || !target)
		return FALSE
	return target.human_ai_act(tied_human, brain)

/datum/human_tied_controller/proc/act_on_blocker(atom/obstacle)
	if(!can_directly_control() || !obstacle)
		return FALSE
	INVOKE_ASYNC(obstacle, TYPE_PROC_REF(/atom, human_ai_act), tied_human, brain)
	return TRUE

// Behavior/migration helpers

// Helper for reconstructing the old blocker interaction loop during migration.
/datum/human_tied_controller/proc/act_on_blockers(list/blockers)
	if(!can_directly_control() || !length(blockers))
		return FALSE
	for(var/a in blockers)
		var/atom/obstacle = a
		act_on_blocker(obstacle)
	return TRUE

// Access primitives

/datum/human_tied_controller/proc/can_ignore_access()
	return can_read_puppet() && iszombie(tied_human)

/datum/human_tied_controller/proc/can_access_with_active_hand(atom/door)
	if(!can_read_puppet() || !door || !hascall(door, "check_access"))
		return FALSE
	return call(door, "check_access")(tied_human.get_active_hand())

/datum/human_tied_controller/proc/can_access_with_id(atom/door)
	if(!can_read_puppet() || !door || !hascall(door, "check_access"))
		return FALSE
	return call(door, "check_access")(tied_human.wear_id)

// Behavior/migration helpers

// Helper for reconstructing the old door access behavior during migration.
/datum/human_tied_controller/proc/can_access(atom/door)
	return can_ignore_access() || can_access_with_active_hand(door) || can_access_with_id(door)

// Raw item interaction primitives

/datum/human_tied_controller/proc/can_use_item(obj/item/item, atom/target)
	if(!can_directly_control() || !item)
		return FALSE
	if(target)
		return item.ai_can_use(tied_human, brain, target)
	return item.ai_can_use(tied_human, brain)

/datum/human_tied_controller/proc/ai_use(obj/item/item, atom/target)
	if(!can_directly_control() || !item)
		return FALSE
	if(target)
		return item.ai_use(tied_human, brain, target)
	return item.ai_use(tied_human, brain)

// Raw communication/action primitives

/datum/human_tied_controller/proc/resist()
	if(!can_directly_control())
		return FALSE
	INVOKE_ASYNC(tied_human, TYPE_VERB_REF(/mob/living, resist))
	return TRUE

/datum/human_tied_controller/proc/say(message)
	if(!can_mutate_puppet() || !message)
		return FALSE
	tied_human.say(message)
	return TRUE

/datum/human_tied_controller/proc/turn_to_conversation_partner(mob/living/carbon/human/partner)
	if(!can_directly_control() || !partner)
		return FALSE
	tied_human.setDir(get_cardinal_dir(tied_human, partner))
	return TRUE
