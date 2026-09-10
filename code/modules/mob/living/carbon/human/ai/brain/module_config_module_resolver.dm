// Human AI module selection and dependency expansion.

// ==================== Default composition ====================
// Full legacy Human AI module set used when a preset has no explicit action policy.
/datum/human_ai_module_config/proc/get_default_module_types()
	return list(
		/datum/human_ai_module/faction,
		/datum/human_ai_module/targeting,
		/datum/human_ai_module/cover,
		/datum/human_ai_module/grenade,
		/datum/human_ai_module/health,
		/datum/human_ai_module/communication,
		/datum/human_ai_module/guns,
		/datum/human_ai_module/navigation,
		/datum/human_ai_module/squad,
		/datum/human_ai_module/action_runtime,
		/datum/human_ai_module/combat,
		/datum/human_ai_module/conversation,
		/datum/human_ai_module/orders,
		/datum/human_ai_module/profile,
		/datum/human_ai_module/emplacement,
		/datum/human_ai_module/admin,
		/datum/human_ai_module/perception,
		/datum/human_ai_module/inventory,
	)

/datum/human_ai_module_config/proc/get_core_module_types()
	return list(
		/datum/human_ai_module/action_runtime,
		/datum/human_ai_module/admin,
	)

// ==================== Action-driven composition ====================
// Converts preset action whitelist/blacklist into the module set required to run those actions.
/datum/human_ai_module_config/proc/get_module_types_to_setup()
	if(!has_explicit_action_policy())
		return get_default_module_types()

	if(isnull(action_whitelist))
		return get_default_module_types()

	if(!length(action_whitelist))
		return get_core_module_types()

	var/list/module_types = get_expanded_module_types(get_core_module_types())
	var/list/action_types = action_whitelist.Copy()
	action_types -= action_blacklist

	for(var/action_type as anything in action_types)
		if(!ispath(action_type, /datum/ai_action))
			report_action_policy_issue("invalid action path [action_type]")
			continue

		var/datum/ai_action/action = GLOB.AI_actions[action_type]
		if(!action)
			report_action_policy_issue("missing registered action [action_type]")
			continue

		for(var/module_type as anything in action.required_ai_modules)
			add_module_type(module_types, module_type)

	return module_types

// ==================== Dependency expansion ====================
// Recursively adds required modules before the module that depends on them.
/datum/human_ai_module_config/proc/get_expanded_module_types(list/requested_module_types)
	var/list/module_types = list()
	for(var/module_type as anything in requested_module_types)
		add_module_type(module_types, module_type)
	return module_types

/datum/human_ai_module_config/proc/add_module_type(list/module_types, module_type)
	if(!ispath(module_type, /datum/human_ai_module))
		report_action_policy_issue("invalid module dependency [module_type]")
		return

	if(module_type in module_types)
		return

	var/list/dependency_types = get_module_dependency_types(module_type)
	for(var/dependency_type as anything in dependency_types)
		add_module_type(module_types, dependency_type)

	module_types += module_type

/datum/human_ai_module_config/proc/get_module_dependency_types(module_type)
	var/datum/human_ai_module/module_path = module_type
	return initial(module_path.required_module_types)

/datum/human_ai_module_config/proc/report_action_policy_issue(message)
	stack_trace("Human AI action policy issue: [message]")

// ==================== Validation ====================
// Reports missing pieces after composition without aborting legacy setup.
/datum/human_ai_module_config/proc/validate_module_setup(datum/human_ai_brain/brain)
	validate_requested_modules(brain)
	validate_action_module_requirements(brain)
	validate_module_dependencies(brain)

/datum/human_ai_module_config/proc/validate_requested_modules(datum/human_ai_brain/brain)
	for(var/module_type as anything in requested_module_types)
		if(!get_module_by_type(brain, module_type))
			report_action_policy_issue("requested module was not created [module_type]")

/datum/human_ai_module_config/proc/validate_action_module_requirements(datum/human_ai_brain/brain)
	if(!has_explicit_action_policy() || !length(action_whitelist))
		return

	var/list/action_types = action_whitelist.Copy()
	action_types -= action_blacklist
	for(var/action_type as anything in action_types)
		var/datum/ai_action/action = GLOB.AI_actions[action_type]
		if(!action)
			continue

		for(var/module_type as anything in action.required_ai_modules)
			if(!get_module_by_type(brain, module_type))
				report_action_policy_issue("action [action_type] missing required module [module_type]")

/datum/human_ai_module_config/proc/validate_module_dependencies(datum/human_ai_brain/brain)
	for(var/datum/human_ai_module/module as anything in owned_modules)
		if(!module.module_id)
			report_action_policy_issue("module [module.type] has no module_id")

		for(var/dependency_type as anything in module.required_module_types)
			if(!get_module_by_type(brain, dependency_type))
				report_action_policy_issue("module [module.type] missing dependency [dependency_type]")
