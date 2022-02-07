MODULE ConvertMap;

FROM EZCommandLine IMPORT
  getParameters, getWord, getCommandLine, switchPresent, deleteSwitch;
FROM EZFileSystem IMPORT MakeFileName;
FROM GSOSInterface IMPORT
  GSOSNameLength;
FROM InOut IMPORT
  WriteLn, WriteString, WriteHex, WriteCard;
FROM LinkMap IMPORT
  pMap, ReadByteworksMap, WriteMapToFile, debugModeOn;
FROM Strings IMPORT
  Length;

IMPORT EZDump;

VAR
  symname: ARRAY [0..GSOSNameLength-1] OF CHAR;
  mapname: ARRAY [0..GSOSNameLength-1] OF CHAR;

PROCEDURE GetShellParms(VAR OK: BOOLEAN);
VAR
  parms:  ARRAY [0..79] OF CHAR;
BEGIN
  getParameters(parms);

  IF Length(parms) = 0 THEN
    OK := FALSE;
  ELSE
    OK := TRUE;

    IF switchPresent(parms, "-d") THEN
      deleteSwitch(parms, "-d");
      debugModeOn := TRUE;
    END;

    getWord(parms, 0, symname);
  END;

  IF NOT OK THEN
    WriteString('No file specified.');
    WriteLn;
  ELSE
    MakeFileName(symname, mapname, '.map');
    WriteString('Creating map file: "');
    WriteString(mapname);
    WriteString('" from symbol file: "');
    WriteString(symname);
    WriteString('"');
    WriteLn;
  END;
END GetShellParms;

VAR
  OK:   BOOLEAN;
  map:  pMap;

BEGIN
  GetShellParms(OK);

  IF OK THEN
    ReadByteworksMap(symname, map);

    IF map <> NIL THEN
      WriteMapToFile(map, mapname);
    ELSE
      WriteString('Error occurred while reading "');
      WriteString(symname);
      WriteString('"');
      WriteLn;
    END;
  END;
END ConvertMap.
