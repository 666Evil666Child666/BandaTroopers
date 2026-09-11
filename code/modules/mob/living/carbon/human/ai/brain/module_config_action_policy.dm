// Human AI action policy configured by equipment presets.

// ==================== Preset fields ====================
// Presets expose action policy; configs consume it during module composition.
/datum/equipment_preset
	var/human_ai_module_config_type = /datum/human_ai_module_config/default // SS220 EDIT: Human AI module composition surface
	var/human_ai_action_set_type = /datum/human_ai_action_set/default // SS220 EDIT: Human AI action set composition surface
	var/list/human_ai_action_whitelist // SS220 EDIT: Human AI action composition surface
	var/list/human_ai_action_blacklist // SS220 EDIT: Human AI action composition surface

// ==================== Preset policy hooks ====================
// Subtypes can override these instead of manually deciding which modules to spawn.
/datum/equipment_preset/proc/get_human_ai_action_whitelist()
	return human_ai_action_whitelist?.Copy()

/datum/equipment_preset/proc/get_human_ai_action_blacklist()
	return human_ai_action_blacklist?.Copy()

// ==================== Config policy state ====================
// Reads and tracks the preset policy for one brain setup pass.
/datum/human_ai_module_config/proc/create_action_set(action_set_type = /datum/human_ai_action_set/default)
	if(!ispath(action_set_type, /datum/human_ai_action_set))
		action_set_type = /datum/human_ai_action_set/default
	return new action_set_type()

/datum/human_ai_module_config/proc/read_action_policy(datum/equipment_preset/preset)
	var/datum/human_ai_action_set/action_set = create_action_set(preset?.human_ai_action_set_type)
	action_whitelist = action_set.get_action_whitelist()
	action_blacklist = action_set.get_action_blacklist()
	qdel(action_set)

	var/list/preset_action_whitelist = preset?.get_human_ai_action_whitelist()
	if(!isnull(preset_action_whitelist))
		action_whitelist = preset_action_whitelist

	var/list/preset_action_blacklist = preset?.get_human_ai_action_blacklist()
	if(!isnull(preset_action_blacklist))
		if(isnull(action_blacklist))
			action_blacklist = preset_action_blacklist
		else
			action_blacklist |= preset_action_blacklist

/datum/human_ai_module_config/proc/has_explicit_action_policy()
	return !isnull(action_whitelist) || !isnull(action_blacklist)
