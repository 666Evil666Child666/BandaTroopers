/datum/human_ai_module
	var/datum/human_ai_brain/brain
	var/list/required_module_types = list()

/datum/human_ai_module/New(datum/human_ai_brain/new_brain)
	. = ..()
	brain = new_brain

/datum/human_ai_module/Destroy(force, ...)
	brain = null
	return ..()

/datum/human_ai_module/proc/reset_module()
	return

/datum/human_ai_module/proc/suspend_module(clear_inventory = FALSE)
	return

/datum/human_ai_module/proc/resume_module(previous_lifecycle_state)
	return

/datum/human_ai_module/proc/process_module(delta_time)
	return

/datum/human_ai_module/proc/on_target_changed(atom/movable/old_target, atom/movable/new_target)
	return

/datum/human_ai_module/proc/on_projectile_threat(obj/projectile/bullet, from_direct_hit = FALSE)
	return

/datum/human_ai_module/proc/on_combat_entered(was_in_combat)
	return

/datum/human_ai_module/proc/on_combat_exit_started(should_holster_primary = TRUE)
	return

/datum/human_ai_module/proc/on_combat_exit_finished(list/combat_exit_context)
	return

/datum/human_ai_module/proc/can_ignore_target_darkness()
	return FALSE
