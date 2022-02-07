(*$OverflowCheck+*)
(*$RangeCheck+*)
MODULE TestPMD;

FROM EZStrings IMPORT ArrayToString;
FROM InOut IMPORT WriteString, WriteLn;
IMPORT EZDump;

VAR
	aCard: CARDINAL;
	aBool: BOOLEAN;
	aString: ARRAY [0..20] OF CHAR;

	PROCEDURE Nested1;	
	VAR
		Nested1Card : CARDINAL;
		Nested1Bool : BOOLEAN;

		PROCEDURE Nested2;
		
		VAR
			Nested2Card : CARDINAL;
			Nested2Bool : BOOLEAN;
			
			PROCEDURE Nested3;
			
			VAR
				Nested3Card : CARDINAL;
				Nested3Bool : BOOLEAN;
			BEGIN
				WriteString('Nested3...');
				WriteLn;
				
				Nested3Card := MAX(CARDINAL);
				Nested3Bool := FALSE;
				
				aCard := Nested3Card;
				aBool := Nested3Bool;
				
				INC(aCard);
				
				ArrayToString('Nested3', aString);
			END Nested3;
		BEGIN
			WriteString('Nested2...');
			WriteLn;
			
			Nested2Card := 2;
			Nested2Bool := TRUE;
			
			aCard := Nested2Card;
			aBool := Nested2Bool;
			
			ArrayToString('Nested2', aString);
			
			Nested3;
		END Nested2;
	BEGIN
		WriteString('Nested1...');
		WriteLn;
    
		Nested1Card := 1;
		Nested1Bool := FALSE;
		
		aCard := Nested1Card;
		aBool := Nested1Bool;
		
		ArrayToString('Nested1', aString);
		
		Nested2;
	END Nested1;
	
BEGIN
    WriteString('TestPMD...');
    WriteLn;
    
	Nested1;
END TestPMD.