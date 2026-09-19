/datum/human_ai_module/melee
	module_id = "melee"
	required_module_types = list(
		/datum/human_ai_module/targeting,
		/datum/human_ai_module/navigation,
		/datum/human_ai_module/cover,
		/datum/human_ai_module/grenade,
		/datum/human_ai_module/combat,
		/datum/human_ai_module/guns,
		/datum/human_ai_module/orders,
		/datum/human_ai_module/emplacement,
	)

	var/melee_weight = 3

/datum/human_ai_module/melee/proc/can_try_melee()
	if(!context?.is_valid())
		return FALSE

	if(!brain.get_current_target())
		return FALSE

	if(!brain.can_move_for_action())
		return FALSE

	if(brain.has_sniper_home())
		return FALSE

	if(brain.can_use_ranged_weapon())
		return FALSE

	return TRUE

/datum/human_ai_module/melee/proc/get_melee_weight()
	return can_try_melee() ? melee_weight : 0

/datum/human_ai_module/melee/proc/should_continue_melee()
	if(!can_try_melee())
		return FALSE

	if(brain.has_active_grenade())
		return FALSE

	if(brain.has_pending_cover())
		return FALSE

	if(brain.can_use_ranged_weapon())
		return FALSE

	return TRUE

/datum/human_ai_module/melee/proc/attack_current_target_if_adjacent()
	var/datum/human_tied_controller/controller = context?.controller
	var/atom/movable/current_target = brain.get_current_target()
	if(!controller || !current_target)
		return FALSE

	if(controller.get_distance_to(current_target) > 1)
		return FALSE

	var/datum/human_ai_melee_context/melee_context = new(brain, null, current_target)
	. = GLOB.human_ai_melee_handler.attack(melee_context)
	qdel(melee_context)

/datum/human_ai_module/melee/proc/approach_current_target()
	var/atom/movable/current_target = brain.get_current_target()
	if(!current_target)
		return FALSE

	return brain.move_to_atom(current_target)

/datum/human_ai_module/melee/proc/run_melee_step()
	if(!should_continue_melee())
		return FALSE

	attack_current_target_if_adjacent()
	return approach_current_target()
