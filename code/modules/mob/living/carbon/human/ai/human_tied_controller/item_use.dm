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

/datum/human_tied_controller/proc/can_use_item_on_self(obj/item/item)
	if(!can_read_puppet() || !item)
		return FALSE
	return item.ai_can_use(tied_human, brain, tied_human)

/datum/human_tied_controller/proc/ai_use_on_self(obj/item/item)
	if(!can_directly_control() || !item)
		return FALSE
	return item.ai_use(tied_human, brain, tied_human)

// Raw self-healing primitives

/datum/human_tied_controller/proc/healing_start_check_self()
	if(!can_read_puppet() || !brain?.health)
		return FALSE
	return brain.health.healing_start_check(tied_human)

/datum/human_tied_controller/proc/start_healing_self()
	if(!can_directly_control() || !brain?.health)
		return FALSE
	return brain.health.start_healing(tied_human)
