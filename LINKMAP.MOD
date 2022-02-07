IMPLEMENTATION MODULE LinkMap;

FROM EZFileSystem IMPORT ReadNBytes, WriteNBytes;
FROM FileSystem IMPORT File, ReadChar, Lookup, Close, WriteWord, ReadWord,
  Response;
FROM InOut IMPORT Write, WriteCard, WriteHex, WriteLn, WriteString;
FROM Lists IMPORT LOpen, LInsertLast, LGetFirst, LGetNext, LEndOfList,
  LMerge, LDeleteAll, LPurge, DumpList, ReadList;
FROM M2Lib IMPORT HighWORD, LoWORD;
FROM Storage IMPORT ALLOCATE, DEALLOCATE;
FROM Strings IMPORT Length;
FROM SYSTEM IMPORT ADDRESS, TSIZE;

IMPORT ASCII;

CONST
  space       = 40C;

VAR
  mapFile:  File;
  line:     ARRAY [0..255] OF CHAR;

(* ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** *)
(*             Procedures for reading and manipulating a text file.           *)
(* ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** *)

PROCEDURE IsHexDigit(ch: CHAR): BOOLEAN;
(*
  OPERATION:
    Returns TRUE if the supplied character is a valid hexadecimal digit.
*)
BEGIN
  RETURN ((ch >= "0") AND (ch <= "9")) OR
         ((CAP(ch) >= "A") AND (CAP(ch) <= "F"));
END IsHexDigit;

PROCEDURE ReadHexNumber(VAR value:  LONGCARD;
                        VAR index:  CARDINAL;
                            size:   CARDINAL);
(*

  OPERATION:
    Reads a hexadecimal number from the 'line', beginning at 'index'.  The 
    number is assumed to be 'size' digits in length.
*)
VAR
  count:  CARDINAL;
  digit:  CARDINAL;
BEGIN
  IF (index + size) > Length(line) THEN
    value := 0;
  ELSE
    count := 0;
    value := 0;

    REPEAT
      digit := ORD(line[count+index]) - 60B;

      IF digit > 26B THEN
        digit := 0;
      ELSIF digit > 9 THEN
        DEC(digit, 7);
      END;

      value := value * 16 + VAL(LONGCARD, digit);
      INC(count);
    UNTIL count = size;

    INC(index, size);
  END;
END ReadHexNumber;

PROCEDURE ReadLine;
VAR
  ch:     CHAR;
  index:  CARDINAL;
BEGIN
  index := 0;
  ReadChar(mapFile, ch);

  WHILE (NOT mapFile.eof) AND (ch <> ASCII.cr) AND (index <= HIGH(line)) DO
    line[index] := ch;
    INC(index);
    ReadChar(mapFile, ch);
  END;

  IF index <= HIGH(line) THEN
    line[index] := ASCII.nul;
  END;

  IF debugModeOn THEN
    WriteString(line);
    WriteLn;
  END;
END ReadLine;

PROCEDURE ReadName(VAR  name:   ARRAY OF CHAR;
                   VAR  index:  CARDINAL);
(*
  OPERATION:
    Reads a string from the line beginning at 'index' within the line.
*)
VAR
  count:  CARDINAL;
BEGIN
  count := 0;

  WHILE (count <= HIGH(name)) AND (index <= HIGH(line)) AND
        (line[index] <> space) AND (line[index] <> ASCII.nul) DO
    name[count] := line[index];
    INC(count);
    INC(index);
  END;

  IF count <= HIGH(name) THEN
    name[count] := ASCII.nul;
  END;
END ReadName;

(* ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** *)
(*               Procedures for displaying structures at debug time           *)
(* ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** *)

PROCEDURE DisplaySymbol(symbol: pSymbol);
BEGIN
  IF debugModeOn THEN
    WITH symbol^ DO
      WriteString('Symbol: "');
      WriteString(name);
      WriteString('" at offset: <');
      WriteHex(HighWORD(offset), 4);
      WriteHex(LoWORD(offset), 4);
      WriteString('> with length <');
      WriteHex(HighWORD(length), 4);
      WriteHex(LoWORD(length), 4);
      WriteString('>');
      WriteLn;
    END;
  END;
END DisplaySymbol;

(* ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** *)
(*               Procedures for reading and manipulating a map.               *)
(* ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** *)

PROCEDURE AddSegmentToMap(VAR map:    pMap;
                              segNum: CARDINAL);
(*
  OPERATION:
    Adds a new segment to the specified map with the supplied segment number.
*)
VAR
  newSeg: pSegment;
  OK:     BOOLEAN;
BEGIN
  NEW(newSeg);

  WITH newSeg^ DO
    number := segNum;
    LOpen(symbols);
  END;

  IF debugModeOn THEN
    WriteString('New segment: <');
    WriteCard(segNum, 2);
    WriteString('>');
    WriteLn;
  END;

  WITH map^ DO
    LInsertLast(segments, newSeg, OK);

    IF NOT OK THEN
      HALT;
    END;
  END;
END AddSegmentToMap;

PROCEDURE sortSymbols(a,b: ADDRESS): BOOLEAN;
VAR
  A,B: pSymbol;
BEGIN
  A := a;
  B := b;

  RETURN A^.offset < B^.offset;
END sortSymbols;

PROCEDURE MergeSymbolToMap(VAR map:     pMap;
                               segment: CARDINAL;
                               symbol:  pSymbol;
                           VAR OK:      BOOLEAN);
(*
  OPERATION:
    Inserts 'symbol' into 'map' by locating the correct 'segment', and place
    within that segment such that all symbols within a segment are in order
    of their true placement in the segment.
*)
VAR
  searchSeg:  pSegment;
  found:      BOOLEAN;
BEGIN
  FindSegment(map, segment, searchSeg);
  
  IF searchSeg = NIL THEN
    OK := FALSE;
  ELSE
    WITH searchSeg^ DO
    	LMerge(symbols, symbol, sortSymbols, OK);
    END;
  
    DisplaySymbol(symbol);
  END;
END MergeSymbolToMap;

PROCEDURE PurgeMap(VAR map: pMap);
(*
  OPERATION:
    Disposes of any memory used by the specified map. 'map' is returned as NIL.
*)
VAR
  segment:  pSegment;
BEGIN
  WITH map^ DO
    LGetFirst(segments, segment);

    WHILE NOT LEndOfList(segments) DO
      LDeleteAll(segment^.symbols, TSIZE(aSymbol));
      LPurge(segment^.symbols);

      LGetNext(segments, segment);
    END;

    LDeleteAll(segments, TSIZE(aSegment));
    LPurge(segments);
  END;

  DISPOSE(map);
END PurgeMap;

PROCEDURE ReadByteworksMap(    filename:  ARRAY OF CHAR;
                           VAR map:       pMap);
(*
  OPERATION:
    Reads a link map generated by the byteworks linker, and generates a memory
    resident version of the map.
*)
VAR
  inError:  BOOLEAN;

  PROCEDURE ProcessSymbolLine;
  VAR
    col:    CARDINAL;
    sym:    pSymbol;
    segNum: LONGCARD;
    OK:     BOOLEAN;
  BEGIN
    col := 0;

    NEW(sym);

    IF sym <> NIL THEN
      WITH sym^ DO
        ReadHexNumber(offset, col, 8);
        INC(col);
        ReadHexNumber(length, col, 8);
        INC(col);
        ReadHexNumber(segNum, col, 2);
        INC(col, 7);
        ReadName(name, col);

        IF offset = 0 THEN
          AddSegmentToMap(map, VAL(CARDINAL, segNum));
        END;

        MergeSymbolToMap(map, segNum, sym, OK);

        inError := NOT OK;
      END;
    ELSE
      HALT;
    END;
  END ProcessSymbolLine;

BEGIN
  inError := FALSE;

  Lookup(mapFile, filename, FALSE);

  IF mapFile.res = done THEN
    NEW(map);
    LOpen(map^.segments);

    ReadLine;

    (*
      Find the first line of the procedure symbol table.
    *)
    WHILE NOT IsHexDigit(line[0]) AND NOT mapFile.eof DO
      ReadLine;
    END;

    (*
      Process each procedure symbol table line.
    *)
    WHILE IsHexDigit(line[0]) AND NOT mapFile.eof AND NOT inError DO
      ProcessSymbolLine;
      ReadLine;
    END;

    Close(mapFile);

    IF inError THEN
      PurgeMap(map);
    ELSE
      WriteMapToFile(map, 'tmpfile');
    END;
  ELSE
    map := NIL;
  END;
END ReadByteworksMap;

PROCEDURE DumpSymbol(VAR f:  File; data: ADDRESS; VAR OK: BOOLEAN);
VAR
  written:  LONGINT;
BEGIN
  WriteNBytes(f, TSIZE(aSymbol), data, written);

  DisplaySymbol(data);

  OK := written = TSIZE(aSymbol);
END DumpSymbol;

PROCEDURE DumpSegment(VAR f:  File; data: ADDRESS; VAR OK: BOOLEAN);
VAR
  segment:  pSegment;
BEGIN
  segment := data;

  WITH segment^ DO
    WriteWord(f, number);

    DumpList(f, symbols, DumpSymbol, OK);
  END;
END DumpSegment;

PROCEDURE WriteMapToFile(map:       pMap;
                         filename:  ARRAY OF CHAR);
(*
  OPERATION:
    Write the specified map to a disk file in a format that is easy for a 
    program to read, as opposed to the text file produced by the linker.
*)
VAR
  OK: BOOLEAN;
BEGIN
  Lookup(mapFile, filename, TRUE);

  WITH map^ DO
    DumpList(mapFile, segments, DumpSegment, OK);
  END;

  Close(mapFile);
END WriteMapToFile;

PROCEDURE ReadSymbol(VAR f:  File; VAR data: ADDRESS; VAR OK: BOOLEAN);
VAR
  read:     LONGINT;
  symbol:   pSymbol;
BEGIN
  NEW(symbol);

  ReadNBytes(f, TSIZE(aSymbol), symbol, read);

  DisplaySymbol(symbol);

  OK := TRUE;
  data := symbol;
END ReadSymbol;

PROCEDURE ReadSegment(VAR f:  File; VAR data: ADDRESS; VAR OK: BOOLEAN);
VAR
  segment:  pSegment;
  segNum:   CARDINAL;
BEGIN
  NEW(segment);

  WITH segment^ DO
    ReadWord(f, number);
    ReadList(f, symbols, ReadSymbol, OK);
  END;

  OK := TRUE;
  data := segment;
END ReadSegment;

PROCEDURE ReadMapFromFile(VAR map:       pMap;
                              filename:  ARRAY OF CHAR);
(*
  OPERATION:
    Read the specified map file into memory.
*)
VAR
  OK: BOOLEAN;
BEGIN
  map := NIL;
  
  Lookup(mapFile, filename, FALSE);

  IF mapFile.res = done THEN
    NEW(map);

    WITH map^ DO
      ReadList(mapFile, segments, ReadSegment, OK);
    END;

    Close(mapFile);
    
    WriteString('Loaded MAP file: ');
    WriteString(filename);
    WriteLn;
  ELSE
    WriteString('Failed to load MAP file: ');
    WriteString(filename);
    WriteLn;
  END;
END ReadMapFromFile;

PROCEDURE FindSegment(    inMap:      pMap;
                          forSegment: CARDINAL;
                      VAR segment:    pSegment);
VAR
  curSegment: pSegment;
  done:       BOOLEAN;
  curNumber:  CARDINAL;
BEGIN
  segment := NIL;
  done := FALSE;

  LGetFirst(inMap^.segments, curSegment);
  
  IF curSegment = NIL THEN
    WriteString('no segments in map!');
    WriteLn;
  END;
  
  WHILE (curSegment <> NIL) AND NOT done DO
    curNumber := curSegment^.number;
    
    IF curNumber = forSegment THEN
      done := TRUE;
      segment := curSegment;
    ELSE
      LGetNext(inMap^.segments, curSegment);
    END;
  END;
END FindSegment;
                      
PROCEDURE FindSymbol(    inMap:     pMap;
                         forOffset: LONGCARD;
                         inSegment: CARDINAL;
                     VAR symbol:    pSymbol);
VAR
  segment:   pSegment;
  curSymbol: pSymbol;
  done:      BOOLEAN;
BEGIN
  symbol := NIL;
  done := FALSE;
  
  FindSegment(inMap, inSegment, segment);
  
  IF segment <> NIL THEN
    LGetFirst(segment^.symbols, curSymbol);
    
    (*
      Find the first symbol in this segment for which the input offset
      is greater than the offset of the symbol.
    *)
    WHILE (curSymbol <> NIL) AND (NOT done) DO
      IF forOffset < curSymbol^.offset THEN
        (* the last one was the one we want *)
        done := TRUE;
      ELSE
        symbol := curSymbol;
        LGetNext(segment^.symbols, curSymbol);
      END
    END;
  END;
END FindSymbol;

BEGIN
  debugModeOn := FALSE;
END LinkMap.
