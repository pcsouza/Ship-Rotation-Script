--This script is called from the FRED editor. When the script is run it banks a ship
--designated by the SEXP variable "shipnumber" to point its pitch vector to any
--coordinates specified by TargetX, TargetY, and TargetZ SEXP variables.

--This script can be called sequentially to rotate multiple ships, but the shipnumber, and
--target coordinate SEXP variables are reused, and so need to be changed before calling
--the script again.

#Global Hooks

$GameInit:

[
--initialize tables

rotate_ship_bank = nil
rotate_ship_bank = {}

rotatingship_bank = nil
rotatingship_bank = {}

initial_rotational_velocity_bank = nil
initial_rotational_velocity_bank = {}

targetX_bank = nil
targetX_bank = {}

targetY_bank = nil
targetY_bank = {}

targetZ_bank = nil
targetZ_bank = {}

acceldamp_bank = nil
acceldamp_bank = {}

rotationspeed_bank = nil
rotationspeed_bank = {}

decelthreshold_bank = nil
decelthreshold_bank = {}

stopthreshold_bank = nil
stopthreshold_bank = {}

orientation_bank = nil
orientation_bank = {}

remaining_accel_bank = nil
remaining_accel_bank = {}


rotationcount_bank = 0

startbankrotation = function()

	rotationcount_bank = rotationcount_bank + 1
	
	--The rotationscriptfinished SEXP can be specified in FRED. This will trigger to 1
	--when the rotation script is finished. This can be used as a trigger for other events
	--in the mission.
	if mn.SEXPVariables['rotationscriptfinished']:isValid() == true then 
		mn.SEXPVariables['rotationscriptfinished'].Value = 0        .
	end								     



--The following variables are VITAL to specify in FRED. If you don't specify these variables, the script will dump errors on you.
--I don't know what ship you want to rotate or to where, so it's your job to declare these.

	if mn.SEXPVariables['shipnumber']:isValid() ~= true then		--To specify the ship, create a variable "shipnumber" and
		ba.error("Must specify 'shipnumber' SEXP variable")		--use the object number of the ship given in the mission file.
	end
	shiptorotate = mn.SEXPVariables['shipnumber'].Value			
		
	if mn.SEXPVariables['targetX']:isValid() ~= true then			--The SEXP variable "targetX" is the X coordinate you want
		ba.error("Must specify 'targetX' SEXP variable")		--the banking axis to point towards.
	end
	targetX_bank[rotationcount_bank] = mn.SEXPVariables['targetX'].Value

	if mn.SEXPVariables['targetY']:isValid() ~= true then			--The SEXP variable "targetY" is the Y coordinate you want
		ba.error("Must specify 'targetY' SEXP variable")		--the banking axis to point towards.
	end
	targetY_bank[rotationcount_bank] = mn.SEXPVariables['targetY'].Value

	if mn.SEXPVariables['targetZ']:isValid() ~= true then			--The SEXP variable "targetZ" is the Z coordinate you want
		ba.error("Must specify 'targetZ' SEXP variable")		--the banking axis to point towards.
	end
	targetZ_bank[rotationcount_bank] = mn.SEXPVariables['targetZ'].Value


--These are more-advanced options that can be modified at will,
--but are not necessary to declare in order to run the script.

	if mn.SEXPVariables['acceldamp']:isValid() == true then						--Dampening on acceleration. The larger this value is
		acceldamp_bank[rotationcount_bank] = mn.SEXPVariables['acceldamp'].Value			--the longer it will take to get to full rotational velocity.
	else
		acceldamp_bank[rotationcount_bank] = 5
	end
	
	if mn.SEXPVariables['rotationspeed']:isValid() == true then					--The rotation speed of your ship.
		rotationspeed_bank[rotationcount_bank] = (.1)*(mn.SEXPVariables['rotationspeed'].Value)	--It's specified in units of .1. Thus,
	else												--A value in Fred of 10 will produce a rotation speed of 
		rotationspeed_bank[rotationcount_bank] = .2							--1.
	end

	if mn.SEXPVariables['decelthreshold']:isValid() == true then						--The absolute value of the (dot product of your desired banking and
		decelthreshold_bank[rotationcount_bank] = (.0001)*(mn.SEXPVariables['decelthreshold'].Value)	--current banking vectors - 1). Below this threshold, the algorithm begins
	else													--decelrating the ship. The SEXP is in units of .0001. Thus a value of 0 
		decelthreshold_bank[rotationcount_bank]=.1							--corresponds to parallel vectors 10000 corresponds to perpendicular vectors, 
	end													--and 20000 to antiparallel vectors.
	
	if mn.SEXPVariables['stopthreshold']:isValid() == true then						--This is a second threshold value that instructs the ship to stop rotating
		stopthreshold_bank[rotationcount_bank] = (.0001)*(mn.SEXPVariables['stopthreshold'])		--if it is greater than the deceleration threshold, the script defaults it to a
	else													--tenth of the deceleration threshold. Also in units of .0001
		stopthreshold_bank[rotationcount_bank] = decelthreshold_bank[rotationcount_bank]*.1
	end

	if stopthreshold_bank[rotationcount_bank] > decelthreshold_bank[rotationcount_bank] then
		stopthreshold_bank[rotationcount_bank] = decelthreshold_bank[rotationcount_bank]*.1
	end

	if mn.SEXPVariables['orientation']:isValid() == true then					--THIS VALUE SHOULD BE EITHER 1 OR -1. It inverts the final pitch vector
		orientation_bank[rotationcount_bank] = mn.SEXPVariables['orientation'].Value		--of the orientation matrix. Thus if the pitch with orientation 1 is 
	else												--<1,0,-1>, it will be <-1, 0, 1> with orientation -1.
		orientation_bank[rotationcount_bank] = 1
	end

--The following variables are for easily debugging your FRED mission.

	if mn.SEXPVariables['showdotproduct']:isValid() == true then		--Shows ingame the dot product of the desired and current pitch vectors.
		showdotproduct = mn.SEXPVariables['showdotproduct'].Value	--Is very useful in fixing your variables if your ship "hangs" or fails 
	else									--to converge on a solution. Set the variable in FRED to 1 to enable this mode.
		showdotproduct = 0
	end

	if mn.SEXPVariables['showdesiredbankvector']:isValid() == true then			--Shows the desired banking vector ingame.
		showdesiredbankvector = mn.SEXPVariables['showdesiredbankvector'].Value
	else
		showdesiredbankvector = 0
	end
	
	if mn.SEXPVariables['showcurrentbankvector']:isValid() == true then			--Shows the current banking vector ingame.
		showcurrentbankvector = mn.SEXPVariables['showcurrentbankvector'].Value
	else
		showcurrentbankvector = 0
	end

	if mn.SEXPVariables['showtargetcoords']:isValid() == true then				--Shows the target coordinates ingame.
		showtargetcoords = mn.SEXPVariables['showtargetcoords'].Value
	else
		showtargetcoords = 0
	end

	if mn.SEXPVariables['showtransbankingvector']:isValid() == true then			--Shows the the banking vector, transformed to relative to
		showtransbankingvector = mn.SEXPVariables['showtransbankingvector'].Value	--the ship's current orientation.
	else
		showtransbankingvector = 0
	end

	rotate_ship_bank[rotationcount_bank] = true
	rotatingship_bank[rotationcount_bank] = mn.Ships[shiptorotate]
	initial_rotational_velocity_bank[rotationcount_bank] = rotatingship_bank[rotationcount_bank].Physics.RotationalVelocity
	remaining_accel_bank[rotationcount_bank] = 0
	

	
end

spinpitch = function(i)

	frametime = ba.getFrametime()

--Convert target coordinates into the desired banking unit vector
	rotatingship_position = rotatingship_bank[i].Position
	desired_point = ba.createVector(targetX_bank[i],targetY_bank[i],targetZ_bank[i])		
	distance = rotatingship_position:getDistance(desired_point)
	desired_bank_vector = (desired_point - rotatingship_position)/distance

--Separate the orientation matrix into its component heading bank and pitch vectors
	current_orientation_matrix = rotatingship_bank[i].Orientation
	current_heading_vector = ba.createVector(current_orientation_matrix[1],current_orientation_matrix[2],current_orientation_matrix[3])
	current_bank_vector = ba.createVector(current_orientation_matrix[4],current_orientation_matrix[5],current_orientation_matrix[6])
	current_pitch_vector = ba.createVector(current_orientation_matrix[7],current_orientation_matrix[8],current_orientation_matrix[9])

--Transform the desired banking vector into a coordinate system based on the current orientation matrix
--such that in this coordinate system, the current orientation matrix equals:
--|1 0 0|Heading
--|0 1 0|Banking
--|0 0 1|Pitch
--This makes subsequent calculation easier.
	transformed_desired_bank= ba.createVector(desired_bank_vector:getDotProduct(current_heading_vector),desired_bank_vector:getDotProduct(current_bank_vector),desired_bank_vector:getDotProduct(current_pitch_vector))


--Calculate a resulting pitch vector such that in the transformed coordinate system
--the pitch vector is perpendicular to the banking vector with a y-component of zero.
--The orientation variable is factored in here since there are two antiparallel pitch
--vectors that satisfy those parameters.	
	transformed_desired_pitch = ba.createVector((orientation_bank[i]*(-1)*(transformed_desired_bank[3])),0,orientation_bank[i]*transformed_desired_bank[1])

--Use the cross product of the two prior vectors to create the desired heading vector.
	transformed_desired_heading = (transformed_desired_bank:getCrossProduct(transformed_desired_pitch))


--Calculate the difference between the desired and current orientation vectors
	delta_H_vector = (transformed_desired_heading - ba.createVector(1,0,0))
	delta_B_vector = (transformed_desired_bank - ba.createVector(0,1,0))
	delta_P_vector = (transformed_desired_pitch - ba.createVector(0,0,1))


--Create the unormalized components of the turning vector
	H = (delta_P_vector[1])
	B = (delta_H_vector[2])
	P = (delta_B_vector[3])

--Normalize H, B, and P so that they become components of a unit vector.
	H_norm = H/math.sqrt(H^2 + B^2 + P^2)
	B_norm = B/math.sqrt(H^2 + B^2 + P^2)
	P_norm = P/math.sqrt(H^2 + B^2 + P^2)

--Assemble the final turning vector for this iteration
	turning_vector = ba.createVector(P_norm,H_norm,B_norm)

--If accleration dampening is in effect, this increases the remaining acceration factor
	if remaining_accel_bank[i] < acceldamp_bank[i] then
		remaining_accel_bank[i] = remaining_accel_bank[i] + frametime
	end
	if remaining_accel_bank[i] > acceldamp_bank[i] then
		remaining_accel_bank[i] = acceldamp_bank[i]
	end
	

--Calculates the dot product of the current and desired banking vectors
	dot_product = current_bank_vector:getDotProduct(desired_bank_vector)

--Determines if the dot product is past the stopping threshold and stops the ship when reached.
	if math.abs(dot_product - 1) <= stopthreshold_bank[i] then
		rotatingship_bank[i].Physics.RationalVelocity = ba.createVector(0,0,0)
		rotate_ship_bank[i] = false
	end

--Determines "main path" rotation
	if math.abs(dot_product - 1) > decelthreshold_bank[i] and rotate_ship_bank[i] ~= false then
		rotatingship_bank[i].Physics.RotationalVelocity = initial_rotational_velocity_bank[i] + (turning_vector*rotationspeed_bank[i] - initial_rotational_velocity_bank[i])*(remaining_accel_bank[i]/acceldamp_bank[i])
	end

--Determines if deceleration threshold is passed and begins decelerating the rotation. Also triggers rotationscriptfinished SEXP
	if math.abs(dot_product - 1) <= decelthreshold_bank[i] and rotate_ship_bank[i] ~= false then
		rotatingship_bank[i].Physics.RotationalVelocity = (turning_vector*rotationspeed_bank[i])*(math.abs(dot_product-1)/decelthreshold_bank[i])
		if mn.SEXPVariables['rotationscriptfinished']:isValid() == true then
			mn.SEXPVariables['rotationscriptfinished'].Value = 1
		end
	end




--Displays debugging information if indicated
		if showdotproduct == 1 then
			gr.drawString(dot_product, 100, 100)
			gr.drawString('dot product',10,100)
		end
		
		if showdesiredbankvector == 1 then
			gr.drawString(desired_bank_vector[1],100,120)
			gr.drawString(desired_bank_vector[2],250,120)
			gr.drawString(desired_bank_vector[3],400,120)
			gr.drawString('desired',10,120)
		end

		if showcurrentbankvector == 1 then
			gr.drawString(current_bank_vector[1],100,150)
			gr.drawString(current_bank_vector[2],250,150)
			gr.drawString(current_bank_vector[3],400,150)
			gr.drawString('current',10,150)
		end

		if showtargetcoords == 1 then
			gr.drawString(targetX_bank,100,180)
			gr.drawString(targetY_bank,250,180)
			gr.drawString(targetZ_bank,400,180)
			gr.drawString('target',10,180)
		end

		if showtransbankingvector == 1 then
			gr.drawString(transformed_desired_heading[1],100,210)
			gr.drawString(transformed_desired_heading[2],250,210)
			gr.drawString(transformed_desired_heading[3],400,210)
			gr.drawString("THead", 10,210)

			gr.drawString(transformed_desired_bank[1],100,225)
			gr.drawString(transformed_desired_bank[2],250,225)
			gr.drawString(transformed_desired_bank[3],400,225)
			gr.drawString("TBank", 10,225)

			gr.drawString(transformed_desired_pitch[1],100,240)
			gr.drawString(transformed_desired_pitch[2],250,240)
			gr.drawString(transformed_desired_pitch[3],400,240)
			gr.drawString("TPitch", 10,240)
		end
	


end
	

]

#END



#Conditional Hooks

$State: GS_STATE_GAME_PLAY



$On Frame:

[

--Runs the script for all currently rotating ships
for current_ship_bank = 1, rotationcount_bank do 
	if rotate_ship_bank[current_ship_bank] == true then
		spinpitch(current_ship_bank)
	end
end



]

$On Mission End:

[

--Resets tables
rotate_ship_bank = nil
rotate_ship_bank = {}

rotatingship_bank = nil
rotatingship_bank = {}

initial_rotational_velocity_bank = nil
initial_rotational_velocity_bank = {}

targetX_bank = nil
targetX_bank = {}

targetY_bank = nil
targetY_bank = {}

targetZ_bank = nil
targetZ_bank = {}

acceldamp_bank = nil
acceldamp_bank = {}

rotationspeed_bank = nil
rotationspeed_bank = {}

decelthreshold_bank = nil
decelthreshold_bank = {}

stopthreshold_bank = nil
stopthreshold_bank = {}

orientation_bank = nil
orientation_bank = {}

remaining_accel_bank = nil
remaining_accel_bank = {}


rotationcount_bank = 0


]

#End