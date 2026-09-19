/datum/human_ai_module/combat
	module_id = "combat"
	required_module_types = list(/datum/human_ai_module/targeting, /datum/human_ai_module/perception)

	/// Ref to the last turf that the AI shot at
	var/turf/shot_at
	/// If TRUE, then we're actively fighting someone or saw a bullet go by or saw someone else go into combat
	var/in_combat = FALSE
	/// The minimum amount of time that can pass before this AI can leave combat
	var/combat_decay_time_min = 15 SECONDS
	/// The maximum amount of time that can pass before this AI can leave combat
	var/combat_decay_time_max = 30 SECONDS

/datum/human_ai_module/combat/proc/reset_combat()
	in_combat = FALSE
	shot_at = null

/datum/human_ai_module/combat/reset_module()
	reset_combat()

/datum/human_ai_module/combat/suspend_module(clear_inventory = FALSE)
	reset_combat()

/datum/human_ai_module/combat/process_module(delta_time)
	if(brain.has_current_target())
		enter_combat()

/datum/human_ai_module/combat/on_ai_event(datum/human_ai_event/event)
	if(event.event_type == HUMAN_AI_EVENT_PROJECTILE_THREAT)
		var/obj/projectile/bullet = event.data?["bullet"]
		on_projectile_threat(bullet, event.data?["from_direct_hit"])

/datum/human_ai_module/combat/on_projectile_threat(obj/projectile/bullet, from_direct_hit = FALSE)
	var/datum/human_ai_module/perception/perception_module = get_perception_module()
	if(!perception_module?.has_recent_threat())
		return

	enter_combat()

/datum/human_ai_module/combat/proc/get_perception_module()
	RETURN_TYPE(/datum/human_ai_module/perception)
	return brain?.get_perception_module()

/datum/human_ai_module/combat/proc/enter_combat()
	SIGNAL_HANDLER
	if(!brain.can_continue_runtime_work())
		return

	var/was_in_combat = in_combat
	brain.on_combat_entered(was_in_combat)
	in_combat = TRUE
	addtimer(CALLBACK(brain, TYPE_PROC_REF(/datum/human_ai_brain, exit_combat)), rand(combat_decay_time_min, combat_decay_time_max), TIMER_UNIQUE | TIMER_NO_HASH_WAIT | TIMER_OVERRIDE)
	SShuman_ai.combat_ever_started = TRUE

/datum/human_ai_module/combat/proc/exit_combat()
	if(!brain.has_valid_tied_human())
		brain.on_combat_exit_force_cleared()
		in_combat = FALSE
		return

	if(!brain.can_continue_runtime_work())
		return

	if(in_combat)
		brain.on_combat_exit_started()

	brain.on_combat_exit_finished()

	in_combat = FALSE
