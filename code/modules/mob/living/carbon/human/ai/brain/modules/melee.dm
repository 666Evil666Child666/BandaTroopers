/datum/human_ai_module/melee
	module_id = "melee"
	required_module_types = list(
		/datum/human_ai_module/targeting,
		/datum/human_ai_module/navigation,
		/datum/human_ai_module/cover,
		/datum/human_ai_module/grenade,
		/datum/human_ai_module/combat,
		/datum/human_ai_module/inventory,
		/datum/human_ai_module/guns,
		/datum/human_ai_module/orders,
		/datum/human_ai_module/emplacement,
	)

	var/melee_weight = 3

/datum/human_ai_module/melee/proc/get_current_target()
	RETURN_TYPE(/atom/movable)
	var/datum/human_ai_module/targeting/targeting = context?.get_module(/datum/human_ai_module/targeting)
	return targeting?.get_current_target()

/datum/human_ai_module/melee/proc/can_move_for_melee()
	var/datum/human_ai_module/orders/orders = context?.get_module(/datum/human_ai_module/orders)
	return !orders || orders.can_move_for_action()

/datum/human_ai_module/melee/proc/has_sniper_home()
	var/datum/human_ai_module/emplacement/emplacement = context?.get_module(/datum/human_ai_module/emplacement)
	return emplacement?.has_sniper_home()

/datum/human_ai_module/melee/proc/has_pending_cover()
	var/datum/human_ai_module/cover/cover = context?.get_module(/datum/human_ai_module/cover)
	return cover?.has_cover() && !cover.is_in_cover()

/datum/human_ai_module/melee/proc/has_active_grenade()
	var/datum/human_ai_module/grenade/grenade = context?.get_module(/datum/human_ai_module/grenade)
	return grenade?.has_active_grenade()

/datum/human_ai_module/melee/proc/can_use_ranged_weapon()
	var/datum/human_ai_module/guns/guns = context?.get_module(/datum/human_ai_module/guns)
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	return guns && !guns.has_tried_reload() && (inventory?.has_primary_weapon() || inventory?.has_secondary_weapons())

/datum/human_ai_module/melee/proc/can_try_melee()
	if(!context?.is_valid())
		return FALSE

	if(!get_current_target())
		return FALSE

	if(!can_move_for_melee())
		return FALSE

	if(has_sniper_home())
		return FALSE

	if(can_use_ranged_weapon())
		return FALSE

	return TRUE

/datum/human_ai_module/melee/proc/get_melee_weight()
	return can_try_melee() ? melee_weight : 0

/datum/human_ai_module/melee/proc/should_continue_melee()
	if(!can_try_melee())
		return FALSE

	if(has_active_grenade())
		return FALSE

	if(has_pending_cover())
		return FALSE

	if(can_use_ranged_weapon())
		return FALSE

	return TRUE

/datum/human_ai_module/melee/proc/attack_current_target_if_adjacent()
	var/datum/human_tied_controller/controller = context?.controller
	var/atom/movable/current_target = get_current_target()
	if(!controller || !current_target)
		return FALSE

	if(controller.get_distance_to(current_target) > 1)
		return FALSE

	var/datum/human_ai_melee_context/melee_context = new(brain, null, current_target)
	. = GLOB.human_ai_melee_handler.attack(melee_context)
	qdel(melee_context)

/datum/human_ai_module/melee/proc/approach_current_target()
	var/atom/movable/current_target = get_current_target()
	if(!current_target)
		return FALSE

	var/datum/human_ai_module/navigation/navigation = context?.get_module(/datum/human_ai_module/navigation)
	return navigation?.move_to_next_turf(get_turf(current_target))

/datum/human_ai_module/melee/proc/run_melee_step()
	if(!should_continue_melee())
		return FALSE

	attack_current_target_if_adjacent()
	return approach_current_target()
