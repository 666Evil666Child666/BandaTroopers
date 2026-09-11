/datum/human_ai_module/action_runtime
	module_id = "action_runtime"

	/// List of whitelisted/blacklisted action datums
	var/list/action_whitelist = null
	var/list/action_blacklist = null

	/// List of current action datums
	var/list/ongoing_actions = list()

/datum/human_ai_module/action_runtime/proc/clear_actions()
	for(var/action in ongoing_actions)
		qdel(action)

	ongoing_actions.Cut()

/datum/human_ai_module/action_runtime/reset_module()
	clear_actions()

/datum/human_ai_module/action_runtime/suspend_module(clear_inventory = FALSE)
	clear_actions()

/datum/human_ai_module/action_runtime/process_module(delta_time)
	return process_actions(delta_time)

/datum/human_ai_module/action_runtime/proc/has_ongoing_action(path)
	if(!ispath(path))
		return FALSE

	for(var/datum/ai_action/action as anything in ongoing_actions)
		if(istype(action, path))
			return TRUE

	return FALSE

/datum/human_ai_module/action_runtime/proc/process_actions(delta_time)
	var/datum/human_ai_context/runtime_context = brain.create_context()
	if(!runtime_context.can_continue())
		qdel(runtime_context)
		return FALSE

	// List all allowed action types for AI to consider
	var/list/allowed_actions = action_whitelist ? action_whitelist.Copy() : GLOB.AI_actions.Copy() // SS220 EDIT: runtime selection must not mutate preset whitelists
	allowed_actions -= action_blacklist
	for(var/datum/ongoing_action as anything in ongoing_actions)
		if(is_type_in_list(ongoing_action, allowed_actions))
			allowed_actions -= ongoing_action.type

	var/grenade_throw_in_progress = brain.has_throw_in_progress()

	// Create assoc list of selected AI actions and their weight
	var/list/possible_actions = list()
	for(var/action_type in shuffle(allowed_actions))
		var/datum/ai_action/glob_ref = GLOB.AI_actions[action_type]
		if(!glob_ref)
			continue
		// SS220 EDIT: skip hand-using actions while a grenade throw is in async flight
		if(grenade_throw_in_progress && (glob_ref.action_flags & ACTION_USING_HANDS))
			continue
		var/weight = glob_ref.get_context_weight(runtime_context)
		if(weight) // No weight means we shouldn't consider this action at all
			possible_actions[action_type] = weight

	// Sorts all allowed actions by their weight
	var/list/sorted_actions = sortTim(possible_actions, GLOBAL_PROC_REF(cmp_numeric_dsc), TRUE)

	// Choose what actions to start in current process() iteration
	for(var/action_type as anything in sorted_actions)
		var/datum/ai_action/possible_action = GLOB.AI_actions[action_type]

		var/list/conflicting_actions = possible_action.get_context_conflicts(runtime_context)
		for(var/datum/ai_action/ongoing_action as anything in ongoing_actions)
			if(ongoing_action.type in conflicting_actions)
				possible_action = null
				break

		if(!possible_action)
			continue

		ongoing_actions += new action_type(brain)
#if defined(TESTING) && defined(HUMAN_AI_TESTING)
		message_admins("action of type [action_type] was added to [runtime_context.controller.get_real_name()]")
#endif

	for(var/datum/ai_action/action as anything in ongoing_actions)
		if(!action.brain)
			ongoing_actions -= action
			continue
		// SS220 EDIT: suppress hand-using actions while a grenade throw is in async flight
		if(grenade_throw_in_progress && (action.action_flags & ACTION_USING_HANDS))
			continue
		var/retval = action.trigger_action()
		switch(retval)
			if(ONGOING_ACTION_UNFINISHED_BLOCK)
				qdel(runtime_context)
				return TRUE
			if(ONGOING_ACTION_COMPLETED)
				qdel(action)

	qdel(runtime_context)
	return FALSE
