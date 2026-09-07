/datum/equipment_preset
	var/human_ai_module_config_type = /datum/human_ai_module_config/default // SS220 EDIT: Human AI module composition surface
	var/list/human_ai_action_whitelist // SS220 EDIT: Human AI action composition surface
	var/list/human_ai_action_blacklist // SS220 EDIT: Human AI action composition surface

/datum/equipment_preset/proc/get_human_ai_action_whitelist()
	return human_ai_action_whitelist?.Copy()

/datum/equipment_preset/proc/get_human_ai_action_blacklist()
	return human_ai_action_blacklist?.Copy()

/datum/human_ai_module_config
	var/list/datum/human_ai_module/owned_modules
	var/list/action_whitelist
	var/list/action_blacklist

/datum/human_ai_module_config/Destroy(force, ...)
	QDEL_LIST(owned_modules)
	owned_modules = null
	action_whitelist = null
	action_blacklist = null
	return ..()

/datum/human_ai_module_config/proc/register_module(datum/human_ai_module/module)
	if(!module)
		return null

	LAZYOR(owned_modules, module)
	return module

/datum/human_ai_module_config/proc/setup_brain(datum/human_ai_brain/brain, mob/living/carbon/human/new_human)
	return

/datum/human_ai_module_config/proc/read_action_policy(datum/equipment_preset/preset)
	action_whitelist = preset?.get_human_ai_action_whitelist()
	action_blacklist = preset?.get_human_ai_action_blacklist()

/datum/human_ai_module_config/proc/has_explicit_action_policy()
	return !isnull(action_whitelist) || !isnull(action_blacklist)

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
		/datum/human_ai_module/perception,
		/datum/human_ai_module/inventory,
	)

/datum/human_ai_module_config/proc/get_core_module_types()
	return list(
		/datum/human_ai_module/action_runtime,
	)

/datum/human_ai_module_config/proc/get_module_types_to_setup()
	if(!has_explicit_action_policy())
		return get_default_module_types()

	if(!length(action_whitelist))
		return get_default_module_types()

	var/list/module_types = get_expanded_module_types(get_core_module_types())
	var/list/action_types = action_whitelist.Copy()
	action_types -= action_blacklist

	for(var/action_type as anything in action_types)
		var/datum/ai_action/action = GLOB.AI_actions[action_type]
		if(!action)
			continue

		for(var/module_type as anything in action.required_ai_modules)
			add_module_type(module_types, module_type)

	return module_types

/datum/human_ai_module_config/proc/get_expanded_module_types(list/requested_module_types)
	var/list/module_types = list()
	for(var/module_type as anything in requested_module_types)
		add_module_type(module_types, module_type)
	return module_types

/datum/human_ai_module_config/proc/add_module_type(list/module_types, module_type)
	if(!ispath(module_type, /datum/human_ai_module))
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

/datum/human_ai_module_config/proc/setup_module_by_type(datum/human_ai_brain/brain, module_type)
	switch(module_type)
		if(/datum/human_ai_module/faction)
			brain.faction = register_module(new /datum/human_ai_module/faction(brain))
		if(/datum/human_ai_module/targeting)
			brain.targeting = register_module(new /datum/human_ai_module/targeting(brain))
		if(/datum/human_ai_module/cover)
			brain.cover = register_module(new /datum/human_ai_module/cover(brain))
		if(/datum/human_ai_module/grenade)
			brain.grenade = register_module(new /datum/human_ai_module/grenade(brain))
		if(/datum/human_ai_module/health)
			brain.health = register_module(new /datum/human_ai_module/health(brain))
		if(/datum/human_ai_module/communication)
			brain.communication = register_module(new /datum/human_ai_module/communication(brain))
		if(/datum/human_ai_module/guns)
			brain.guns = register_module(new /datum/human_ai_module/guns(brain))
		if(/datum/human_ai_module/navigation)
			brain.navigation = register_module(new /datum/human_ai_module/navigation(brain))
		if(/datum/human_ai_module/squad)
			brain.squad = register_module(new /datum/human_ai_module/squad(brain))
		if(/datum/human_ai_module/action_runtime)
			brain.action_runtime = register_module(new /datum/human_ai_module/action_runtime(brain))
		if(/datum/human_ai_module/combat)
			brain.combat = register_module(new /datum/human_ai_module/combat(brain))
		if(/datum/human_ai_module/conversation)
			brain.conversation = register_module(new /datum/human_ai_module/conversation(brain))
		if(/datum/human_ai_module/orders)
			brain.orders = register_module(new /datum/human_ai_module/orders(brain))
		if(/datum/human_ai_module/profile)
			brain.profile = register_module(new /datum/human_ai_module/profile(brain))
		if(/datum/human_ai_module/emplacement)
			brain.emplacement = register_module(new /datum/human_ai_module/emplacement(brain))
		if(/datum/human_ai_module/perception)
			brain.perception = register_module(new /datum/human_ai_module/perception(brain))
		if(/datum/human_ai_module/inventory)
			brain.inventory = register_module(new /datum/human_ai_module/inventory(brain))

/datum/human_ai_module_config/proc/get_module_by_type(datum/human_ai_brain/brain, module_type)
	switch(module_type)
		if(/datum/human_ai_module/faction)
			return brain.faction
		if(/datum/human_ai_module/targeting)
			return brain.targeting
		if(/datum/human_ai_module/cover)
			return brain.cover
		if(/datum/human_ai_module/grenade)
			return brain.grenade
		if(/datum/human_ai_module/health)
			return brain.health
		if(/datum/human_ai_module/communication)
			return brain.communication
		if(/datum/human_ai_module/guns)
			return brain.guns
		if(/datum/human_ai_module/navigation)
			return brain.navigation
		if(/datum/human_ai_module/squad)
			return brain.squad
		if(/datum/human_ai_module/action_runtime)
			return brain.action_runtime
		if(/datum/human_ai_module/combat)
			return brain.combat
		if(/datum/human_ai_module/conversation)
			return brain.conversation
		if(/datum/human_ai_module/orders)
			return brain.orders
		if(/datum/human_ai_module/profile)
			return brain.profile
		if(/datum/human_ai_module/emplacement)
			return brain.emplacement
		if(/datum/human_ai_module/perception)
			return brain.perception
		if(/datum/human_ai_module/inventory)
			return brain.inventory

	return null

/datum/human_ai_module_config/proc/build_module_list(datum/human_ai_brain/brain, list/module_types)
	var/list/module_list = list()
	for(var/module_type as anything in module_types)
		var/datum/human_ai_module/module = get_module_by_type(brain, module_type)
		if(module)
			module_list += module

	return module_list

/datum/human_ai_module_config/proc/teardown_brain_modules(datum/human_ai_brain/brain)
	QDEL_LIST(owned_modules)
	owned_modules = null
	brain.targeting = null
	brain.perception = null
	brain.cover = null
	brain.faction = null
	brain.inventory = null
	brain.grenade = null
	brain.health = null
	brain.communication = null
	brain.guns = null
	brain.navigation = null
	brain.squad = null
	brain.action_runtime = null
	brain.combat = null
	brain.conversation = null
	brain.orders = null
	brain.profile = null
	brain.emplacement = null
	brain.extension_modules = null

/datum/human_ai_module_config/proc/configure_module_lists(datum/human_ai_brain/brain)
	configure_lifecycle_module_lists(brain)
	configure_process_module_lists(brain)
	configure_event_module_lists(brain)
	configure_query_module_lists(brain)

/datum/human_ai_module_config/proc/configure_lifecycle_module_lists(datum/human_ai_brain/brain)
	return

/datum/human_ai_module_config/proc/configure_process_module_lists(datum/human_ai_brain/brain)
	return

/datum/human_ai_module_config/proc/configure_event_module_lists(datum/human_ai_brain/brain)
	return

/datum/human_ai_module_config/proc/configure_query_module_lists(datum/human_ai_brain/brain)
	return

/datum/human_ai_module_config/default/setup_brain(datum/human_ai_brain/brain, mob/living/carbon/human/new_human)
	read_action_policy(new_human?.assigned_equipment_preset)

	for(var/module_type as anything in get_module_types_to_setup())
		setup_module_by_type(brain, module_type)

	if(brain.action_runtime)
		brain.action_runtime.action_whitelist = action_whitelist?.Copy()
		brain.action_runtime.action_blacklist = action_blacklist?.Copy()
	brain.perception?.register_signals()
	brain.perception?.setup_detection_radius()
	brain.inventory?.register_signals()

/datum/human_ai_module_config/default/configure_lifecycle_module_lists(datum/human_ai_brain/brain)
	brain.reset_modules_before_wake_clear = build_module_list(brain, list(/datum/human_ai_module/health, /datum/human_ai_module/navigation, /datum/human_ai_module/cover, /datum/human_ai_module/perception))
	brain.reset_modules_after_wake_clear = build_module_list(brain, list(/datum/human_ai_module/combat, /datum/human_ai_module/grenade, /datum/human_ai_module/targeting, /datum/human_ai_module/inventory, /datum/human_ai_module/action_runtime))
	brain.suspend_modules_before_wake_clear = build_module_list(brain, list(/datum/human_ai_module/navigation, /datum/human_ai_module/cover, /datum/human_ai_module/perception))
	brain.suspend_modules_after_wake_clear = build_module_list(brain, list(/datum/human_ai_module/combat, /datum/human_ai_module/grenade, /datum/human_ai_module/targeting, /datum/human_ai_module/health, /datum/human_ai_module/action_runtime, /datum/human_ai_module/inventory))
	brain.resume_modules = build_module_list(brain, list(/datum/human_ai_module/inventory, /datum/human_ai_module/guns))

/datum/human_ai_module_config/default/configure_process_module_lists(datum/human_ai_brain/brain)
	brain.process_modules_before_posture = build_module_list(brain, list(/datum/human_ai_module/perception))
	brain.process_modules_after_posture = build_module_list(brain, list(/datum/human_ai_module/targeting, /datum/human_ai_module/combat, /datum/human_ai_module/inventory, /datum/human_ai_module/action_runtime))

/datum/human_ai_module_config/default/configure_event_module_lists(datum/human_ai_brain/brain)
	brain.target_change_modules = build_module_list(brain, list(/datum/human_ai_module/inventory))
	brain.projectile_threat_modules = build_module_list(brain, list(/datum/human_ai_module/combat, /datum/human_ai_module/faction, /datum/human_ai_module/targeting, /datum/human_ai_module/cover))
	brain.combat_entered_modules = build_module_list(brain, list(/datum/human_ai_module/squad, /datum/human_ai_module/communication, /datum/human_ai_module/cover))
	brain.combat_exit_started_modules = build_module_list(brain, list(/datum/human_ai_module/targeting, /datum/human_ai_module/communication, /datum/human_ai_module/inventory))
	brain.combat_exit_finished_modules = build_module_list(brain, list(/datum/human_ai_module/cover, /datum/human_ai_module/targeting))
	brain.combat_exit_force_clear_modules = build_module_list(brain, list(/datum/human_ai_module/targeting, /datum/human_ai_module/cover))

/datum/human_ai_module_config/default/configure_query_module_lists(datum/human_ai_brain/brain)
	brain.target_vision_modules = build_module_list(brain, list(/datum/human_ai_module/inventory))
