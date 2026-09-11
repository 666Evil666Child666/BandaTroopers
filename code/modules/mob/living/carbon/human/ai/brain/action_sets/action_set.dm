// Reusable Human AI action policy objects; presets can select one and optionally override it.

/datum/human_ai_action_set
	var/list/action_whitelist
	var/list/action_blacklist

/datum/human_ai_action_set/proc/get_action_whitelist()
	return action_whitelist?.Copy()

/datum/human_ai_action_set/proc/get_action_blacklist()
	return action_blacklist?.Copy()

/datum/human_ai_action_set/default
