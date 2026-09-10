/datum/human_ai_event
	var/event_type
	var/datum/human_ai_brain/source_brain
	var/datum/human_ai_context/context
	var/list/data

/datum/human_ai_event/New(new_event_type, datum/human_ai_brain/new_source_brain, list/new_data)
	. = ..()
	event_type = new_event_type
	source_brain = new_source_brain
	context = source_brain?.create_context()
	data = new_data ? new_data.Copy() : list()

/datum/human_ai_event/Destroy(force, ...)
	QDEL_NULL(context)
	source_brain = null
	data = null
	return ..()

/datum/human_ai_brain/proc/register_ai_event_subscriber(event_type, datum/human_ai_module/module)
	if(!event_type || !module)
		return FALSE

	LAZYORASSOCLIST(ai_event_subscribers, event_type, module)
	return TRUE

/datum/human_ai_brain/proc/unregister_ai_event_subscriber(datum/human_ai_module/module)
	if(!ai_event_subscribers || !module)
		return FALSE

	for(var/event_type as anything in ai_event_subscribers)
		LAZYREMOVEASSOC(ai_event_subscribers, event_type, module)
	return TRUE

/datum/human_ai_brain/proc/emit_ai_event(event_type, list/event_data = null)
	if(!event_type || !ai_event_subscribers)
		return FALSE

	var/list/subscribers = ai_event_subscribers[event_type]
	if(!length(subscribers))
		return FALSE

	var/list/subscribers_to_notify = subscribers.Copy()
	var/datum/human_ai_event/event = new(event_type, src, event_data)
	for(var/datum/human_ai_module/module as anything in subscribers_to_notify)
		if(QDELETED(module))
			continue
		module.dispatch_ai_event(event)

	qdel(event)
	return TRUE
