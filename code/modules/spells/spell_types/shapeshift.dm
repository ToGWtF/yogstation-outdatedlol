/obj/effect/proc_holder/spell/targeted/shapeshift
	name = "Shapechange"
	desc = "Take on the shape of another for a time to use their natural abilities. Once you've made your choice it cannot be changed."
	clothes_req = 0
	human_req = 0
	charge_max = 200
	cooldown_min = 50
	range = -1
	include_user = 1
	invocation = "RAC'WA NO!"
	invocation_type = "shout"
	action_icon_state = "shapeshift"

	var/shapeshift_type
	var/list/current_shapes = list()
	var/list/current_casters = list()
	var/list/possible_shapes = list(/mob/living/simple_animal/mouse,\
		/mob/living/simple_animal/pet/dog/corgi,\
		/mob/living/simple_animal/hostile/carp/ranged/chaos,\
		/mob/living/simple_animal/bot/ed209,\
		/mob/living/simple_animal/hostile/construct/armored)

/obj/effect/proc_holder/spell/targeted/shapeshift/cast(list/targets,mob/user = usr)
	for(var/mob/living/M in targets)
		if(!shapeshift_type)
			var/list/animal_list = list()
			for(var/path in possible_shapes)
				var/mob/living/simple_animal/A = path
				animal_list[initial(A.name)] = path
			shapeshift_type = input(M, "Choose Your Animal Form!", "It's Morphing Time!", null) as anything in animal_list
			if(!shapeshift_type) //If you aren't gonna decide I am!
				shapeshift_type = pick(animal_list)
			shapeshift_type = animal_list[shapeshift_type]
		if(M in current_shapes)
			Restore(M)
		else
			Shapeshift(M)

/obj/effect/proc_holder/spell/targeted/shapeshift/proc/Shapeshift(mob/living/caster)
	for(var/mob/living/M in caster)
		if(GODMODE in M.status_flags)
			caster << "<span class='warning'>You're already shapeshifted!</span>"
			return

	var/mob/living/shape = new shapeshift_type(caster.loc)
	caster.loc = shape
	caster.status_flags |= GODMODE
	shape.maxHealth = caster.maxHealth
	shape.adjustBruteLoss(-shape.maxHealth)
	shape.adjustBruteLoss(caster.maxHealth - caster.health)

	current_shapes |= shape
	current_casters |= caster
	clothes_req = 0
	human_req = 0

	caster.mind.transfer_to(shape)

/obj/effect/proc_holder/spell/targeted/shapeshift/proc/Restore(mob/living/shape)
	var/mob/living/caster
	for(var/mob/living/M in shape)
		if(M in current_casters)
			caster = M
			break
	if(!caster)
		return
	caster.loc = shape.loc
	caster.status_flags &= ~GODMODE
	caster.adjustBruteLoss(caster.health - shape.health)

	clothes_req = initial(clothes_req)
	human_req = initial(human_req)
	current_casters.Remove(caster)
	current_shapes.Remove(shape)

	shape.mind.transfer_to(caster)
	qdel(shape) //Gib it maybe ?