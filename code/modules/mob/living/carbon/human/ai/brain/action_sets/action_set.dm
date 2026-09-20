// Reusable Human AI action policy objects; presets can select one and optionally override it.

/datum/human_ai_action_set
	var/list/included_action_set_types = list()
	var/list/action_whitelist = list()
	var/list/action_blacklist = list()

/datum/human_ai_action_set/proc/get_action_whitelist(list/resolving_action_set_types = null)
	if(!resolving_action_set_types)
		resolving_action_set_types = list()
	if(type in resolving_action_set_types)
		stack_trace("Human AI action set issue: cyclic included action set [type]")
		return list()

	resolving_action_set_types += type
	var/list/resolved_actions = list()
	for(var/action_set_type as anything in included_action_set_types)
		if(!ispath(action_set_type, /datum/human_ai_action_set))
			stack_trace("Human AI action set issue: invalid included action set [action_set_type]")
			continue

		var/datum/human_ai_action_set/action_set = new action_set_type()
		resolved_actions |= action_set.get_action_whitelist(resolving_action_set_types)
		qdel(action_set)

	resolving_action_set_types -= type
	resolved_actions |= action_whitelist
	return resolved_actions

/datum/human_ai_action_set/proc/get_action_blacklist(list/resolving_action_set_types = null)
	if(!resolving_action_set_types)
		resolving_action_set_types = list()
	if(type in resolving_action_set_types)
		stack_trace("Human AI action set issue: cyclic included action set [type]")
		return list()

	resolving_action_set_types += type
	var/list/resolved_actions = list()
	for(var/action_set_type as anything in included_action_set_types)
		if(!ispath(action_set_type, /datum/human_ai_action_set))
			stack_trace("Human AI action set issue: invalid included action set [action_set_type]")
			continue

		var/datum/human_ai_action_set/action_set = new action_set_type()
		resolved_actions |= action_set.get_action_blacklist(resolving_action_set_types)
		qdel(action_set)

	resolving_action_set_types -= type
	resolved_actions |= action_blacklist
	return resolved_actions

/datum/human_ai_action_set/movement
	action_whitelist = list(
		/datum/ai_action/chase_target,
		/datum/ai_action/follow_leader,
		/datum/ai_action/investigate_lost_target,
		/datum/ai_action/patrol_waypoints,
		/datum/ai_action/quick_approach,
	)

/datum/human_ai_action_set/combat
	action_whitelist = list(
		/datum/ai_action/fire_at_target,
		/datum/ai_action/keep_distance,
		/datum/ai_action/reload,
		/datum/ai_action/select_primary,
	)

/datum/human_ai_action_set/survival
	action_whitelist = list(
		/datum/ai_action/resist_burning,
		/datum/ai_action/take_cover,
		/datum/ai_action/treat_ally,
		/datum/ai_action/treat_self,
	)

/datum/human_ai_action_set/grenade
	action_whitelist = list(
		/datum/ai_action/throw_back_nade,
		/datum/ai_action/throw_grenade,
	)

/datum/human_ai_action_set/melee
	action_whitelist = list(
		/datum/ai_action/walk_melee,
	)

/datum/human_ai_action_set/emplacement
	action_whitelist = list(
		/datum/ai_action/machinegunner_nest,
		/datum/ai_action/sniper_nest,
	)

/datum/human_ai_action_set/default
	included_action_set_types = list(
		/datum/human_ai_action_set/movement,
		/datum/human_ai_action_set/combat,
		/datum/human_ai_action_set/survival,
		/datum/human_ai_action_set/grenade,
		/datum/human_ai_action_set/melee,
		/datum/human_ai_action_set/emplacement,
	)
	action_whitelist = list(
		/datum/ai_action/converse,
		/datum/ai_action/item_pickup,
	)
