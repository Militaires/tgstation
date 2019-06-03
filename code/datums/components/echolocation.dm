/datum/component/echolocation
	var/echo_range = 4

	var/cooldown_time = 20
	var/image_expiry_time = 15
	var/fade_in_time = 5
	var/fade_out_time = 5

	var/cooldown_last = 0
	var/list/static/echo_blacklist
	var/list/static/needs_flattening
	var/list/static/echo_images

	var/datum/action/innate/echo/E
	var/datum/action/innate/echo/auto/A

/datum/component/echolocation/Initialize()
	. = ..()
	var/mob/M = parent
	if(!istype(M))
		return COMPONENT_INCOMPATIBLE
	echo_blacklist = typecacheof(list(
	/atom/movable/lighting_object,
	/obj/effect/decal/cleanable/blood,
	/obj/effect/decal/cleanable/xenoblood,
	/obj/effect/decal/cleanable/oil,
	/obj/effect/decal/cleanable/dirt,
	/obj/effect/turf_decal,
	/obj/screen,
	/image,
	/turf/open,
	/area)
	)

	needs_flattening = typecacheof(list(,
	/obj/structure/table,
	/obj/machinery/door/airlock,
	/mob/living)
	)

	echo_images = list()
	E = new
	A = new
	E.Grant(M)
	A.Grant(M)
	RegisterSignal(E, COMSIG_ACTION_TRIGGER, .proc/echolocate)
	RegisterSignal(A, COMSIG_ACTION_TRIGGER, .proc/toggle_auto)

	M.overlay_fullscreen("echo", /obj/screen/fullscreen/echo)


/datum/component/echolocation/_RemoveFromParent()
	..()
	var/mob/M = parent
	E.Remove(M)
	A.Remove(M)

/datum/component/echolocation/process()
	var/mob/M = parent
	if(!M.client)
		STOP_PROCESSING(SSecholocation, src)
	echolocate()

/datum/component/echolocation/proc/echolocate()
	if(world.time < cooldown_last)
		return
	cooldown_last = world.time + cooldown_time
	var/mob/H = parent
	var/image/image_output
	var/list/filtered = list()
	var/list/seen = oview(echo_range, H)
	var/list/receivers = list()
	var/key
	receivers += H
	for(var/I in seen)
		var/atom/A = I
		if(!(A.type in echo_blacklist) && !A.invisibility)
			if(istype(A, /turf/closed))
				filtered += A
			if(istype(A, /obj))
				if(istype(A.loc, /turf))
					filtered += I
			if(istype(A, /mob/living))
				filtered += A
	for(var/mob/M in seen)
		var/datum/component/echolocation/E = M.GetComponent(/datum/component/echolocation)
		if(E)
			receivers += M
	for(var/F in filtered)
		var/atom/S = F
		for(var/D in S.datum_outputs)
			if(istype(D, /datum/outputs/echo_override))
				var/datum/outputs/echo_override/O = D
				image_output = image(O.vfx.icon, null, O.vfx.icon_state, S.layer, O.vfx.plane)
				echo_images["[S.icon]-[S.icon_state]"] = image_output
		//generate caching key
		if(istype(S, /obj/structure/table))
			key = "[S.icon]-[generate_smoothing_key(S)]"
		else if(istype(S, /obj/machinery/door))
			key = "[S.density]-[S.icon]"
		else if(istype(S, /turf/closed))
			key = generate_smoothing_key(S)
		else
			key = "[S.icon]-[S.icon_state]" //no unique keying method? likely generic object (doesn't use overlays to make its icon)
		if(echo_images[key])
			image_output = echo_images[key]
		else
			image_output = generate_image(S)
			echo_images[key] = image_output
		show_image(receivers, image_output, S)

/datum/component/echolocation/proc/show_image(list/receivers, image/image_echo, atom/input)
	for(var/M in receivers)
		var/image/output = image(image_echo)
		output.loc = input
		output.dir = input.dir
		var/mob/receiving_mob = M
		if(receiving_mob.client)
			receiving_mob.client.images += output
			animate(output, alpha = 255, time = fade_in_time)
			addtimer(CALLBACK(src, .proc/fade_image, output, receiving_mob), image_expiry_time)

/datum/component/echolocation/proc/fade_image(sound_image, mob/M)
	animate(sound_image, alpha = 0, time = fade_out_time)
	addtimer(CALLBACK(src, .proc/delete_image, sound_image, M), image_expiry_time, fade_out_time)

/datum/component/echolocation/proc/delete_image(sound_image, mob/M)
	if(M.client)
		M.client.images -= sound_image
	qdel(sound_image)

/datum/component/echolocation/proc/generate_image(atom/input)
	var/icon/I
	var/image/final_image
	if(istype(input, /turf/closed))
		var/list/dirs = list()
		for(var/direction in GLOB.cardinals)
			var/turf/T = get_step(input, direction)
			if(istype(T, input.type) || (locate(input.type) in T))
				dirs += direction
		I = icon('icons/obj/echo_override.dmi',"wall")
		for(var/dir in dirs)
			switch(dir)
				if(NORTH)
					I.DrawBox(null, 2, 32, 31, 31)
				if(SOUTH)
					I.DrawBox(null, 2, 1, 31, 1)
				if(EAST)
					I.DrawBox(null, 32, 2, 32, 31)
				if(WEST)
					I.DrawBox(null, 1, 2, 1, 31)
				final_image = image(I, null, null, input.layer, FULLSCREEN_PLANE)
	else
		if(needs_flattening[input.type])
			I = getFlatIcon(input)
		else
			I = icon(input.icon, input.icon_state)
			I.MapColors(rgb(0,0,0,0), rgb(0,0,0,0), rgb(0,0,0,255), rgb(0,0,0,-254))
			final_image = image(I, null,input.icon_state, input.layer, FULLSCREEN_PLANE, input.dir)
			final_image.filters += filter(type="outline", size=1, color="#FFFFFF")
	final_image.appearance_flags = RESET_COLOR
	final_image.alpha = 0
	return final_image

/datum/component/echolocation/proc/generate_smoothing_key(atom/input)
	var/list/dirs = list()
	for(var/direction in GLOB.cardinals)
		var/turf/T = get_step(input, direction)
		if(istype(T, input.type) || (locate(input.type) in T))
			dirs += direction
	var/key = dirs.Join()
	return key

//AUTO

/datum/component/echolocation/proc/toggle_auto()
	if(!(datum_flags & DF_ISPROCESSING))
		to_chat(parent, "<span class='notice'>Instinct takes over your echolocation.</span>")
		START_PROCESSING(SSecholocation, src)
	else
		to_chat(parent, "<span class='notice'>You pay more attention on when to echolocate.</span>")
		STOP_PROCESSING(SSecholocation, src)

/datum/action/innate/echo
	name = "Echolocate"
	check_flags = AB_CHECK_CONSCIOUS
	icon_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "meson"

/datum/action/innate/echo/auto
	name = "Automatic Echolocation"