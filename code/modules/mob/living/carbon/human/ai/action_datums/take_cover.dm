/datum/ai_action/take_cover
	name = "Take Cover"
	action_flags = ACTION_USING_LEGS

/datum/ai_action/take_cover/get_weight(datum/human_ai_brain/brain)
	if(!brain.has_valid_tied_human()) // SS220 EDIT: upstream cover action must not score after modular owner teardown
		return 0

	if(!brain.cover.current_cover)
		return 0

	if(!brain.orders.can_move_for_action())
		return 0

	if(brain.cover.in_cover && !(get_dist(brain.tied_human, brain.targeting.current_target) > brain?.inventory?.gun_data?.minimum_range))
		return 0

	return 15

/datum/ai_action/take_cover/trigger_action()
	. = ..()
	if(!brain || !brain.has_valid_tied_human()) // SS220 EDIT: cover movement exits cleanly if the modular AI owner vanishes mid-action
		return ONGOING_ACTION_COMPLETED

	var/turf/current_cover = brain.cover.current_cover
	if(!brain.cover.current_cover)
		return ONGOING_ACTION_COMPLETED

	var/mob/living/carbon/human/tied_human = brain.tied_human

#if defined(TESTING) || defined(HUMAN_AI_TESTING)
	current_cover.color = "#b80505"
	current_cover.maptext = "[tied_human.real_name] | [get_dist(current_cover, tied_human)]"
#endif

	if(get_dist(current_cover, tied_human) > 0)
		if(!brain.navigation.move_to_next_turf(current_cover))
			brain.cover.end_cover()
			return ONGOING_ACTION_COMPLETED

		if(!brain || !brain.has_valid_tied_human())
			return ONGOING_ACTION_COMPLETED

		tied_human = brain.tied_human
		if(get_dist(current_cover, tied_human) > 0)
			return ONGOING_ACTION_UNFINISHED

	brain.cover.in_cover = TRUE
	return ONGOING_ACTION_COMPLETED
