/datum/ai_action/machinegunner_nest
	name = "Machinegunner Nest"
	action_flags = ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/emplacement, /datum/human_ai_module/guns, /datum/human_ai_module/inventory, /datum/human_ai_module/navigation, /datum/human_ai_module/profile)
	var/initial_view
	var/initial_reload_line_chance

/datum/ai_action/machinegunner_nest/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_ai_module/inventory/inventory = context?.get_module(/datum/human_ai_module/inventory)
	if(!brain || !inventory)
		return 0

	if(!brain.has_machinegunner_home())
		return 0

	if(brain.has_tried_reload())
		return 0

	if(brain.should_block_stationary_fire_for_cover())
		return 0

	if(!inventory.has_primary_weapon())
		return 0

	if(brain.is_healing_someone())
		return 0

	return 12

/datum/ai_action/machinegunner_nest/Added()
	var/datum/human_ai_brain/brain = context?.brain
	if(!brain)
		return

	initial_view = brain.get_view_distance()
	initial_reload_line_chance = brain.get_reload_line_chance()
	brain.set_reload_line_chance(0)

/datum/ai_action/machinegunner_nest/Destroy(force, ...)
	var/datum/human_ai_brain/brain = context?.brain
	if(brain)
		brain.set_view_distance(initial_view)
		brain.set_reload_line_chance(initial_reload_line_chance)
	return ..()

/datum/ai_action/machinegunner_nest/trigger_action()
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

	var/turf/machinegunner_home = brain.get_machinegunner_home()
	if(QDELETED(machinegunner_home))
		return ONGOING_ACTION_COMPLETED

	if(controller.get_distance_to(machinegunner_home) > 0)
		if(!brain.move_to_turf(machinegunner_home))
			return ONGOING_ACTION_COMPLETED

	if(!controller.get_distance_to(machinegunner_home))
		brain.set_view_distance(30)
		controller.face_dir(brain.get_machinegunner_dir())

	if(!brain.should_reload())
		inventory.unholster_primary()
		inventory.ensure_primary_hand(primary_weapon)
		inventory.wield_primary()

	return ONGOING_ACTION_UNFINISHED


/datum/admins/proc/get_human_ai_machinegunner_equipment_presets()
	var/list/equipment_presets = list(
		/datum/equipment_preset/rebel/soldier::name = /datum/equipment_preset/rebel/soldier,
		/datum/equipment_preset/clf/soldier::name = /datum/equipment_preset/clf/soldier,
		/datum/equipment_preset/canc/remnant::name = /datum/equipment_preset/canc/remnant,
		/datum/equipment_preset/canc/remnant/snowman::name = /datum/equipment_preset/canc/remnant/snowman,
		/datum/equipment_preset/canc/newblood_machinegunner::name = /datum/equipment_preset/canc/newblood_machinegunner,
		/datum/equipment_preset/canc/machinegunner::name = /datum/equipment_preset/canc/machinegunner,
		/datum/equipment_preset/canc_dogwar/militia/lmg::name = /datum/equipment_preset/canc_dogwar/militia/lmg,
		/datum/equipment_preset/canc_dogwar/soldier/machinegunner::name = /datum/equipment_preset/canc_dogwar/soldier/machinegunner,
		/datum/equipment_preset/canc/machinegunner/snowman::name = /datum/equipment_preset/canc/machinegunner/snowman,
		/datum/equipment_preset/upp/machinegunner::name = /datum/equipment_preset/upp/machinegunner,
		/datum/equipment_preset/contractor/duty/heavy::name = /datum/equipment_preset/contractor/duty/heavy,
		/datum/equipment_preset/pmc/gunner::name = /datum/equipment_preset/pmc/gunner,
		/datum/equipment_preset/uscm/smartgunner_equipped::name = /datum/equipment_preset/uscm/smartgunner_equipped,
		/datum/equipment_preset/usa/gunner::name = /datum/equipment_preset/usa/gunner,
		/datum/equipment_preset/usa/heavygunner::name = /datum/equipment_preset/usa/heavygunner,
		/datum/equipment_preset/royal_marine/machinegun::name = /datum/equipment_preset/royal_marine/machinegun,
		/datum/equipment_preset/contractor/covert/heavy::name = /datum/equipment_preset/contractor/covert/heavy,
		/datum/equipment_preset/other/freelancer/machinegunner::name = /datum/equipment_preset/other/freelancer/machinegunner,
		/datum/equipment_preset/other/elite_merc/heavy::name = /datum/equipment_preset/other/elite_merc/heavy,
		/datum/equipment_preset/rebel/soldier/machinegunner::name = /datum/equipment_preset/rebel/soldier/machinegunner,
		/datum/equipment_preset/clf/soldier/machinegunner::name = /datum/equipment_preset/clf/soldier/machinegunner,
		/datum/equipment_preset/mercenary/sentinel/mg::name = /datum/equipment_preset/mercenary/sentinel/mg,
		/datum/equipment_preset/fil/rifleman/mg::name = /datum/equipment_preset/fil/rifleman/mg,
	)
	if(hascall(src, "modular_append_human_ai_machinegunner_equipment_presets"))
		call(src, "modular_append_human_ai_machinegunner_equipment_presets")(equipment_presets)
	return equipment_presets

/datum/admins/proc/create_human_ai_machinegunner()
	set name = "Create Human AI machinegunner"
	set category = "Game Master.HumanAI"

	var/list/machinegunner_equipment_presets = get_human_ai_machinegunner_equipment_presets()

	if(!check_rights(R_DEBUG))
		return

	if(tgui_input_list(usr, "Press Enter to select the home turf of the machinegunner.", "Home Turf", list("Enter", "Cancel")) != "Enter")
		return

	var/turf/home_turf = get_turf(usr)
	var/turf/target_turf

	while(TRUE)
		if(tgui_input_list(usr, "Press Enter to select the center of the machinegunner's overwatch. This must be within 30 tiles and not be blocked.", "Target Turf", list("Enter", "Cancel")) == "Enter")
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
	var/chosen_equipment_name = tgui_input_list(usr, "Select machinegunner equipment.", "machinegunner Equipment", machinegunner_equipment_presets)
	if(!chosen_equipment_name)
		qdel(ai_human)
		return
	arm_equipment(ai_human, machinegunner_equipment_presets[chosen_equipment_name], TRUE)

	var/datum/human_ai_context/setup_context = ai_comp.ai_brain.create_context()
	var/datum/human_tied_controller/controller = setup_context.controller
	if(!controller)
		qdel(setup_context)
		qdel(ai_human)
		return
	controller.forceMove(home_turf)
	qdel(setup_context)
	ai_comp.ai_brain.set_machinegunner_home(home_turf, get_cardinal_dir(home_turf, target_turf))

	to_chat(usr, SPAN_NOTICE("machinegunner has been created."))
