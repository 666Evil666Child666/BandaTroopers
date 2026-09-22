// Human AI action runtime API.
// Action queue, action blacklists, and currently running action state.

/datum/human_ai_brain/proc/cancel_ongoing_actions_by_type(list/action_types, datum/ai_action/except_action = null)
	var/datum/human_ai_module/action_runtime/action_runtime_module = get_action_runtime_module()
	if(!length(action_types) || !action_runtime_module)
		return

	var/list/actions_to_cancel = action_runtime_module.ongoing_actions.Copy()
	for(var/datum/ai_action/ongoing_action as anything in actions_to_cancel)
		if(!(ongoing_action in action_runtime_module.ongoing_actions))
			continue
		if((ongoing_action != except_action) && (ongoing_action.type in action_types))
			qdel(ongoing_action)

/datum/human_ai_brain/proc/remove_ongoing_action(datum/ai_action/action)
	var/datum/human_ai_module/action_runtime/action_runtime_module = get_action_runtime_module()
	if(action_runtime_module)
		action_runtime_module.ongoing_actions -= action

/datum/human_ai_brain/proc/has_ongoing_action(action_type)
	var/datum/human_ai_module/action_runtime/action_runtime_module = get_action_runtime_module()
	return action_runtime_module?.has_ongoing_action(action_type)

/datum/human_ai_brain/proc/add_action_blacklist(list/action_types)
	var/datum/human_ai_module/action_runtime/action_runtime_module = get_action_runtime_module()
	if(!length(action_types) || !action_runtime_module)
		return
	if(!action_runtime_module.action_blacklist)
		action_runtime_module.action_blacklist = list()
	for(var/action_type as anything in action_types)
		action_runtime_module.action_blacklist |= action_type
	cancel_ongoing_actions_by_type(action_types)

/datum/human_ai_brain/proc/remove_action_blacklist(list/action_types)
	var/datum/human_ai_module/action_runtime/action_runtime_module = get_action_runtime_module()
	if(!length(action_types) || !action_runtime_module?.action_blacklist)
		return
	for(var/action_type as anything in action_types)
		action_runtime_module.action_blacklist -= action_type
	if(!length(action_runtime_module.action_blacklist))
		action_runtime_module.action_blacklist = null

/datum/human_ai_brain/proc/has_ongoing_throw_action_in_progress()
	var/datum/human_ai_module/action_runtime/action_runtime_module = get_action_runtime_module()
	if(!action_runtime_module)
		return FALSE
	for(var/datum/ai_action/ongoing_action as anything in action_runtime_module.ongoing_actions.Copy())
		if(!(ongoing_action in action_runtime_module.ongoing_actions))
			continue
		if(istype(ongoing_action, /datum/ai_action/throw_grenade))
			var/datum/ai_action/throw_grenade/throw_grenade_action = ongoing_action
			if(throw_grenade_action.mid_throw)
				return TRUE

		if(istype(ongoing_action, /datum/ai_action/throw_back_nade))
			var/datum/ai_action/throw_back_nade/throw_back_action = ongoing_action
			if(throw_back_action.mid_throw)
				return TRUE

	return FALSE
