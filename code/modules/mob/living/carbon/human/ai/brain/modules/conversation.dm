/datum/human_ai_module/conversation
	module_id = "conversation"
	required_module_types = list(/datum/human_ai_module/combat)

	/// If TRUE, this AI is currently in a conversation with others
	var/in_conversation = FALSE
	/// The chance that the AI will try to initiate a conversation. Trying to initiate a conversation is on a 1 second cooldown, so this is really every 5 ticks
	/// Disabled until more conversations are added
	var/conversation_start_prob = 0 //0.75 // at 1 chance / sec, this'll mean we hit the equivalent of a 50% chance of a conversation at ~90 chances, which would take ~90 seconds
	COOLDOWN_DECLARE(conversation_start_cooldown)
	/// Cooldown upon a successful conversation, started on everyone involved at the end of the conversation
	COOLDOWN_DECLARE(conversation_success_cooldown)
	/// Length of the conversation success cooldown
	var/conversation_success_cooldown_time = 45 SECONDS

/datum/human_ai_module/conversation/proc/is_in_conversation()
	return in_conversation

/datum/human_ai_module/conversation/proc/is_owner_in_combat()
	return brain.is_in_combat()

/datum/human_ai_module/conversation/proc/can_try_start()
	if(!COOLDOWN_FINISHED(src, conversation_start_cooldown))
		return FALSE

	COOLDOWN_START(src, conversation_start_cooldown, 1 SECONDS)

	if(!can_participate())
		return FALSE

	return prob(conversation_start_prob)

/datum/human_ai_module/conversation/proc/can_participate()
	var/datum/human_tied_controller/controller = context?.controller
	if(!context?.can_continue())
		return FALSE

	if(is_owner_in_combat() || in_conversation || controller.is_health_below(HEALTH_THRESHOLD_CRIT))
		return FALSE

	return TRUE

/datum/human_ai_module/conversation/proc/can_continue()
	var/datum/human_tied_controller/controller = context?.controller
	if(!context?.can_continue())
		return FALSE

	if(is_owner_in_combat() || !is_in_conversation() || !controller || controller.is_health_below(HEALTH_THRESHOLD_CRIT))
		return FALSE

	return TRUE

/datum/human_ai_module/conversation/proc/start_conversation()
	in_conversation = TRUE

/datum/human_ai_module/conversation/proc/end_conversation(success = FALSE)
	in_conversation = FALSE
	if(success)
		COOLDOWN_START(src, conversation_success_cooldown, conversation_success_cooldown_time)
