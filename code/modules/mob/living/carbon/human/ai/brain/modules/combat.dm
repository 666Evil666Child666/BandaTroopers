/datum/human_ai_module/combat
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

/datum/human_ai_module/combat/proc/enter_combat()
	SIGNAL_HANDLER
	if(!brain.has_valid_tied_human())
		return

	if(brain.squad.squad_id) // call for help
		var/datum/human_ai_squad/squad_datum = SShuman_ai.squad_id_dict["[brain.squad.squad_id]"]
		for(var/datum/human_ai_brain/squaddie as anything in squad_datum.ai_in_squad)
			if(!squaddie.has_valid_tied_human())
				continue
			if(squaddie.targeting.has_target_turf())
				continue
			if(get_dist(squaddie.tied_human, brain.tied_human) > squaddie.profile.view_distance)
				continue
			var/atom/movable/current_target = brain.targeting.get_current_target()
			if(!squaddie.targeting.can_target(current_target))
				continue
			squaddie.targeting.set_target_turf_direct(brain.targeting.get_target_turf())

	if(brain.tied_human.client)
		return

	if(!in_combat)
		brain.communication.say_in_combat_line()

	var/atom/movable/current_target = brain.targeting.get_current_target()
	if(isxeno(current_target))
		brain.cover.try_cover(Get_Angle(current_target, brain.tied_human), current_target)

	in_combat = TRUE
	addtimer(CALLBACK(brain, TYPE_PROC_REF(/datum/human_ai_brain, exit_combat)), rand(combat_decay_time_min, combat_decay_time_max), TIMER_UNIQUE | TIMER_NO_HASH_WAIT | TIMER_OVERRIDE)
	SShuman_ai.combat_ever_started = TRUE

/datum/human_ai_module/combat/proc/exit_combat()
	if(!brain.has_valid_tied_human())
		brain.targeting.lose_target()
		brain.targeting.clear_target_turf()
		brain.cover.end_cover()
		in_combat = FALSE
		return

	if(brain.tied_human.client)
		return

	if(in_combat)
		brain.tied_human.a_intent_change(INTENT_DISARM)
		brain.targeting.lose_target()
		brain.communication.say_exit_combat_line()
		if(!brain.emplacement.has_sniper_home())
			brain.inventory.holster_primary()
		brain.inventory.holster_melee()

	if(brain.cover.has_cover())
		if(!prob(brain.cover.peek_cover_chance))
			brain.targeting.clear_target_turf()
		brain.cover.end_cover()
	else
		brain.targeting.clear_target_turf()

	in_combat = FALSE
