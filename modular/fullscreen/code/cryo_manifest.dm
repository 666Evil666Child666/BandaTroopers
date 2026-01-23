#define PEOPLE_PER_PAGE 12
#define LETTERS_BASE 1
#define LETTERS_PER_PEOPLE 5
#define LETTERS_GAIN 1.5
#define BASE_REMOVE_TIME (5 SECONDS)
#define PAGE_REMOVE_TIME (1.5 SECONDS)

// Начальный манифест при выходе из крио
/mob/living/carbon/human/play_manifest()
	var/list/manifest_lines = list()
	var/list/pages = list()

	// --- сбор данных ---
	for(var/mob/living/carbon/human/H as anything in GLOB.alive_human_list)
		if(H.z == ZTRAIT_GROUND)
			continue
		if(H.faction != faction)
			continue
		var/obj/item/card/id/card = H.get_idcard()
		var/datum/paygrade/account_paygrade = "UNKWN"
		if(card)
			account_paygrade = GLOB.paygrades[card.paygrade]

		manifest_lines += "[H.name]...[account_paygrade.prefix]/A[rand(1,99)]/TQ[rand(0,10)].0.[rand(100000,999999)]<br>"

	var/total_people = length(manifest_lines)
	if(!total_people)
		return

	// --- пагинация ---
	var/page_count = CEILING(total_people, PEOPLE_PER_PAGE) / PEOPLE_PER_PAGE

	for(var/i = 1, i <= page_count, i++)
		var/start = (i - 1) * PEOPLE_PER_PAGE + 1
		var/end = min(i * PEOPLE_PER_PAGE, total_people)

		var/page_text = ""
		for(var/j = start, j <= end, j++)
			page_text += manifest_lines[j]

		pages += page_text

	// --- титульник ---
	var/alert_type = /atom/movable/screen/text/screen_text/picture/starting
	var/platoon = "3rd Bat. 'Banda Troopers"

	switch(faction)
		if(FACTION_MARINE)
			if(assigned_squad && assigned_squad.name == SQUAD_LRRP)
				platoon = "Snake Eaters"
		if(FACTION_UPP)
			alert_type = /atom/movable/screen/text/screen_text/picture/starting/upp
			platoon = "Red Dawn"
		if(FACTION_PMC)
			alert_type = /atom/movable/screen/text/screen_text/picture/starting/wy
			platoon = "Azure-15"
		if(FACTION_TWE)
			alert_type = /atom/movable/screen/text/screen_text/picture/starting/twe
			platoon = "Gamma Troop"

	var/title_text = "<u>[SSmapping.configs[SHIP_MAP].map_name]<br></u>[platoon]<br><br>"

	// --- вывод страниц ---
	for(var/p = 1, p <= length(pages), p++)
		var/people_on_page = min(PEOPLE_PER_PAGE, total_people - ((p - 1) * PEOPLE_PER_PAGE))

		// +1.5 за каждые 5 человек, с округлением вниз
		var/override_letters = LETTERS_BASE + round((people_on_page / LETTERS_PER_PEOPLE) * LETTERS_GAIN)

		var/time_to_remove = BASE_REMOVE_TIME + (p * PAGE_REMOVE_TIME)
		sleeping = max(1, (time_to_remove - 2 SECONDS) / 10) // Ensure a minimum sleep time of 0.1 seconds

		var/med_beep_time = 2.5 SECONDS
		if(p == 1)
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound_client), src.client, 'sound/effects/cryo_opening.ogg', src, 80), time_to_remove)
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound_client), src.client, 'sound/effects/cryo_beep.ogg', src, 80), time_to_remove - 2 SECONDS)
		else if(p == length(pages))
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound_client), src.client, 'sound/effects/cryo_beep.ogg', src, 80), med_beep_time)
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound_client), src.client, 'sound/effects/cryo_beep.ogg', src, 80), time_to_remove)
		else
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound_client), src.client, 'sound/effects/cryo_beep.ogg', src, 80), med_beep_time)

		var/page_header = "<b>PAGE [p]/[length(pages)]</b><br><br>"
		var/text_to_show = page_header + pages[p]

		if(p == 1)
			text_to_show = title_text + text_to_show

		play_screen_text(text_to_show, alert_type, override_letters_per_update = override_letters)
		sleep(time_to_remove)

#undef PEOPLE_PER_PAGE
#undef LETTERS_BASE
#undef LETTERS_PER_PEOPLE
#undef LETTERS_GAIN
#undef BASE_REMOVE_TIME
#undef PAGE_REMOVE_TIME
