// Шкафчики под отряды и их привязка
/obj/structure/closet/secure_closet/marine_personal
	var/squad_type

/obj/structure/closet/secure_closet/marine_personal/proc/is_correct_squad(mob/living/carbon/human/H)
	if(!squad_type)
		return TRUE
	if(!H.assigned_squad)
		return FALSE
	if(H.assigned_squad.name == squad_type)
		return TRUE

	// Отдельная проверка для первого сквада
	if(squad_type == SQUAD_MARINE_1)
		// Так как связаны с ренеймом платунов
		if(H.assigned_squad.name == GLOB.main_platoon_name)
			return TRUE
	return FALSE


// Пехотинец
/obj/structure/closet/secure_closet/marine_personal/rifleman
	icon = 'modular/squads/icons/closet.dmi'
	icon_state = "secure1-rm"
	icon_closed = "secure-rm"
	icon_locked = "secure1-rm"
	icon_opened = "secureopen-rm"
	icon_broken = "securebroken-rm"
	icon_off = "secureoff-rm"

/obj/structure/closet/secure_closet/marine_personal/rifleman/s1
	squad_type = SQUAD_MARINE_1

/obj/structure/closet/secure_closet/marine_personal/rifleman/s2
	squad_type = SQUAD_MARINE_2

/obj/structure/closet/secure_closet/marine_personal/rifleman/s3
	squad_type = SQUAD_MARINE_3

/obj/structure/closet/secure_closet/marine_personal/rifleman/s4
	squad_type = SQUAD_MARINE_4

/obj/structure/closet/secure_closet/marine_personal/rifleman/s5
	squad_type = SQUAD_MARINE_5


// Смартганнер
/obj/structure/closet/secure_closet/marine_personal/smartgunner
	icon = 'modular/squads/icons/closet.dmi'
	icon_state = "secure1-sg"
	icon_closed = "secure-sg"
	icon_locked = "secure1-sg"
	icon_opened = "secureopen-sg"
	icon_broken = "securebroken-sg"
	icon_off = "secureoff-sg"

/obj/structure/closet/secure_closet/marine_personal/smartgunner/s1
	squad_type = SQUAD_MARINE_1

/obj/structure/closet/secure_closet/marine_personal/smartgunner/s2
	squad_type = SQUAD_MARINE_2

/obj/structure/closet/secure_closet/marine_personal/smartgunner/s3
	squad_type = SQUAD_MARINE_3

/obj/structure/closet/secure_closet/marine_personal/smartgunner/s4
	squad_type = SQUAD_MARINE_4

/obj/structure/closet/secure_closet/marine_personal/smartgunner/s5
	squad_type = SQUAD_MARINE_5


// Медик
/obj/structure/closet/secure_closet/marine_personal/corpsman
	icon = 'modular/squads/icons/closet.dmi'
	icon_state = "secure1-med"
	icon_closed = "secure-med"
	icon_locked = "secure1-med"
	icon_opened = "secureopen-med"
	icon_broken = "securebroken-med"
	icon_off = "secureoff-med"

/obj/structure/closet/secure_closet/marine_personal/corpsman/s1
	squad_type = SQUAD_MARINE_1

/obj/structure/closet/secure_closet/marine_personal/corpsman/s2
	squad_type = SQUAD_MARINE_2

/obj/structure/closet/secure_closet/marine_personal/corpsman/s3
	squad_type = SQUAD_MARINE_3

/obj/structure/closet/secure_closet/marine_personal/corpsman/s4
	squad_type = SQUAD_MARINE_4

/obj/structure/closet/secure_closet/marine_personal/corpsman/s5
	squad_type = SQUAD_MARINE_5


// Спек
/obj/structure/closet/secure_closet/marine_personal/specialist
	icon = 'modular/squads/icons/closet.dmi'
	icon_state = "secure1-spec"
	icon_closed = "secure-spec"
	icon_locked = "secure1-spec"
	icon_opened = "secureopen-spec"
	icon_broken = "securebroken-spec"
	icon_off = "secureoff-spec"

/obj/structure/closet/secure_closet/marine_personal/specialist/s1
	squad_type = SQUAD_MARINE_1

/obj/structure/closet/secure_closet/marine_personal/specialist/s2
	squad_type = SQUAD_MARINE_2

/obj/structure/closet/secure_closet/marine_personal/specialist/s3
	squad_type = SQUAD_MARINE_3

/obj/structure/closet/secure_closet/marine_personal/specialist/s4
	squad_type = SQUAD_MARINE_4

/obj/structure/closet/secure_closet/marine_personal/specialist/s5
	squad_type = SQUAD_MARINE_5


// ФТЛ
/obj/structure/closet/secure_closet/marine_personal/squad_leader
	icon = 'modular/squads/icons/closet.dmi'
	icon_state = "secure1-ftl"
	icon_closed = "secure-ftl"
	icon_locked = "secure1-ftl"
	icon_opened = "secureopen-ftl"
	icon_broken = "securebroken-ftl"
	icon_off = "secureoff-ftl"

/obj/structure/closet/secure_closet/marine_personal/squad_leader/s1
	squad_type = SQUAD_MARINE_1

/obj/structure/closet/secure_closet/marine_personal/squad_leader/s2
	squad_type = SQUAD_MARINE_2

/obj/structure/closet/secure_closet/marine_personal/squad_leader/s3
	squad_type = SQUAD_MARINE_3

/obj/structure/closet/secure_closet/marine_personal/squad_leader/s4
	squad_type = SQUAD_MARINE_4

/obj/structure/closet/secure_closet/marine_personal/squad_leader/s5
	squad_type = SQUAD_MARINE_5


// СЛ
/obj/structure/closet/secure_closet/marine_personal/platoon_leader
	icon = 'modular/squads/icons/closet.dmi'
	icon_state = "secure1-sl"
	icon_closed = "secure-sl"
	icon_locked = "secure1-sl"
	icon_opened = "secureopen-sl"
	icon_broken = "securebroken-sl"
	icon_off = "secureoff-sl"

/obj/structure/closet/secure_closet/marine_personal/platoon_leader/s1
	squad_type = SQUAD_MARINE_1

/obj/structure/closet/secure_closet/marine_personal/platoon_leader/s2
	squad_type = SQUAD_MARINE_2

/obj/structure/closet/secure_closet/marine_personal/platoon_leader/s3
	squad_type = SQUAD_MARINE_3

/obj/structure/closet/secure_closet/marine_personal/platoon_leader/s4
	squad_type = SQUAD_MARINE_4

/obj/structure/closet/secure_closet/marine_personal/platoon_leader/s5
	squad_type = SQUAD_MARINE_5


// SO
/obj/structure/closet/secure_closet/marine_personal/platoon_commander
	icon = 'modular/squads/icons/closet.dmi'
	icon_state = "secure1-so"
	icon_closed = "secure-so"
	icon_locked = "secure1-so"
	icon_opened = "secureopen-so"
	icon_broken = "securebroken-so"
	icon_off = "secureoff-so"
