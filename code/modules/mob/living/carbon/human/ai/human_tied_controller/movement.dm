// Movement gates

/datum/human_tied_controller/proc/can_move()
	if(!can_directly_control())
		return FALSE
	if(!(tied_human.mobility_flags & MOBILITY_MOVE) || tied_human.is_mob_incapacitated(TRUE) || (tied_human.body_position != STANDING_UP && !tied_human.can_crawl) || tied_human.anchored)
		return FALSE
	return TRUE

/datum/human_tied_controller/proc/has_move_delay()
	return ai_move_delay > world.time

// Move delay primitives

/datum/human_tied_controller/proc/get_current_move_delay()
	if(!can_read_puppet())
		return 0
	if(tied_human.recalculate_move_delay)
		return tied_human.movement_delay()
	return tied_human.move_delay

/datum/human_tied_controller/proc/consume_next_move_slowdown()
	if(!can_mutate_puppet() || !tied_human.next_move_slowdown)
		return 0
	var/consumed_slowdown = tied_human.next_move_slowdown
	tied_human.next_move_slowdown = 0
	return consumed_slowdown

/datum/human_tied_controller/proc/set_move_delay_until(target_time)
	ai_move_delay = target_time
	return TRUE

/datum/human_tied_controller/proc/apply_move_delay()
	if(!can_mutate_puppet())
		return FALSE
	set_move_delay_until(world.time + get_current_move_delay() + consume_next_move_slowdown())
	return TRUE

// Behavior/migration helpers

/datum/human_tied_controller/proc/try_apply_move_delay()
	if(!can_move() || has_move_delay())
		return FALSE
	return apply_move_delay()

// Helper for reconstructing the old movement behavior during migration.
/datum/human_tied_controller/proc/can_move_and_apply_move_delay()
	return try_apply_move_delay()

// Raw movement primitives

/datum/human_tied_controller/proc/get_move_direction(turf/target_turf)
	if(!can_read_puppet() || !target_turf)
		return null
	return get_dir(tied_human, target_turf)

/datum/human_tied_controller/proc/Move(turf/target_turf, direction)
	if(!can_directly_control() || !target_turf)
		return FALSE
	if(isnull(direction))
		direction = get_move_direction(target_turf)
	return tied_human.Move(target_turf, direction)

/datum/human_tied_controller/proc/forceMove(turf/target_turf)
	if(!can_force_control() || !target_turf)
		return FALSE
	tied_human.forceMove(target_turf)
	return TRUE

// Behavior helper that combines movement checks, blockers, delay, and raw Move().
/datum/human_tied_controller/proc/try_move(turf/target_turf, direction, interact_with_blockers = TRUE)
	if(!can_move() || !target_turf || has_move_delay())
		return FALSE
	if(isnull(direction))
		direction = get_move_direction(target_turf)
	if(get_dist(target_turf, tied_human) == 1)
		var/list/blockers = get_move_blockers(target_turf)
		if(isnull(blockers))
			return FALSE
		for(var/a in blockers)
			var/atom/obstacle = a
			if(get_obstacle_cost(obstacle, direction, target_turf) == INFINITY)
				return FALSE
		if(interact_with_blockers)
			act_on_blockers(blockers)
	if(!apply_move_delay())
		return FALSE
	return Move(target_turf, direction)

// Raw facing primitives

/datum/human_tied_controller/proc/face_atom(atom/target)
	if(!can_directly_control() || !target)
		return FALSE
	tied_human.face_atom(target)
	return TRUE

/datum/human_tied_controller/proc/face_dir(direction)
	if(!can_directly_control() || !direction)
		return FALSE
	tied_human.face_dir(direction)
	return TRUE

/datum/human_tied_controller/proc/setDir(direction)
	if(!can_directly_control() || !direction)
		return FALSE
	tied_human.setDir(direction)
	return TRUE
