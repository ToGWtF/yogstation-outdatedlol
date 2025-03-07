/turf/closed/wall
	name = "wall"
	desc = "A huge chunk of metal used to separate rooms."
	icon = 'icons/turf/walls/wall.dmi'
	icon_state = "wall"
	var/mineral = "metal"
	explosion_block = 1

	thermal_conductivity = WALL_HEAT_TRANSFER_COEFFICIENT
	heat_capacity = 312500 //a little over 5 cm thick , 312500 for 1 m by 2.5 m by 0.25 m plasteel wall

	var/walltype = "metal"
	var/hardness = 40 //lower numbers are harder. Used to determine the probability of a hulk smashing through.
	var/slicing_duration = 100  //default time taken to slice the wall
	var/sheet_type = /obj/item/stack/sheet/metal
	var/obj/item/stack/sheet/builtin_sheet = null

	canSmoothWith = list(
	/turf/closed/wall,
	/turf/closed/wall/r_wall,
	/obj/structure/falsewall,
	/obj/structure/falsewall/reinforced,
	/turf/closed/wall/rust,
	/turf/closed/wall/r_wall/rust,
	/turf/closed/wall/clockwork)
	smooth = SMOOTH_TRUE

/turf/closed/wall/New()
	..()
	builtin_sheet = new sheet_type

/turf/closed/wall/attack_tk()
	return

/turf/closed/wall/proc/dismantle_wall(devastated=0, explode=0)
	if(devastated)
		devastate_wall()
	else
		playsound(src, 'sound/items/Welder.ogg', 100, 1)
		var/newgirder = break_wall()
		if(newgirder) //maybe we don't /want/ a girder!
			transfer_fingerprints_to(newgirder)

	for(var/obj/O in src.contents) //Eject contents!
		if(istype(O,/obj/structure/sign/poster))
			var/obj/structure/sign/poster/P = O
			P.roll_and_drop(src)
		else
			O.loc = src
	ChangeTurf(/turf/open/floor/plating)

/turf/closed/wall/proc/break_wall()
	builtin_sheet.amount = 2
	builtin_sheet.loc = src
	return (new /obj/structure/girder(src))

/turf/closed/wall/proc/devastate_wall()
	builtin_sheet.amount = 2
	builtin_sheet.loc = src
	new /obj/item/stack/sheet/metal(src)

/turf/closed/wall/ex_act(severity, target)
	if(target == src)
		dismantle_wall(1,1)
		return
	switch(severity)
		if(1)
			//SN src = null
			src.ChangeTurf(src.baseturf)
			return
		if(2)
			if (prob(50))
				dismantle_wall(0,1)
			else
				dismantle_wall(1,1)
		if(3)
			if (prob(hardness))
				dismantle_wall(0,1)
			else
	if(!density)
		..()
	return

/turf/closed/wall/blob_act(obj/effect/blob/B)
	if(prob(50))
		dismantle_wall()

/turf/closed/wall/mech_melee_attack(obj/mecha/M)
	M.do_attack_animation(src)
	if(M.damtype == "brute")
		playsound(src, 'sound/weapons/punch4.ogg', 50, 1)
		visible_message("<span class='danger'>[M.name] has hit [src]!</span>")
		if(prob(hardness + M.force) && M.force > 20)
			dismantle_wall(1)
			visible_message("<span class='warning'>[M.name] smashes through the wall!</span>")
			playsound(src, 'sound/effects/meteorimpact.ogg', 100, 1)

/turf/closed/wall/attack_paw(mob/living/user)
	user.changeNext_move(CLICK_CD_MELEE)
	return src.attack_hand(user)


/turf/closed/wall/attack_animal(mob/living/simple_animal/M)
	if(istype(M,/mob/living/simple_animal/hostile/construct/builder)||istype(M,/mob/living/simple_animal/hostile/construct/harvester))
		if(istype(src, /turf/closed/wall/mineral/cult))
			return
		src.ChangeTurf(/turf/closed/wall/mineral/cult)
		M <<"<span class='notice'>You transfer some of your corrupt energy into the wall, causing it to transform.</span>"
		playsound(src, 'sound/items/Welder.ogg', 100, 1)
		return
	M.changeNext_move(CLICK_CD_MELEE)
	M.do_attack_animation(src)
	if(M.environment_smash >= 2)
		playsound(src, 'sound/effects/meteorimpact.ogg', 100, 1)
		M << "<span class='notice'>You smash through the wall.</span>"
		dismantle_wall(1)
		return

/turf/closed/wall/attack_hulk(mob/user)
	..(user, 1)
	if(prob(hardness))
		playsound(src, 'sound/effects/meteorimpact.ogg', 100, 1)
		user << text("<span class='notice'>You smash through the wall.</span>")
		user.say(pick(";RAAAAAAAARGH!", ";HNNNNNNNNNGGGGGGH!", ";GWAAAAAAAARRRHHH!", "NNNNNNNNGGGGGGGGHH!", ";AAAAAAARRRGH!" ))
		dismantle_wall(1)

	else
		playsound(src, 'sound/effects/bang.ogg', 50, 1)
		user << text("<span class='notice'>You punch the wall.</span>")
	return 1

/turf/closed/wall/attack_hand(mob/user)
	user.changeNext_move(CLICK_CD_MELEE)
	user << "<span class='notice'>You push the wall but nothing happens!</span>"
	playsound(src, 'sound/weapons/Genhit.ogg', 25, 1)
	src.add_fingerprint(user)
	..()
	return


/turf/closed/wall/attackby(obj/item/weapon/W, mob/user, params)
	user.changeNext_move(CLICK_CD_MELEE)
	if (!user.IsAdvancedToolUser())
		user << "<span class='warning'>You don't have the dexterity to do this!</span>"
		return

	//get the user's location
	if( !istype(user.loc, /turf) )
		return	//can't do this stuff whilst inside objects and such

	add_fingerprint(user)

	//THERMITE related stuff. Calls src.thermitemelt() which handles melting simulated walls and the relevant effects
	if( thermite )
		if(W.is_hot() && !unacidable)
			thermitemelt(user)
			return

	var/turf/T = user.loc	//get user's location for delay checks

	//the istype cascade has been spread among various procs for easy overriding
	if(try_wallmount(W,user,T) || try_decon(W,user,T) || try_destroy(W,user,T))
		return

	return


/turf/closed/wall/proc/try_wallmount(obj/item/weapon/W, mob/user, turf/T)
	//check for wall mounted frames
	if(istype(W,/obj/item/wallframe))
		var/obj/item/wallframe/F = W
		if(F.try_build(src))
			F.attach(src)
		return 1
	//Poster stuff
	else if(istype(W,/obj/item/weapon/poster))
		place_poster(W,user)
		return 1

	return 0


/turf/closed/wall/proc/try_decon(obj/item/weapon/W, mob/user, turf/T)
	if( istype(W, /obj/item/weapon/weldingtool) )
		var/obj/item/weapon/weldingtool/WT = W
		if( WT.remove_fuel(0,user) )
			user << "<span class='notice'>You begin slicing through the outer plating...</span>"
			playsound(src, 'sound/items/Welder.ogg', 100, 1)
			if(do_after(user, slicing_duration/W.toolspeed, target = src))
				if( !istype(src, /turf/closed/wall) || !user || !WT || !WT.isOn() || !T )
					return 1
				if( user.loc == T && user.get_active_hand() == WT )
					user << "<span class='notice'>You remove the outer plating.</span>"
					dismantle_wall()
					return 1
	else if( istype(W, /obj/item/weapon/gun/energy/plasmacutter) )
		user << "<span class='notice'>You begin slicing through the outer plating...</span>"
		playsound(src, 'sound/items/Welder.ogg', 100, 1)
		if(do_after(user, slicing_duration*0.6, target = src))  // plasma cutter is faster than welding tool
			if( !istype(src, /turf/closed/wall) || !user || !W || !T )
				return 1
			if( user.loc == T && user.get_active_hand() == W )
				user << "<span class='notice'>You remove the outer plating.</span>"
				dismantle_wall()
				visible_message("The wall was sliced apart by [user]!", "<span class='italics'>You hear metal being sliced apart.</span>")
				return 1
	return 0


/turf/closed/wall/proc/try_destroy(obj/item/weapon/W, mob/user, turf/T)
	if(istype(W, /obj/item/weapon/pickaxe/drill/jackhammer))
		var/obj/item/weapon/pickaxe/drill/jackhammer/D = W
		if( !istype(src, /turf/closed/wall) || !user || !W || !T )
			return 1
		if( user.loc == T && user.get_active_hand() == W )
			D.playDigSound()
			dismantle_wall()
			visible_message("<span class='warning'>[user] smashes through the [name] with the [W.name]!</span>", "<span class='italics'>You hear the grinding of metal.</span>")
			return 1
	return 0


/turf/closed/wall/proc/thermitemelt(mob/user)
	overlays = list()
	var/obj/effect/overlay/O = new/obj/effect/overlay( src )
	O.name = "thermite"
	O.desc = "Looks hot."
	O.icon = 'icons/effects/fire.dmi'
	O.icon_state = "2"
	O.anchored = 1
	O.opacity = 1
	O.density = 1
	O.layer = FLY_LAYER

	playsound(src, 'sound/items/Welder.ogg', 100, 1)

	if(thermite >= 50)
		var/burning_time = max(100,300 - thermite)
		var/turf/open/floor/F = ChangeTurf(/turf/open/floor/plating)
		F.burn_tile()
		F.icon_state = "wall_thermite"
		F.add_hiddenprint(user)
		spawn(burning_time)
			if(O)
				qdel(O)
	else
		thermite = 0
		spawn(50)
			if(O)
				qdel(O)
	return

/turf/closed/wall/singularity_pull(S, current_size)
	if(current_size >= STAGE_FIVE)
		if(prob(50))
			dismantle_wall()
		return
	if(current_size == STAGE_FOUR)
		if(prob(30))
			dismantle_wall()

/turf/closed/wall/narsie_act()
	if(prob(20))
		ChangeTurf(/turf/closed/wall/mineral/cult)

/turf/closed/wall/ratvar_act(force)
	var/converted = (prob(40) || force)
	if(converted)
		ChangeTurf(/turf/closed/wall/clockwork)
	for(var/I in src)
		var/atom/A = I
		if(ismob(A) || converted)
			A.ratvar_act()

/turf/closed/wall/storage_contents_dump_act(obj/item/weapon/storage/src_object, mob/user)
	return 0
