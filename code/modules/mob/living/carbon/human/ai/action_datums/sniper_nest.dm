/datum/ai_action/sniper_nest
	name = "Sniper Nest"
	action_flags = ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/emplacement, /datum/human_ai_module/guns, /datum/human_ai_module/inventory, /datum/human_ai_module/navigation, /datum/human_ai_module/profile)
	var/initial_view
	var/initial_reload_line_chance

/datum/ai_action/sniper_nest/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !inventory)
		return 0

	if(!brain.has_sniper_home())
		return 0

	if(brain.has_tried_reload())
		return 0

	if(brain.has_cover())
		return 0

	if(!inventory.has_primary_weapon())
		return 0

	if(brain.is_healing_someone())
		return 0

	return 12

/datum/ai_action/sniper_nest/Added()
	var/datum/human_ai_brain/brain = context?.brain
	if(!brain)
		return

	initial_view = brain.get_view_distance()
	initial_reload_line_chance = brain.get_reload_line_chance()
	brain.set_reload_line_chance(0)

/datum/ai_action/sniper_nest/Destroy(force, ...)
	var/datum/human_ai_brain/brain = context?.brain
	if(brain)
		brain.set_view_distance(initial_view)
		brain.set_reload_line_chance(initial_reload_line_chance)
	return ..()

/datum/ai_action/sniper_nest/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !controller || !inventory)
		return ONGOING_ACTION_COMPLETED

	if(brain.is_stationary_fire_blocked())
		return ONGOING_ACTION_COMPLETED

	var/obj/item/weapon/gun/primary_weapon = inventory.get_primary_weapon()
	if(!primary_weapon)
		return ONGOING_ACTION_COMPLETED

	var/turf/sniper_home = brain.get_sniper_home()
	if(QDELETED(sniper_home))
		return ONGOING_ACTION_COMPLETED

	if(controller.get_distance_to(sniper_home) > 0)
		if(!brain.move_to_turf(sniper_home))
			return ONGOING_ACTION_COMPLETED

	if(!controller.get_distance_to(sniper_home))
		brain.set_view_distance(30)
		controller.face_dir(brain.get_sniper_dir())

	if(!brain.should_reload())
		inventory.unholster_primary()
		inventory.ensure_primary_hand(primary_weapon)
		inventory.wield_primary()

	return ONGOING_ACTION_UNFINISHED


/datum/admins/proc/create_human_ai_sniper()
	set name = "Create Human AI Sniper"
	set category = "Game Master.HumanAI"

	var/static/list/sniper_equipment_presets = list(
		/datum/equipment_preset/clf/soldier/bolt::name = /datum/equipment_preset/clf/soldier/bolt,
		/datum/equipment_preset/clf/soldier/svd::name = /datum/equipment_preset/clf/soldier/svd,
		/datum/equipment_preset/rebel/sniper::name = /datum/equipment_preset/rebel/sniper,
		/datum/equipment_preset/canc/remnant/marksman::name = /datum/equipment_preset/canc/remnant/marksman,
		/datum/equipment_preset/canc_dogwar/soldier/marksman::name = /datum/equipment_preset/canc_dogwar/soldier/marksman,
		/datum/equipment_preset/canc_dogwar/militia/marksman::name = /datum/equipment_preset/canc_dogwar/militia/marksman,
		/datum/equipment_preset/canc_dogwar/upp/marksman::name = /datum/equipment_preset/canc_dogwar/upp/marksman,
		/datum/equipment_preset/canc_dogwar/specops/marksman::name = /datum/equipment_preset/canc_dogwar/specops/marksman,
		/datum/equipment_preset/canc/remnant/marksman/snowman::name = /datum/equipment_preset/canc/remnant/marksman/snowman,
		/datum/equipment_preset/canc/remnant/marksman/type88::name = /datum/equipment_preset/canc/remnant/marksman/type88,
		/datum/equipment_preset/canc/remnant/marksman/type88/snowman::name = /datum/equipment_preset/canc/remnant/marksman/type88/snowman,
		/datum/equipment_preset/pmc/sniper::name = /datum/equipment_preset/pmc/sniper,
		/datum/equipment_preset/upp/sniper::name = /datum/equipment_preset/upp/sniper,
		/datum/equipment_preset/uscm/specialist_equipped/sniper::name = /datum/equipment_preset/uscm/specialist_equipped/sniper,
		/datum/equipment_preset/other/freelancer/marksman::name = /datum/equipment_preset/other/freelancer/marksman,
		/datum/equipment_preset/royal_marine/sniper::name = /datum/equipment_preset/royal_marine/sniper/ai,
		/datum/equipment_preset/colonist/security/guard/marksman::name = /datum/equipment_preset/colonist/security/guard/marksman,
		/datum/equipment_preset/mercenary/sentinel/marksman::name = /datum/equipment_preset/mercenary/sentinel/marksman,
		/datum/equipment_preset/mercenary/infiltrator::name = /datum/equipment_preset/mercenary/infiltrator,
		/datum/equipment_preset/fil/rifleman/sniper::name = /datum/equipment_preset/fil/rifleman/sniper,
		// SS220 EDIT - START
		// HALO AI sniper presets.
		/datum/equipment_preset/unsc/spec/equipped_sniper/ai_sniper::name = /datum/equipment_preset/unsc/spec/equipped_sniper/ai_sniper,
		/datum/equipment_preset/unsc/spartan/sniper::name = /datum/equipment_preset/unsc/spartan/sniper,
		/datum/equipment_preset/insurgent/specialist/sniper::name = /datum/equipment_preset/insurgent/specialist/sniper,
		/datum/equipment_preset/covenant/sangheili/minor/carbine::name = /datum/equipment_preset/covenant/sangheili/minor/carbine,
		/datum/equipment_preset/covenant/ruuhtian/marksman/carbine::name = /datum/equipment_preset/covenant/ruuhtian/marksman/carbine,
		/datum/equipment_preset/covenant/ruuhtian/sniper/carbine::name = /datum/equipment_preset/covenant/ruuhtian/sniper/carbine,
		// SS220 EDIT - END
	)

	if(!check_rights(R_DEBUG))
		return

	if(tgui_input_list(usr, "Press Enter to select the home turf of the sniper.", "Home Turf", list("Enter", "Cancel")) != "Enter")
		return

	var/turf/home_turf = get_turf(usr)
	var/turf/target_turf

	while(TRUE)
		if(tgui_input_list(usr, "Press Enter to select the center of the sniper's overwatch. This must be within 30 tiles and not be blocked.", "Target Turf", list("Enter", "Cancel")) == "Enter")
			var/turf/maybe_target_turf = get_turf(usr)
			if(get_dist(home_turf, maybe_target_turf) > 30)
				to_chat(usr, SPAN_WARNING("This turf is too far away. Max range 30, attempted range [get_dist(home_turf, target_turf)]."))
				continue

			if(locate(/turf/closed) in get_line(home_turf, maybe_target_turf))
				to_chat(usr, SPAN_WARNING("A wall is located between the home and target turf."))
				continue
			target_turf = maybe_target_turf
		break

	if(!home_turf || !target_turf)
		return

	var/mob/living/carbon/human/ai_human = new()
	var/datum/component/human_ai/ai_comp = ai_human.AddComponent(/datum/component/human_ai)
	var/chosen_equipment_name = tgui_input_list(usr, "Select sniper equipment.", "Sniper Equipment", sniper_equipment_presets)
	if(!chosen_equipment_name)
		qdel(ai_human)
		return
	arm_equipment(ai_human, sniper_equipment_presets[chosen_equipment_name], TRUE)

	var/datum/human_ai_context/setup_context = ai_comp.ai_brain.create_context()
	var/datum/human_tied_controller/controller = setup_context.controller
	if(!controller)
		qdel(setup_context)
		qdel(ai_human)
		return
	controller.forceMove(home_turf)
	qdel(setup_context)
	ai_comp.ai_brain.set_sniper_home(home_turf, get_cardinal_dir(home_turf, target_turf))

	to_chat(usr, SPAN_NOTICE("Sniper has been created."))
