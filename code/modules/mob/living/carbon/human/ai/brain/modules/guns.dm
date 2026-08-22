/datum/human_ai_module/guns
	/// If we've tried to reload (and failed) with our current inventory
	var/tried_reload = FALSE
	/// Cooldown for if we've fired too many rounds in a burst (for recoil)
	COOLDOWN_DECLARE(fire_overload_cooldown)
	/// Generic cooldown for things like shotgun pumping, bolt racking, etc. This stops us from firing for however long specified
	COOLDOWN_DECLARE(stop_fire_cooldown)

/datum/human_ai_module/guns/proc/has_tried_reload()
	return tried_reload

/datum/human_ai_module/guns/proc/mark_tried_reload()
	tried_reload = TRUE

/datum/human_ai_module/guns/proc/clear_tried_reload()
	tried_reload = FALSE

/datum/human_ai_module/guns/proc/should_reload()
	var/obj/item/weapon/gun/primary_weapon = brain.inventory.get_primary_weapon()
	if(!primary_weapon)
		return FALSE

	// if(primary_weapon.in_chamber)
	// 	return FALSE

	// if(!primary_weapon.current_mag)
	// 	return TRUE

	// if(primary_weapon.current_mag.current_rounds > 0)
	// 	return FALSE

	// return TRUE

	return !primary_weapon.has_ammunition()	// SS220 EDIT
