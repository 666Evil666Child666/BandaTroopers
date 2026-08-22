/datum/human_ai_module/orders
	/// A targeted turf that we should quickly approach
	var/turf/quick_approach
	/// If TRUE, the AI will not move at all
	var/hold_position = FALSE

/datum/human_ai_module/orders/proc/set_hold_position(new_value)
	hold_position = new_value

/datum/human_ai_module/orders/proc/set_quick_approach(turf/new_turf)
	quick_approach = new_turf

/datum/human_ai_module/orders/proc/clear_quick_approach()
	quick_approach = null

/datum/human_ai_module/orders/proc/can_move_for_action()
	return !hold_position
