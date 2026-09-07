/datum/human_ai_module_config

/datum/human_ai_module_config/proc/setup_brain(datum/human_ai_brain/brain, mob/living/carbon/human/new_human)
	return

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
	brain.faction = new(brain)
	brain.targeting = new(brain)
	brain.cover = new(brain)
	brain.grenade = new(brain)
	brain.health = new(brain)
	brain.communication = new(brain)
	brain.guns = new(brain)
	brain.navigation = new(brain)
	brain.squad = new(brain)
	brain.action_runtime = new(brain)
	brain.combat = new(brain)
	brain.conversation = new(brain)
	brain.orders = new(brain)
	brain.profile = new(brain)
	brain.emplacement = new(brain)
	brain.perception = new(brain)
	brain.perception.register_signals()
	brain.perception.setup_detection_radius()
	brain.inventory = new(brain)
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
