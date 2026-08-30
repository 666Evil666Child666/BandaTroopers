/datum/human_tied_controller
	/// Brain that owns this tied-human controller.
	var/datum/human_ai_brain/brain
	/// Human puppet currently tied to the owning brain.
	var/mob/living/carbon/human/tied_human
	/// Local move delay guard for controller-owned movement.
	var/ai_move_delay = 0

/datum/human_tied_controller/New(datum/human_ai_brain/new_brain, mob/living/carbon/human/new_human)
	. = ..()
	if(new_brain || new_human)
		attach(new_brain, new_human)

/datum/human_tied_controller/Destroy(force, ...)
	detach()
	return ..()

/datum/human_tied_controller/proc/attach(datum/human_ai_brain/new_brain, mob/living/carbon/human/new_human, sync_brain = TRUE)
	if(new_brain)
		brain = new_brain
	if(new_human)
		tied_human = new_human
	else if(!tied_human && brain?.tied_human)
		tied_human = brain.tied_human
	if(sync_brain)
		sync_to_brain()
	return has_tied_human()

/datum/human_tied_controller/proc/set_brain(datum/human_ai_brain/new_brain, sync_brain = FALSE)
	brain = new_brain
	if(sync_brain)
		sync_to_brain()

/datum/human_tied_controller/proc/set_tied_human(mob/living/carbon/human/new_human, sync_brain = FALSE)
	tied_human = new_human
	if(sync_brain)
		sync_to_brain()

/datum/human_tied_controller/proc/sync_to_brain()
	if(brain)
		brain.tied_human = tied_human
	return TRUE

/datum/human_tied_controller/proc/detach(clear_ai_flag = FALSE, sync_brain = TRUE)
	if(clear_ai_flag)
		clear_ai_controlled()
	var/datum/human_ai_brain/old_brain = brain
	if(sync_brain && old_brain && (old_brain.tied_human == tied_human))
		old_brain.tied_human = null
	brain = null
	tied_human = null
	ai_move_delay = 0
	return TRUE
