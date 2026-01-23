/obj/structure/closet/secure_closet/marine_personal
	name = "personal locker"
	desc = "It's an immobile card-locked storage unit."
	icon_state = "secure1"
	can_be_stacked = TRUE
	var/owner
	var/has_cryo_gear = TRUE

	var/job = "DO NOT USE!!!"
	var/x_to_linked_spawn_turf
	var/y_to_linked_spawn_turf
	var/turf/linked_spawn_turf

	var/need_check_content = TRUE // SS220 EDIT - fixes - переменная для единоразовой проверки контента

/obj/structure/closet/secure_closet/marine_personal/get_examine_text(mob/user)
	. = ..()
	. += SPAN_NOTICE("It has a name tag[owner ? ": [owner]." : ". They are still in hypersleep..."]")

/obj/structure/closet/secure_closet/marine_personal/Initialize(mapload, ...)
	. = ..()
	GLOB.personal_closets += src

	if(x_to_linked_spawn_turf || y_to_linked_spawn_turf)
		linked_spawn_turf = locate(x + x_to_linked_spawn_turf, y + y_to_linked_spawn_turf, z)

	if(has_cryo_gear)
		spawn_gear()

/obj/structure/closet/secure_closet/marine_personal/Destroy()
	GLOB.personal_closets -= src
	return ..()

/obj/structure/closet/secure_closet/marine_personal/allowed(mob/M)
	if(owner == M.real_name)
		// SS220 EDIT - START - Squad Frequency Fix
		if(need_check_content && ishuman(M))
			var/mob/living/carbon/human/H = M
			if(H.assigned_squad)
				var/found_headset = FALSE // На случай если не найдем и надо будет искать еще раз
				for(var/obj/item/device/radio/headset/headset in contents)
					headset.set_frequency(H.assigned_squad.radio_freq)
					found_headset = TRUE
				if(found_headset)
					need_check_content = FALSE
		// SS220 EDIT - END - Squad Frequency Fix
		return TRUE
	return FALSE

// ==USCM Standard== //

/obj/structure/closet/secure_closet/marine_personal/proc/spawn_gear()
	new /obj/item/clothing/under/marine(src)
	new /obj/item/clothing/shoes/marine/knife(src)
	new /obj/item/device/radio/headset/almayer/marine/solardevils(src)
	need_check_content = TRUE // SS220 EDIT

/obj/structure/closet/secure_closet/marine_personal/rifleman
	job = JOB_SQUAD_MARINE

/obj/structure/closet/secure_closet/marine_personal/smartgunner
	job = JOB_SQUAD_SMARTGUN

/obj/structure/closet/secure_closet/marine_personal/corpsman
	job = JOB_SQUAD_MEDIC

/obj/structure/closet/secure_closet/marine_personal/squad_leader
	job = JOB_SQUAD_TEAM_LEADER

/obj/structure/closet/secure_closet/marine_personal/platoon_leader
	job = JOB_SQUAD_LEADER

/obj/structure/closet/secure_closet/marine_personal/platoon_leader/spawn_gear()
	new /obj/item/clothing/under/marine(src)
	new /obj/item/clothing/shoes/marine/knife(src)
	new /obj/item/device/radio/headset/almayer/marine/solardevils/seclead(src)

/obj/structure/closet/secure_closet/marine_personal/platoon_commander
	job = JOB_SO

/obj/structure/closet/secure_closet/marine_personal/platoon_commander/spawn_gear()
	new /obj/item/clothing/under/marine(src)
	new /obj/item/clothing/under/marine/officer/boiler(src)
	new /obj/item/clothing/head/cmcap/bridge(src)
	new /obj/item/clothing/suit/storage/jacket/marine/service(src)
	new /obj/item/clothing/under/marine/officer/bridge(src)
	new /obj/item/clothing/shoes/laceup(src)
	new /obj/item/clothing/head/marine/peaked/service(src)
	new /obj/item/clothing/suit/storage/jacket/marine/dress/officer/bomber(src)
	new /obj/item/clothing/shoes/marine/knife(src)
	new /obj/item/device/radio/headset/almayer/marine/solardevils/pltco(src)

// ==UPP== //

/obj/structure/closet/secure_closet/marine_personal/upp/spawn_gear()
	new /obj/item/clothing/head/uppcap/beret/naval(src)
	new /obj/item/clothing/under/marine/veteran/UPP(src)
	new /obj/item/clothing/shoes/marine/upp(src)
	new /obj/item/device/radio/headset/almayer/marine/solardevils/upp(src)

/obj/structure/closet/secure_closet/marine_personal/upp/rifleman
	job = JOB_SQUAD_MARINE

/obj/structure/closet/secure_closet/marine_personal/upp/smartgunner
	job = JOB_SQUAD_SMARTGUN

/obj/structure/closet/secure_closet/marine_personal/upp/corpsman
	job = JOB_SQUAD_MEDIC

/obj/structure/closet/secure_closet/marine_personal/upp/squad_leader
	job = JOB_SQUAD_TEAM_LEADER

/obj/structure/closet/secure_closet/marine_personal/upp/platoon_leader
	job = JOB_SQUAD_LEADER

/obj/structure/closet/secure_closet/marine_personal/upp/platoon_commander
	job = JOB_SO

/obj/structure/closet/secure_closet/marine_personal/upp/platoon_commander/spawn_gear()
	new /obj/item/clothing/head/uppcap/beret/naval(src)
	new /obj/item/clothing/under/marine/veteran/UPP/naval(src)
	new /obj/item/clothing/shoes/marine/upp(src)
	new /obj/item/device/radio/headset/almayer/marine/solardevils/upp(src)
	new /obj/item/clothing/suit/storage/jacket/marine/upp/naval(src)
	new /obj/item/clothing/suit/storage/jacket/marine/upp(src)

// ==USCM FORECON== //

/obj/structure/closet/secure_closet/marine_personal/forecon/spawn_gear()
	new /obj/item/clothing/under/marine/standard(src)
	new /obj/item/clothing/shoes/marine/knife(src)
	new /obj/item/device/radio/headset/almayer/marine/solardevils/forecon(src)

/obj/structure/closet/secure_closet/marine_personal/forecon/rifleman
	job = JOB_SQUAD_MARINE

/obj/structure/closet/secure_closet/marine_personal/forecon/smartgunner
	job = JOB_SQUAD_SMARTGUN

/obj/structure/closet/secure_closet/marine_personal/forecon/corpsman
	job = JOB_SQUAD_MEDIC

/obj/structure/closet/secure_closet/marine_personal/forecon/squad_leader
	job = JOB_SQUAD_TEAM_LEADER

/obj/structure/closet/secure_closet/marine_personal/forecon/platoon_leader
	job = JOB_SQUAD_LEADER

/obj/structure/closet/secure_closet/marine_personal/forecon/rto
	job = JOB_SQUAD_RTO

// ==WY PMC== //

/obj/structure/closet/secure_closet/marine_personal/pmc/spawn_gear()
	new /obj/item/clothing/under/marine/veteran/pmc(src)
	new /obj/item/device/radio/headset/distress/pmc/platoon(src)
	new /obj/item/clothing/shoes/marine/civilian/knife(src)

/obj/structure/closet/secure_closet/marine_personal/pmc/rifleman
	job = JOB_SQUAD_MARINE

/obj/structure/closet/secure_closet/marine_personal/pmc/smartgunner
	job = JOB_SQUAD_SMARTGUN

/obj/structure/closet/secure_closet/marine_personal/pmc/corpsman
	job = JOB_SQUAD_MEDIC

/obj/structure/closet/secure_closet/marine_personal/pmc/squad_leader
	job = JOB_SQUAD_TEAM_LEADER

/obj/structure/closet/secure_closet/marine_personal/pmc/platoon_leader
	job = JOB_SQUAD_LEADER

/obj/structure/closet/secure_closet/marine_personal/pmc/platoon_commander
	job = JOB_SO

/obj/structure/closet/secure_closet/marine_personal/pmc/platoon_commander/spawn_gear()
	new /obj/item/clothing/head/beret/pmc(src)
	new /obj/item/clothing/under/liaison_suit/formal(src)
	new /obj/item/clothing/shoes/laceup(src)
	new /obj/item/device/radio/headset/distress/pmc/platoon/cmd(src)
	new /obj/item/clothing/suit/storage/jacket/marine/corporate/formal(src)

// ==Royal Marines== //

/obj/structure/closet/secure_closet/marine_personal/rmc/spawn_gear()
	new /obj/item/clothing/head/cmcap/royal_marine(src)
	new /obj/item/clothing/under/marine/veteran/royal_marine(src)
	new /obj/item/device/radio/headset/almayer/marine/solardevils/rmc(src)
	new /obj/item/clothing/shoes/marine/rmc/knife(src)

/obj/structure/closet/secure_closet/marine_personal/rmc/troop_commander/spawn_gear()
	new /obj/item/clothing/head/cmcap/royal_marine(src)
	new /obj/item/clothing/under/marine/veteran/royal_marine/lt(src)
	new /obj/item/clothing/accessory/ranks/rmc/o1(src)
	new /obj/item/device/radio/headset/almayer/marine/solardevils/rmc(src)
	new /obj/item/clothing/shoes/marine/rmc/knife(src)

/obj/structure/closet/secure_closet/marine_personal/rmc/rifleman
	job = JOB_TWE_RMC_RIFLEMAN

/obj/structure/closet/secure_closet/marine_personal/rmc/smartgunner
	job = JOB_TWE_RMC_SMARTGUNNER

/obj/structure/closet/secure_closet/marine_personal/rmc/marksman
	job = JOB_TWE_RMC_MARKSMAN

/obj/structure/closet/secure_closet/marine_personal/rmc/medic
	job = JOB_TWE_RMC_MEDIC

/obj/structure/closet/secure_closet/marine_personal/rmc/engi
	job = JOB_TWE_RMC_ENGI

/obj/structure/closet/secure_closet/marine_personal/rmc/gunner
	job = JOB_TWE_RMC_BREACHER

/obj/structure/closet/secure_closet/marine_personal/rmc/team_leader
	job = JOB_TWE_RMC_TEAMLEADER

/obj/structure/closet/secure_closet/marine_personal/rmc/section_leader
	job = JOB_TWE_RMC_SECTIONLEADER

/obj/structure/closet/secure_closet/marine_personal/rmc/troop_leader
	job = JOB_TWE_RMC_TROOPLEADER

/obj/structure/closet/secure_closet/marine_personal/rmc/troop_commander
	job = JOB_TWE_RMC_LIEUTENANT
