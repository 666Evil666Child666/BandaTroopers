// ==================== State ====================
// Owns created modules and stores resolved action policy for this brain setup.
/datum/human_ai_module_config
	var/list/datum/human_ai_module/owned_modules
	var/list/modules_by_type
	var/list/modules_by_id
	var/list/requested_module_types
	var/list/action_whitelist
	var/list/action_blacklist

// ==================== Lifetime ====================
// Releases modules owned by the config datum.
/datum/human_ai_module_config/Destroy(force, ...)
	QDEL_LIST(owned_modules)
	owned_modules = null
	modules_by_type = null
	modules_by_id = null
	requested_module_types = null
	action_whitelist = null
	action_blacklist = null
	return ..()

/datum/human_ai_module_config/proc/setup_brain(datum/human_ai_brain/brain, mob/living/carbon/human/new_human)
	return

// ==================== Teardown ====================
// Clears every module slot on the brain after deleting config-owned modules.
/datum/human_ai_module_config/proc/teardown_brain_modules(datum/human_ai_brain/brain)
	QDEL_LIST(owned_modules)
	owned_modules = null
	modules_by_type = null
	modules_by_id = null
	requested_module_types = null
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

// ==================== Process lists ====================
// Wires created modules into lifecycle, process, event, and query dispatch lists.
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

// ==================== Default setup ====================
// Builds the default Human AI from preset action policy and expanded module dependencies.
/datum/human_ai_module_config/default/setup_brain(datum/human_ai_brain/brain, mob/living/carbon/human/new_human)
	read_action_policy(new_human?.assigned_equipment_preset)

	requested_module_types = get_module_types_to_setup()
	for(var/module_type as anything in requested_module_types)
		setup_module_by_type(brain, module_type)

	validate_module_setup(brain)

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
