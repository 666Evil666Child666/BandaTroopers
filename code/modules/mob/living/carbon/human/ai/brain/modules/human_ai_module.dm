/datum/human_ai_module
	var/datum/human_ai_brain/brain

/datum/human_ai_module/New(datum/human_ai_brain/new_brain)
	. = ..()
	brain = new_brain

/datum/human_ai_module/Destroy(force, ...)
	brain = null
	return ..()
