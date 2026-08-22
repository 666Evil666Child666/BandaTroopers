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
			if(squaddie.targeting.target_turf)
				continue
			if(get_dist(squaddie.tied_human, brain.tied_human) > squaddie.view_distance)
				continue
			if(!squaddie.targeting.can_target(brain.targeting.current_target))
				continue
			squaddie.targeting.target_turf = brain.targeting.target_turf

	if(brain.tied_human.client)
		return

	if(!in_combat)
		brain.communication.say_in_combat_line()

	if(isxeno(brain.targeting.current_target))
		brain.cover.try_cover(Get_Angle(brain.targeting.current_target, brain.tied_human), brain.targeting.current_target)

	in_combat = TRUE
	addtimer(CALLBACK(brain, TYPE_PROC_REF(/datum/human_ai_brain, exit_combat)), rand(combat_decay_time_min, combat_decay_time_max), TIMER_UNIQUE | TIMER_NO_HASH_WAIT | TIMER_OVERRIDE)
	SShuman_ai.combat_ever_started = TRUE

/datum/human_ai_module/combat/proc/exit_combat()
	if(!brain.has_valid_tied_human())
		brain.targeting.lose_target()
		brain.targeting.target_turf = null
		brain.cover.end_cover()
		in_combat = FALSE
		return

	if(brain.tied_human.client)
		return

	if(in_combat)
		brain.tied_human.a_intent_change(INTENT_DISARM)
		brain.targeting.lose_target()
		brain.communication.say_exit_combat_line()
		if(!brain.sniper_home)
			brain.inventory.holster_primary()
		brain.inventory.holster_melee()

	if(brain.cover.current_cover)
		if(!prob(brain.cover.peek_cover_chance))
			brain.targeting.target_turf = null
		brain.cover.end_cover()
	else
		brain.targeting.target_turf = null

	in_combat = FALSE
