(*$StackSize 2000H*)
MODULE PMD;

FROM ASCII IMPORT
  nul;
FROM EZCommandLine IMPORT
  getParameters, getWord, getCommandLine;
FROM EZDump IMPORT
  pBlockListEntry, dumpBlockList, OpenPMD, ClosePMD, dumpHeader, DisplayReason,
  dumpStack;
FROM EZFileSystem IMPORT
  MakeFileName;
FROM EZStrings IMPORT
  StringToLeftArray;
FROM FileSystem IMPORT
  File;
FROM GSOSInterface IMPORT
  GSOSOutString, GSOSOutStringToString, GSOSNameLength;
FROM InOut IMPORT
  WriteLn, WriteString, WriteHex, WriteCard;
FROM LinkMap IMPORT
  pMap, PurgeMap, ReadMapFromFile, FindSymbol, pSymbol, debugModeOn;
FROM M2Lib IMPORT
  LongWORD;
FROM NumberConversion IMPORT
  CardToString;
FROM Strings IMPORT
  Length;
FROM SYSTEM IMPORT
  ADDRESS, ADR, BYTE;

VAR
  DumpFile: GSOSOutString;
  mapname:  ARRAY [0..GSOSNameLength-1] OF CHAR;
  map:      pMap;

PROCEDURE WriteBlockDetails(number: CARDINAL; block: pBlockListEntry; offset: ADDRESS); FORWARD;

PROCEDURE FindSegmentInDump(    addr:   ADDRESS;
                            VAR block:  pBlockListEntry;
                            VAR offset: ADDRESS);
VAR
  Found:  BOOLEAN;
BEGIN
  block := dumpBlockList;
  Found := FALSE;

  WITH dumpHeader DO
    WHILE (block <> NIL) AND NOT Found DO
      WITH block^.info DO
        IF addr > address THEN
          offset := addr - address;

          IF VAL(LONGINT, offset) < length THEN
            Found := TRUE;
          END;
        END;
      END;

      IF NOT Found THEN
        block := block^.next;
      END;
    END;
  END;
END FindSegmentInDump;

VAR
  dumpname: ARRAY [0..GSOSNameLength-1] OF CHAR;

PROCEDURE GetShellParms(VAR OK: BOOLEAN);
VAR
  parms:  ARRAY [0..79] OF CHAR;
BEGIN
  getParameters(parms);

  IF Length(parms) = 0 THEN
    OK := FALSE;
  ELSE
    OK := TRUE;

    getWord(parms, 0, dumpname);
  END;

  IF NOT OK THEN
    WriteString('No file specified.');
    WriteLn;
  END;
END GetShellParms;

PROCEDURE TraceStackFrame(number: CARDINAL; thisFrame: CARDINAL);
TYPE
  aStackFrame =
    RECORD
      dRegister:      CARDINAL;
      display:        CARDINAL;
      nextStackFrame: CARDINAL;
      returnOffset:   CARDINAL;
      returnBank:     BYTE;
    END;
  pStackFrame = POINTER TO aStackFrame;
    
VAR
  block:    pBlockListEntry;
  offset:   ADDRESS;
  frameAdr: pStackFrame;
  temp:     CARDINAL;
  addr:     ADDRESS;
BEGIN
  frameAdr := dumpStack + VAL(ADDRESS, thisFrame - dumpHeader.StackBottom + 1);

  WITH frameAdr^ DO
    temp := VAL(CARDINAL, returnBank);
    addr := VAL(ADDRESS, LongWORD(returnOffset, temp));

    FindSegmentInDump(addr, block, offset);

    IF block = NIL THEN
      WriteString('Unable to trace stack any further...');
      WriteLn;
    ELSE
      WriteBlockDetails(number, block, offset);

      IF (nextStackFrame < dumpHeader.StackTop) AND
         (nextStackFrame > dumpHeader.StackBottom) THEN
        TraceStackFrame(number + 1, nextStackFrame);
      END;
    END;
  END;
END TraceStackFrame;

PROCEDURE WriteBlockDetails(number: CARDINAL; block: pBlockListEntry; offset: ADDRESS);
VAR
  symbol:    pSymbol;
  numberStr: ARRAY [0..3] OF CHAR;
BEGIN
  CardToString(number, numberStr, 2);
  StringToLeftArray(numberStr, numberStr);
  WriteString('# ');
  WriteString(numberStr);
  WriteString(' ');
  WriteHex(VAL(CARDINAL, offset), 4);
  WriteString(' in ');
  
  WITH block^ DO    
    IF map <> NIL THEN
      FindSymbol(map, VAL(LONGCARD, offset), info.segment + 1, symbol);
      
      IF symbol <> NIL THEN
        WriteString(symbol^.name);
      END;
    ELSE
      WriteString(' in load segment ');
      WriteCard(info.segment, 3);
      WriteString(', length: ');
      WriteHex(VAL(CARDINAL, info.length), 4);
      WriteString('H');
    END;
    
    WriteLn;
  END;
END WriteBlockDetails;

VAR
  dumpFile: File;
  OK:       BOOLEAN;
  block:    pBlockListEntry;
  offset:   ADDRESS;
  blockNum: CARDINAL;
BEGIN
  GetShellParms(OK);

  IF OK THEN
    OpenPMD(dumpFile, dumpname, OK);

    IF OK THEN
      blockNum := 1;
      MakeFileName(dumpname, mapname, '.map');
      ReadMapFromFile(map, mapname);
    
      DisplayReason(dumpHeader.Reason);

      FindSegmentInDump(dumpHeader.TermAddr, block, offset);

      IF block <> NIL THEN
        WriteString('Program terminated at');
        WriteLn;
        WriteLn;
        
        WriteBlockDetails(blockNum, block, offset);

        TraceStackFrame(blockNum + 1, dumpHeader.stackFrame);
      ELSE
        WriteString('Unable to determine crash location.');
        WriteLn;
      END;

      IF map <> NIL THEN
        PurgeMap(map);
      END;
      
      ClosePMD(dumpFile);
    END;
  END;
END PMD.
