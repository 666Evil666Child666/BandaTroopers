/datum/human_ai_brain/proc/halo_finalize_human_ai_brain(mob/living/carbon/human/new_human)
	return

/datum/human_ai_brain/proc/invalidate_halo_runtime_caches()
	return

/datum/human_ai_brain/proc/halo_runtime_uses_projectile_pressure_controls()
	return FALSE

/datum/human_ai_brain/proc/halo_apply_navigation_profile(short_step_range = 0, path_retarget_slack = 0, nearby_item_interval = 1 SECONDS)
	return

/datum/human_ai_brain/proc/halo_should_suspend_nearby_item_search(queued_projectiles_override = null)
	return FALSE

/datum/human_ai_brain/proc/halo_should_disable_cover_retreat(queued_projectiles_override = null)
	return FALSE

/datum/human_ai_brain/proc/halo_should_defer_ranged_fire(atom/threat = null, queued_projectiles_override = null)
	return FALSE

/datum/human_ai_brain/proc/halo_configure_unggoy_behavior(role, panic_health_pct = 0, panics_without_leader = FALSE, ignore_panic = FALSE, overheat_retreat = TRUE)
	return

/datum/human_ai_brain/proc/halo_configure_unggoy_suicide_bomber(suicide_prime_range = 5)
	return

/datum/human_ai_brain/proc/halo_configure_sangheili_behavior(has_sword = FALSE, sword_only = FALSE, sword_charge_range = 5, unarmed_commit_range = 2)
	return
