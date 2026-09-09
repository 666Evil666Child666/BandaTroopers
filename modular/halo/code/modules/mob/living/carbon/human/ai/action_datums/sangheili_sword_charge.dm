/datum/ai_action/sangheili_sword_charge
	name = "Рывок сангхейли с мечом"
	action_flags = ACTION_USING_HANDS | ACTION_USING_LEGS
	required_ai_modules = list(/datum/human_ai_module/targeting, /datum/human_ai_module/navigation, /datum/human_ai_module/inventory, /datum/human_ai_module/action_runtime)

/datum/ai_action/sangheili_sword_charge/Added()
	var/datum/human_ai_brain/brain = context?.brain
	if(!brain)
		return

	brain.halo_covenant_end_cover()

/datum/ai_action/sangheili_sword_charge/get_context_weight(datum/human_ai_context/context)
	var/datum/human_ai_brain/brain = context?.brain
	if(!brain?.halo_sangheili_runtime)
		return 0

	if(!brain.halo_covenant_can_run_movement_action(TRUE))
		return 0

	var/atom/threat = brain.halo_covenant_get_threat_atom()
	if(!threat)
		return 0

	if(!brain.halo_sangheili_should_sword_charge(threat))
		return 0

	if(brain.halo_sangheili_sword_only)
		return 60

	return 45

/datum/ai_action/sangheili_sword_charge/Destroy(force, ...)
	var/datum/human_ai_brain/brain = context?.brain
	if(!brain?.halo_sangheili_should_keep_sword_drawn())
		if(!brain?.halo_sangheili_restore_ranged_state())
			brain?.halo_sangheili_holster_sword()
	return ..()

/datum/ai_action/sangheili_sword_charge/trigger_action()
	. = ..()
	if(. == ONGOING_ACTION_COMPLETED)
		return .

	var/datum/human_ai_brain/brain = context?.brain
	var/datum/human_tied_controller/controller = context?.controller
	if(!brain || !controller)
		return ONGOING_ACTION_COMPLETED

	var/atom/threat = brain.halo_covenant_get_threat_atom()
	if(!brain.halo_sangheili_runtime || !brain.has_valid_tied_human() || !threat || !brain.halo_covenant_can_run_movement_action(TRUE) || !brain.halo_sangheili_should_sword_charge(threat))
		if(!brain.halo_sangheili_restore_ranged_state())
			brain.halo_sangheili_holster_sword()
		return ONGOING_ACTION_COMPLETED

	brain.halo_covenant_end_cover()
	controller.set_combat_intent()

	var/obj/item/weapon/covenant/energy_sword/sword = brain.halo_sangheili_draw_sword()
	if(!sword && !brain.halo_sangheili_sword_only)
		brain.halo_sangheili_restore_ranged_state()
		return ONGOING_ACTION_COMPLETED

	if(controller.get_distance_to(threat) <= 1)
		if(!sword)
			brain.halo_covenant_clear_hands()
		controller.face_atom(threat)
		INVOKE_ASYNC(controller, TYPE_PROC_REF(/datum/human_tied_controller, do_click), threat, "", list())
		return ONGOING_ACTION_UNFINISHED_BLOCK

	if(!brain.halo_covenant_move_to_threat(threat))
		return ONGOING_ACTION_COMPLETED
	return ONGOING_ACTION_UNFINISHED_BLOCK
