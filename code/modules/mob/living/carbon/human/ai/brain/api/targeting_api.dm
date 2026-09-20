// Human AI targeting and perception-facing API.
// Perception owns sensing and target validity; targeting owns current target state.

/datum/human_ai_brain/proc/get_current_target()
	RETURN_TYPE(/atom/movable)
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.get_current_target()

/datum/human_ai_brain/proc/get_aim_target()
	RETURN_TYPE(/atom)
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.get_aim_target()

/datum/human_ai_brain/proc/has_current_target()
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.has_current_target()

/datum/human_ai_brain/proc/can_target(atom/movable/target)
	var/datum/human_ai_module/perception/perception_module = get_perception_module()
	return perception_module?.can_target(target)

/datum/human_ai_brain/proc/get_visible_target_candidates()
	var/datum/human_ai_module/perception/perception_module = get_perception_module()
	return perception_module?.get_visible_target_candidates() || list()

/datum/human_ai_brain/proc/get_fire_line_safety(atom/target, datum/human_ai_firearm_profile/gun_data = null)
	var/datum/human_ai_module/perception/perception_module = get_perception_module()
	if(!perception_module)
		return HUMAN_AI_FIRE_LINE_BLOCKED
	return perception_module.get_fire_line_safety(target, gun_data)

/datum/human_ai_brain/proc/has_recent_projectile_threat()
	var/datum/human_ai_module/perception/perception_module = get_perception_module()
	return perception_module?.has_recent_projectile_threat()

/datum/human_ai_brain/proc/get_recent_projectile_threat_turf()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/perception/perception_module = get_perception_module()
	return perception_module?.get_recent_projectile_threat_turf()

/datum/human_ai_brain/proc/get_recent_projectile_threat_source()
	RETURN_TYPE(/atom/movable)
	var/datum/human_ai_module/perception/perception_module = get_perception_module()
	return perception_module?.get_recent_projectile_threat_source()

/datum/human_ai_brain/proc/get_recent_projectile_threat_angle()
	var/datum/human_ai_module/perception/perception_module = get_perception_module()
	return perception_module?.get_recent_projectile_threat_angle()

/datum/human_ai_brain/proc/get_target_turf()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	var/turf/target_turf = targeting_module?.get_target_turf()
	if(target_turf)
		return target_turf
	return get_recent_projectile_threat_turf()

/datum/human_ai_brain/proc/has_target_turf()
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	if(targeting_module?.has_target_turf())
		return TRUE
	return has_recent_projectile_threat()

/datum/human_ai_brain/proc/get_shared_combat_target_turf()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.get_current_target_turf()

/datum/human_ai_brain/proc/has_shared_combat_target_turf()
	return !!get_shared_combat_target_turf()

/datum/human_ai_brain/proc/get_chase_target_turf()
	RETURN_TYPE(/turf)
	var/turf/target_turf = get_shared_combat_target_turf()
	if(target_turf)
		return target_turf
	return get_recent_projectile_threat_turf()

/datum/human_ai_brain/proc/get_current_target_turf()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.get_current_target_turf()

/datum/human_ai_brain/proc/get_last_known_target_turf()
	RETURN_TYPE(/turf)
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.get_last_known_target_turf()

/datum/human_ai_brain/proc/has_recent_lost_target()
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	return targeting_module?.has_recent_lost_target()

/datum/human_ai_brain/proc/has_offscreen_fire_target()
	return has_recent_projectile_threat()

/datum/human_ai_brain/proc/can_fire_offscreen(turf/target_turf, datum/human_ai_firearm_profile/gun_data = null)
	if(!target_turf || !has_recent_projectile_threat())
		return FALSE
	if(get_recent_projectile_threat_turf() != target_turf)
		return FALSE
	var/atom/movable/threat_source = get_recent_projectile_threat_source()
	if(threat_source && !QDELETED(threat_source) && is_friendly_target(threat_source))
		return FALSE
	if(!gun_data)
		return TRUE
	return gun_data.maximum_range > get_view_distance()

/datum/human_ai_brain/proc/lose_target()
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	targeting_module?.lose_target()

/datum/human_ai_brain/proc/clear_target_turf()
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	targeting_module?.clear_target_turf()

/datum/human_ai_brain/proc/clear_last_known_target()
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	targeting_module?.clear_last_known_target()

/datum/human_ai_brain/proc/set_target_turf_direct(turf/new_target_turf)
	var/datum/human_ai_module/targeting/targeting_module = get_targeting_module()
	targeting_module?.set_target_turf_direct(new_target_turf)
