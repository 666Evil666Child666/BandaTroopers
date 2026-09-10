// Human AI module construction, ownership, and lookup by module type.

// ==================== Ownership ====================
// The config owns modules it creates; teardown deletes this list.
/datum/human_ai_module_config/proc/register_module(datum/human_ai_module/module)
	if(!module)
		return null

	LAZYOR(owned_modules, module)
	LAZYINITLIST(modules_by_type)
	if(modules_by_type[module.type] && (modules_by_type[module.type] != module))
		report_action_policy_issue("duplicate module type registration [module.type]")
	modules_by_type[module.type] = module
	if(module.module_id)
		LAZYINITLIST(modules_by_id)
		if(modules_by_id[module.module_id] && (modules_by_id[module.module_id] != module))
			report_action_policy_issue("duplicate module id registration [module.module_id]")
		modules_by_id[module.module_id] = module
	return module

// ==================== Factory ====================
// Creates a module for a known module type and stores it in the brain's typed module slot.
/datum/human_ai_module_config/proc/setup_module_by_type(datum/human_ai_brain/brain, module_type)
	var/datum/human_ai_module/module
	switch(module_type)
		if(/datum/human_ai_module/faction)
			module = new /datum/human_ai_module/faction(brain)
			brain.faction = module
		if(/datum/human_ai_module/targeting)
			module = new /datum/human_ai_module/targeting(brain)
			brain.targeting = module
		if(/datum/human_ai_module/cover)
			module = new /datum/human_ai_module/cover(brain)
			brain.cover = module
		if(/datum/human_ai_module/grenade)
			module = new /datum/human_ai_module/grenade(brain)
			brain.grenade = module
		if(/datum/human_ai_module/health)
			module = new /datum/human_ai_module/health(brain)
			brain.health = module
		if(/datum/human_ai_module/communication)
			module = new /datum/human_ai_module/communication(brain)
			brain.communication = module
		if(/datum/human_ai_module/guns)
			module = new /datum/human_ai_module/guns(brain)
			brain.guns = module
		if(/datum/human_ai_module/navigation)
			module = new /datum/human_ai_module/navigation(brain)
			brain.navigation = module
		if(/datum/human_ai_module/squad)
			module = new /datum/human_ai_module/squad(brain)
			brain.squad = module
		if(/datum/human_ai_module/action_runtime)
			module = new /datum/human_ai_module/action_runtime(brain)
			brain.action_runtime = module
		if(/datum/human_ai_module/combat)
			module = new /datum/human_ai_module/combat(brain)
			brain.combat = module
		if(/datum/human_ai_module/conversation)
			module = new /datum/human_ai_module/conversation(brain)
			brain.conversation = module
		if(/datum/human_ai_module/orders)
			module = new /datum/human_ai_module/orders(brain)
			brain.orders = module
		if(/datum/human_ai_module/profile)
			module = new /datum/human_ai_module/profile(brain)
			brain.profile = module
		if(/datum/human_ai_module/emplacement)
			module = new /datum/human_ai_module/emplacement(brain)
			brain.emplacement = module
		if(/datum/human_ai_module/admin)
			module = new /datum/human_ai_module/admin(brain)
			brain.admin = module
		if(/datum/human_ai_module/perception)
			module = new /datum/human_ai_module/perception(brain)
			brain.perception = module
		if(/datum/human_ai_module/inventory)
			module = new /datum/human_ai_module/inventory(brain)
			brain.inventory = module

	if(!module)
		report_action_policy_issue("unknown module factory type [module_type]")
		return null

	return register_module(module)

// ==================== Lookup ====================
// Reads the registry source of truth for a known module type.
/datum/human_ai_module_config/proc/get_module_by_type(datum/human_ai_brain/brain, module_type)
	if(!modules_by_type)
		return null
	return modules_by_type[module_type]

/datum/human_ai_module_config/proc/get_module_by_id(module_id)
	if(!modules_by_id)
		return null
	return modules_by_id[module_id]

// ==================== Dispatch lists ====================
// Builds ordered process/event lists while omitting modules that were not composed for this brain.
/datum/human_ai_module_config/proc/build_module_list(datum/human_ai_brain/brain, list/module_types)
	var/list/module_list = list()
	for(var/module_type as anything in module_types)
		var/datum/human_ai_module/module = get_module_by_type(brain, module_type)
		if(module)
			module_list += module

	return module_list

/datum/human_ai_module_config/proc/register_module_list_for_event(datum/human_ai_brain/brain, event_type, list/module_types)
	for(var/datum/human_ai_module/module as anything in build_module_list(brain, module_types))
		brain.register_ai_event_subscriber(event_type, module)
