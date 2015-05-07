1;

function steamTable = loadTable(filename)
	content = load(filename);
	cols = columns(content);
	headers = "teprvfvgufughfhgsfsg";
	for i = 1:cols
		steamTable.(headers(2*i-1:2*i)) = content(:, i);
	endfor
endfunction

function wp = spPumpWork(va, Pa, Pb)
	wp = va*(Pb-Pa);
endfunction
	
function [x, warning] = qualityFromProp(prop, propName, T, table)
	[propf, propg] = satProps(T, table, propName);
	x = (prop-propf)/(propg-propf);
	if (x > 1)
		warning = 1;
	elseif (x<0)
		warning = -1;
	else
		warning = 0;
	endif
endfunction

function prop = propFromQuality(x, propName, T, table)
	[propf, propg] = satProps(T, table, propName);
	prop = propf+x*(propg-propf);
endfunction

function [propf, propg] = satProps(T, table, propName)
	index = lookup(table.te, T);
	if (propName == "pr")
		propf = table.(propName)(index) * 100000;
		propg = propf * 100000;
	else
		propf = table.([propName, "f"])(index);
		propg = table.([propName, "g"])(index);
		if (propName == "v")
			propf = propf/1000;
		endif
	endif
endfunction

function [entropySp, temp] = SatLineForTS(table)
	entropySp = zeros(1, rows(table.te)*2);
	length = columns(entropySp);
	temp = zeros(1, length);
	for i = 1:rows(table.te);
		n = length+1-i;
		entropySp(i) = propFromQuality(0, "s", table.te(i), table);
		entropySp(n) = propFromQuality(1, "s", table.te(i), table);
		temp(i) = table.te(i);
		temp(n) = table.te(i);
	endfor
endfunction

function [entropyStates, tempStates, energies] = calcProps(qin, T1, T3, steamTable)
	T4 = T1;
	P1 = satProps(T1, steamTable, "pr")(1);
	P3 = satProps(T3, steamTable, "pr")(1);
	P2 = P3;
	P4 = P1;

	h1 = propFromQuality(0, "h", T1, steamTable);
	s1 = propFromQuality(0, "s", T1, steamTable);
	v1 = propFromQuality(0, "v", T1, steamTable);
	s2 = s1;
	wp = spPumpWork(v1, P1, P2);
	h2 = h1 + wp;
	index = lookup(steamTable.hf, h2);
	T2 = steamTable.te(index);
	sf3 = propFromQuality(0, "s", T3, steamTable);
	h3 = h2 + qin;
	[x3, warning3] = qualityFromProp(h3, "h", T3, steamTable);
	s3 = propFromQuality(x3, "s", T3, steamTable);
	s4  = s3;
	[x4, warning4] = qualityFromProp(s4, "s", T4, steamTable);
	h4 = propFromQuality(x4, "h", T4, steamTable);
	qout = h4 - h1;
	wt = h3-h4;

	entropyStates = [s1, s2, sf3, s3, s4, s1];
	tempStates = [T1, T2, T3, T3, T4, T1];
	energies = [wp, qin, wt, qout, warning3, warning4];	
endfunction

function plotTS(steamTable, entStates, tStates)
	[s, t] = SatLineForTS(steamTable);
	plot(s,t, 'r', entStates, tStates , "b");
	axis([(entStates(1)-1) (entStates(4)+1) (tStates(1)-1) (tStates(4)+1)]);
endfunction

function main()
	steamTable = loadTable("steamTable.txt");
	proceed = 1;
	printf("\
--------------------------------------------------------------------------------\n\
This is a script that creates a Ts diagram for an ideal Rankine cycle \n\
based on user defined input. It first asks for operating temperatures and\n\
specific heat input. Then it computes state properties using a steam table\n\
to determine enthalpies. Then it prints specific heat out, pump and engine work. \n\
--------------------------------------------------------------------------------");
	while(proceed == 1)
		qin = input("\nHow much heat per unit mass is added to the system evaporator in kJ/kg? ")
		T1 = input("What is the heat sink or condensor temperature in degrees Celsius (0 - 80 C)? ")
		T3 = input("What is the heat source or evaporator in degrees Celsius ( 0 - 80 C)? ")

		[entropyStates, tempStates, energies] = calcProps(qin, T1, T3, steamTable);
		plotTS(steamTable, entropyStates, tempStates);
		printf("\n\
--------------------------------------------------------------------------------\n");
		printf("specific pump work:   wp   = "), disp(energies(1));
		printf("specific heat input:  qin  = "), disp(energies(2));
		printf("specific engine work: wt   = "), disp(energies(3));
		printf("specific heat output: qout = "), disp(energies(4));
		if (energies(5) == 1)
			printf("WARNING: The vapor became super heated in state 3.\n");
			printf("The calculations in this script are not valid for super heated vapor.\n");
		elseif (energies(5) == -1)
			printf("WARNING: The liquid never evaporated and remained subcooled. \n")
			printf("The calculations in this script are not valid without evaporation in the evaporator.");
		endif
		printf("\
--------------------------------------------------------------------------------\n");
		proceed = yes_or_no("Would you like to change the operating temperatures or heat load? ");
	endwhile
endfunction

main()