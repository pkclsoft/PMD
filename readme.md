# PMD (Post Mortem Debugger) for ORCA/Modula-2

This repository provides the source for two utilities that may be used to facilitate limited post-mortem debugging with programs written in ORCA/Modula2.

## PMD
 
This utility was originally written alongside the compiler, and there was some mention of it within the
manual for the compiler, however I don't think it ever shipped.  The code I found was certainly incomplete
and not working.

I've spent a little time (February 2022) to make it functional to the point where it can now read the SDP file
and output the stack trace of the program that crashed.

The SDP file that is produced by a Modula2 program that has a "WITH EZDump" in it, contains enough information to allow the
stack trace to be produced, and, in theory, the contents of any local and global variables.

With the initial release on GitHub, only the stack trace functionality has been implemented, even though the actual data
for the variables should already exist within the SDP files from the original release of ORCA/Modula2.

## ConvertMap

This utility is used to convert the textual symbol table output by the ORCA/M linker (when the +l option is used) into a binary file that can be read and used by the PMD utility.

When you link your program, be sure to link it with the +l option, and redirect the output to a file.  For example:

```
link +l testpmd keep=$ > testpmd.sym
```

You can then run convertmap over that file to create a map file for the PMD utility:

```
convertmap testpmd.sym
```

## Making changes

If you would like to make changes to this utility (like add the functions I haven't) and distribute them to others, feel free to submit them here.

If you're wanting to make changes, then the modified utility needs to be able to read the SDP files produced by applications built by the original release of the compiler.  If you want to improve things and need to break that compatibility, then you need to make sure that the EZDump library code is compatible with what you do.

## Line Endings
The text and source files in this repository originally used CR line endings, as usual for Apple II text files, but they have been converted to use LF line endings because that is the format expected by Git. If you wish to move them to a real or emulated Apple II and build them there, you will need to convert them back to CR line endings.

If you wish, you can configure Git to perform line ending conversions as files are checked in and out of the Git repository. With this configuration, the files in your local working copy will contain CR line endings suitable for use on an Apple II. To set this up, perform the following steps in your local copy of the Git repository (these should be done when your working copy has no uncommitted changes):

1. Add the following lines at the end of the `.git/config` file:
```
[filter "crtext"]
	clean = LC_CTYPE=C tr \\\\r \\\\n
	smudge = LC_CTYPE=C tr \\\\n \\\\r
```

2. Add the following line to the `.git/info/attributes` file, creating it if necessary:
```
* filter=crtext
```

3. Run the following commands to convert the existing files in your working copy:
```
rm .git/index
git checkout HEAD -- .
```

Alternatively, you can keep the LF line endings in your working copy of the Git repository, but convert them when you copy the files to an Apple II. There are various tools to do this.  One option is `udl`, which is [available][udl] both as a IIGS shell utility and as C code that can be built and used on modern systems.

Another option, if you are using the [GSPlus emulator](https://apple2.gs/plus/) is to host your local repository in a directory that is visible on both your host computer, and the emulator via the excellent [Host FST](https://github.com/ksherlock/host-fst).

[udl]: http://ftp.gno.org/pub/apple2/gs.specific/gno/file.convert/udl.114.shk

## File Types
In addition to converting the line endings, you will also have to set the files to the appropriate file types before building the utility on a IIGS.

There is a `fixtypes` script (for use under the ORCA/M shell) that modifies the file and aux type of all source and build scripts, *apart from the fixtures script itself!*

So, once you have the files from the repository on your IIGS (or emulator), within the ORCA/M shell, execute the following command on each `fixtypes` script:

    filetype fixtypes src 6

## Building the utilities

Is as simple as running the `fixtypes` script, followed by the `build` script:

Once the build is complete, you can move both `pmd` and `convertmap` to the 16/ directory, and update the 15/syscmnd file so that
the can be found by ORCA/M automatically.

