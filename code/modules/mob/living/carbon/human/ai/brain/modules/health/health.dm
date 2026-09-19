#define HUMAN_AI_TREATMENT_STAGE_BRUTE 1
#define HUMAN_AI_TREATMENT_STAGE_BLEED 2
#define HUMAN_AI_TREATMENT_STAGE_BONEBREAK 3
#define HUMAN_AI_TREATMENT_STAGE_BURN 4
#define HUMAN_AI_TREATMENT_STAGE_PAIN 5
#define HUMAN_AI_TREATMENT_STAGE_TOX 6
#define HUMAN_AI_TREATMENT_STAGE_OXY 7

#define HUMAN_AI_TREATMENT_URGENCY_STABLE 1
#define HUMAN_AI_TREATMENT_URGENCY_SEVERE 2
#define HUMAN_AI_TREATMENT_URGENCY_CRITICAL 3

/datum/human_ai_module/health
	module_id = "health"
	required_module_types = list(/datum/human_ai_module/faction, /datum/human_ai_module/profile)

	/// At what percentage of max HP to start searching for medical treatment
	var/healing_start_threshold = 0.7
	/// Requires this much damage of one type to consider it a problem
	var/damage_problem_threshold = 5
	/// Pain percentage (out of 100) for the AI to consider using painkillers
	var/pain_percentage_threshold = 1

	/// Are we currently treating someone?
	var/healing_someone = FALSE
	var/treatment_generation = 0 // SS220 EDIT: cancellation invalidates every suspended frame of this treatment
	/// Patient currently reserved by this health module.
	var/mob/living/carbon/human/current_treatment_target

	/// Reference for found injured ally
	var/mob/living/carbon/human/found_injured_ally

	/// Cooldown on using pills to avoid OD. This isn't the best solution as it prevents the AI from using more than 1 pill of any kind every 20s, but it'll work for now
	COOLDOWN_DECLARE(pill_use_cooldown)
	/// How long to wait before repeating pill-based treatment for the same patient and treatment stage.
	var/pill_treatment_effect_wait = 45 SECONDS
	/// How long to wait before repeating injected reagent treatment for the same patient and treatment stage.
	var/injected_treatment_effect_wait = 15 SECONDS
	/// Patient-stage treatment repeat locks. Keyed by patient ref and treatment stage.
	var/list/recent_patient_treatments = list()

	/// How many stacks of "wasn't able to treat" this AI has. If these stacks pass a certain threshold, the AI can no longer be treated by others for a small period of time. Stacks decay when not being accumulated
	var/cant_be_treated_stacks = 0

	/// How many stacks are required to stop this AI from recieving treatment
	var/treatment_stack_threshold = 10

/datum/human_ai_module/health/Destroy(force, ...)
	cancel_treatment() // SS220 EDIT: invalidate sleeping work before clearing the owning brain
	lose_injured_ally()
	return ..()

/datum/human_ai_module/health/reset_module()
	cancel_treatment() // SS220 EDIT: reset invalidates suspended treatment before clearing actions
	lose_injured_ally()
	recent_patient_treatments = list()

/datum/human_ai_module/health/suspend_module(clear_inventory = FALSE)
	lose_injured_ally()
	cancel_treatment() // SS220 EDIT: resumed AI must not inherit an old treatment continuation
	recent_patient_treatments = list()

/datum/human_ai_module/health/proc/is_treating()
	return healing_someone

/datum/human_ai_module/health/proc/can_retry_self_treatment()
	return cant_be_treated_stacks < treatment_stack_threshold

/datum/human_ai_module/health/proc/increment_treatment_stacks()
	cant_be_treated_stacks++
	addtimer(CALLBACK(src, PROC_REF(clear_treatment_stacks)), 5 SECONDS, TIMER_UNIQUE | TIMER_NO_HASH_WAIT | TIMER_OVERRIDE)

/datum/human_ai_module/health/proc/clear_treatment_stacks()
	cant_be_treated_stacks = 0
