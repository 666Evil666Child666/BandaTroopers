// Puppet state queries

/datum/human_tied_controller/proc/has_tied_human()
	return tied_human && !QDELETED(tied_human)

/datum/human_tied_controller/proc/is_tied_human_loaded()
	return has_tied_human() && !isnull(tied_human.loc)

/datum/human_tied_controller/proc/has_valid_tied_human()
	return is_tied_human_loaded()

/datum/human_tied_controller/proc/has_client()
	return !!tied_human?.client

/datum/human_tied_controller/proc/has_active_player()
	return has_client()

/datum/human_tied_controller/proc/can_player_takeover_block_ai()
	return has_active_player()

// AI control flags

/datum/human_tied_controller/proc/is_ai_controlled()
	return !!(tied_human?.mob_flags & AI_CONTROLLED)

/datum/human_tied_controller/proc/mark_ai_controlled()
	if(!has_tied_human())
		return FALSE
	tied_human.mob_flags |= AI_CONTROLLED
	return TRUE

/datum/human_tied_controller/proc/clear_ai_controlled()
	if(!has_tied_human())
		return FALSE
	tied_human.mob_flags &= ~AI_CONTROLLED
	return TRUE

// Control gates

/datum/human_tied_controller/proc/can_read_puppet()
	return has_tied_human()

/datum/human_tied_controller/proc/can_mutate_puppet()
	return is_tied_human_loaded() && !can_player_takeover_block_ai()

/datum/human_tied_controller/proc/can_tick_ai()
	return can_mutate_puppet() && !is_dead()

/datum/human_tied_controller/proc/can_directly_control()
	return can_tick_ai()

/datum/human_tied_controller/proc/can_force_control()
	return can_mutate_puppet()

/datum/human_tied_controller/proc/can_force_setup()
	return can_mutate_puppet()

/datum/human_tied_controller/proc/can_setup_puppet()
	return can_force_setup()

/datum/human_tied_controller/proc/can_release_puppet()
	return has_tied_human()

// Behavior/migration helpers

// Helper for reconstructing the old broad control gate during migration.
/datum/human_tied_controller/proc/can_ai_control()
	return can_mutate_puppet()

// Puppet read primitives

/datum/human_tied_controller/proc/is_dead()
	return !has_tied_human() || (tied_human.stat == DEAD)

/datum/human_tied_controller/proc/is_incapacitated(ignore_resting = FALSE)
	return !has_tied_human() || tied_human.is_mob_incapacitated(ignore_resting)

/datum/human_tied_controller/proc/is_conscious_available()
	return can_mutate_puppet() && !tied_human.buckled && (tied_human.stat == CONSCIOUS) && !tied_human.is_mob_incapacitated()

/datum/human_tied_controller/proc/get_turf()
	RETURN_TYPE(/turf)
	return get_turf(tied_human)

/datum/human_tied_controller/proc/get_faction()
	return tied_human?.faction

// Puppet mutation primitives

/datum/human_tied_controller/proc/set_faction(new_faction)
	if(!can_force_setup())
		return FALSE
	tied_human.faction = new_faction
	return TRUE

/datum/human_tied_controller/proc/get_health_ratio()
	if(!can_read_puppet() || !tied_human.maxHealth)
		return 0
	return tied_human.health / tied_human.maxHealth
