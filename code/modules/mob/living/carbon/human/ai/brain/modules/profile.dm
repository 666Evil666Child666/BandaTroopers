/datum/human_ai_module/profile
	module_id = "profile"
	var/micro_action_delay = 0.2 SECONDS
	var/short_action_delay = 0.5 SECONDS
	var/medium_action_delay = 2 SECONDS
	var/long_action_delay = 5 SECONDS
	/// Global multiplier for all AI action delays
	var/action_delay_mult = 2 // Doubled from 1, gives hAI a believable time between actions

	/// Distance for view checks
	var/view_distance = 6
	/// If TRUE, shoots until the target is dead. Else, stops when downed
	var/shoot_to_kill = TRUE
	/// Should we limit our FOV in case view_distance is more than 7
	var/scope_vision = TRUE
