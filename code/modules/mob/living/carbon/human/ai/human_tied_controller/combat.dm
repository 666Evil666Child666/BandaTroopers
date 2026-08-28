// Raw intent primitives

/datum/human_tied_controller/proc/set_intent(intent)
	if(!can_directly_control())
		return FALSE
	tied_human.a_intent_change(intent)
	return TRUE

/datum/human_tied_controller/proc/set_raw_intent(intent)
	if(!can_directly_control())
		return FALSE
	tied_human.a_intent = intent
	return TRUE

/datum/human_tied_controller/proc/a_intent_change(intent)
	return set_intent(intent)

/datum/human_tied_controller/proc/set_combat_intent()
	return set_intent(INTENT_HARM)

/datum/human_tied_controller/proc/set_grab_intent()
	return set_intent(INTENT_GRAB)

/datum/human_tied_controller/proc/set_safe_intent()
	return set_intent(INTENT_DISARM)

// Raw click/combat primitives

/datum/human_tied_controller/proc/wield(obj/item/weapon/gun/weapon)
	if(!can_directly_control() || !weapon)
		return FALSE
	weapon.wield(tied_human)
	return TRUE

/datum/human_tied_controller/proc/unwield_weapon(obj/item/weapon/gun/weapon)
	if(!can_directly_control() || !weapon)
		return FALSE
	weapon.unwield(tied_human)
	return TRUE

/datum/human_tied_controller/proc/do_click(atom/target, params = "", list/modifiers)
	if(!can_directly_control() || !target)
		return FALSE
	if(!modifiers)
		modifiers = list()
	tied_human.do_click(target, params, modifiers)
	return TRUE

/datum/human_tied_controller/proc/click_atom(atom/target)
	if(!do_click(target, "", list()))
		return FALSE
	face_atom(target)
	return TRUE

// Behavior/migration helpers

// Helper for reconstructing the old ranged-click behavior during migration.
/datum/human_tied_controller/proc/fire_click(atom/target)
	if(!target)
		return FALSE
	set_combat_intent()
	face_atom(target)
	return do_click(target, "", list())

// Helper for reconstructing the old melee-click behavior during migration.
/datum/human_tied_controller/proc/melee_click(atom/target)
	if(!target)
		return FALSE
	set_combat_intent()
	if(do_click(target, "", list()))
		face_atom(target)
		return TRUE
	return FALSE

// Raw throw primitives

/datum/human_tied_controller/proc/can_throw()
	return can_directly_control() && tied_human.get_active_hand()

/datum/human_tied_controller/proc/toggle_throw_mode(mode = THROW_MODE_NORMAL)
	if(!can_directly_control())
		return FALSE
	if(!tied_human.throw_mode)
		tied_human.toggle_throw_mode(mode)
	return TRUE

/datum/human_tied_controller/proc/throw_item(turf/target_turf)
	if(!can_throw() || !target_turf)
		return FALSE
	face_atom(target_turf)
	tied_human.throw_item(target_turf)
	return TRUE

/datum/human_tied_controller/proc/prime_grenade(obj/item/explosive/grenade/grenade)
	if(!can_directly_control() || !grenade)
		return FALSE
	grenade.attack_self(tied_human)
	return TRUE

// Grenade primitives

/datum/human_tied_controller/proc/can_hold_grenade(obj/item/explosive/grenade/grenade)
	return can_directly_control() && grenade

/datum/human_tied_controller/proc/is_holding_grenade(obj/item/explosive/grenade/grenade)
	return !!get_hand_holding(grenade)

/datum/human_tied_controller/proc/ensure_grenade_active(obj/item/explosive/grenade/grenade)
	if(!can_hold_grenade(grenade))
		return FALSE
	if(get_active_hand() == grenade)
		return TRUE
	if(get_inactive_hand() == grenade)
		swap_hand()
		return get_active_hand() == grenade
	return FALSE

/datum/human_tied_controller/proc/clear_active_hand_for_grenade()
	if(!get_active_hand())
		return TRUE
	return clear_active_hand_if_possible()

// Behavior/migration helpers

// Helper for reconstructing the old grenade pickup behavior during migration.
/datum/human_tied_controller/proc/hold_grenade(obj/item/explosive/grenade/grenade)
	if(!can_hold_grenade(grenade))
		return FALSE
	if(ensure_grenade_active(grenade))
		return TRUE
	if(!clear_active_hand_for_grenade())
		return FALSE
	return put_in_active_hand(grenade)

// Helper for reconstructing the old live-grenade drop behavior during migration.
/datum/human_tied_controller/proc/drop_live_grenade(obj/item/explosive/grenade/grenade)
	if(!can_hold_grenade(grenade) || !is_holding_grenade(grenade))
		return FALSE
	return drop_inv_item_on_ground(grenade)
