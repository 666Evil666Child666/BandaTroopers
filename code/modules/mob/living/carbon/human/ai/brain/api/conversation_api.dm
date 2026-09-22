// Human AI conversation API.
// Idle conversation participation checks.

/datum/human_ai_brain/proc/can_try_start_conversation()
	var/datum/human_ai_module/conversation/conversation_module = get_conversation_module()
	return conversation_module?.can_try_start()

/datum/human_ai_brain/proc/can_participate_in_conversation()
	var/datum/human_ai_module/conversation/conversation_module = get_conversation_module()
	return conversation_module?.can_participate()

/datum/human_ai_brain/proc/can_continue_conversation()
	var/datum/human_ai_module/conversation/conversation_module = get_conversation_module()
	return conversation_module?.can_continue()
