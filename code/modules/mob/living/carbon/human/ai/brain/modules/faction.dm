/datum/human_ai_module/faction
	/// Factions that the AI won't engage in hostilities with. Controlled by the AI's faction
	var/list/friendly_factions = list()
	/// Factions that the AI will not become hostile to unless attacked
	var/list/neutral_factions = list()
	/// The last faction that the AI was/is a part of
	var/previous_faction

/// Removes neutral faction status from a given faction
/datum/human_ai_module/faction/proc/on_neutral_faction_betray(faction)
	if(!brain.tied_controller.has_faction())
		return

	var/datum/human_ai_faction/our_faction = SShuman_ai.human_ai_factions[brain.tied_controller.get_faction()]
	if(!our_faction)
		return

	our_faction.remove_neutral_faction(faction)
	our_faction.reapply_faction_data()

/// Returns TRUE if the target is friendly/neutral to us
/// This is THE hottest proc that Human AI invokes, so please be careful in adding more to it
/datum/human_ai_module/faction/proc/faction_check(atom/target)
	var/my_faction = brain.tied_controller.get_faction()
	var/target_faction

	if(ismob(target))
		var/mob/mob_target = target
		target_faction = mob_target.faction
	else if(istype(target, /obj/vehicle/multitile))
		var/obj/vehicle/multitile/vehicle_target = target
		target_faction = vehicle_target.vehicle_faction
	else if(isdefenses(target))
		var/obj/structure/machinery/defenses/defense_target = target
		return (my_faction in defense_target.faction_group)
	else
		return FALSE

	if(target_faction == my_faction)
		return TRUE
	if(target_faction in friendly_factions)
		return TRUE
	if(target_faction in neutral_factions)
		return TRUE
	return FALSE

/datum/human_ai_module/faction/proc/react_to_attacker_faction(atom/attacker)
	if(!length(neutral_factions))
		return

	if(ismob(attacker))
		var/mob/mob_attacker = attacker
		if(mob_attacker.faction in neutral_factions)
			on_neutral_faction_betray(mob_attacker.faction)
		return

	if(isdefenses(attacker))
		var/obj/structure/machinery/defenses/defense_attacker = attacker
		for(var/faction in defense_attacker.faction_group)
			if(faction in neutral_factions)
				on_neutral_faction_betray(faction)

/datum/human_ai_module/faction/on_projectile_threat(obj/projectile/bullet, from_direct_hit = FALSE)
	if(!bullet?.firer)
		return

	react_to_attacker_faction(bullet.firer)
