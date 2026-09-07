/datum/human_ai_module_config
	var/list/datum/human_ai_module/owned_modules

/datum/human_ai_module_config/Destroy(force, ...)
	QDEL_LIST(owned_modules)
	owned_modules = null
	return ..()

/datum/human_ai_module_config/proc/register_module(datum/human_ai_module/module)
	if(!module)
		return null

	LAZYOR(owned_modules, module)
	return module

/datum/human_ai_module_config/proc/setup_brain(datum/human_ai_brain/brain, mob/living/carbon/human/new_human)
	return

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
	brain.faction = register_module(new /datum/human_ai_module/faction(brain))
	brain.targeting = register_module(new /datum/human_ai_module/targeting(brain))
	brain.cover = register_module(new /datum/human_ai_module/cover(brain))
	brain.grenade = register_module(new /datum/human_ai_module/grenade(brain))
	brain.health = register_module(new /datum/human_ai_module/health(brain))
	brain.communication = register_module(new /datum/human_ai_module/communication(brain))
	brain.guns = register_module(new /datum/human_ai_module/guns(brain))
	brain.navigation = register_module(new /datum/human_ai_module/navigation(brain))
	brain.squad = register_module(new /datum/human_ai_module/squad(brain))
	brain.action_runtime = register_module(new /datum/human_ai_module/action_runtime(brain))
	brain.combat = register_module(new /datum/human_ai_module/combat(brain))
	brain.conversation = register_module(new /datum/human_ai_module/conversation(brain))
	brain.orders = register_module(new /datum/human_ai_module/orders(brain))
	brain.profile = register_module(new /datum/human_ai_module/profile(brain))
	brain.emplacement = register_module(new /datum/human_ai_module/emplacement(brain))
	brain.perception = register_module(new /datum/human_ai_module/perception(brain))
	brain.perception.register_signals()
	brain.perception.setup_detection_radius()
	brain.inventory = register_module(new /datum/human_ai_module/inventory(brain))
	brain.inventory.register_signals()

/datum/human_ai_module_config/default/configure_lifecycle_module_lists(datum/human_ai_brain/brain)
	brain.reset_modules_before_wake_clear = list(
		brain.health,
		brain.navigation,
		brain.cover,
		brain.perception,
	)

	brain.reset_modules_after_wake_clear = list(
		brain.combat,
		brain.grenade,
		brain.targeting,
		brain.inventory,
		brain.action_runtime,
	)

	brain.suspend_modules_before_wake_clear = list(
		brain.navigation,
		brain.cover,
		brain.perception,
	)

	brain.suspend_modules_after_wake_clear = list(
		brain.combat,
		brain.grenade,
		brain.targeting,
		brain.health,
		brain.action_runtime,
		brain.inventory,
	)

	brain.resume_modules = list(
		brain.inventory,
		brain.guns,
	)

/datum/human_ai_module_config/default/configure_process_module_lists(datum/human_ai_brain/brain)
	brain.process_modules_before_posture = list(
		brain.perception,
	)

	brain.process_modules_after_posture = list(
		brain.targeting,
		brain.combat,
		brain.inventory,
		brain.action_runtime,
	)

/datum/human_ai_module_config/default/configure_event_module_lists(datum/human_ai_brain/brain)
	brain.target_change_modules = list(
		brain.inventory,
	)

	brain.projectile_threat_modules = list(
		brain.combat,
		brain.faction,
		brain.targeting,
		brain.cover,
	)

	brain.combat_entered_modules = list(
		brain.squad,
		brain.communication,
		brain.cover,
	)

	brain.combat_exit_started_modules = list(
		brain.targeting,
		brain.communication,
		brain.inventory,
	)

	brain.combat_exit_finished_modules = list(
		brain.cover,
		brain.targeting,
	)

	brain.combat_exit_force_clear_modules = list(
		brain.targeting,
		brain.cover,
	)

/datum/human_ai_module_config/default/configure_query_module_lists(datum/human_ai_brain/brain)
	brain.target_vision_modules = list(
		brain.inventory,
	)
