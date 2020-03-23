# What's it #

 It's a CLI utility that trims Tcl source files off comments and whitespaces.

 By this, you can get a working Tcl code stripped of needless stuff and, as a side effect, of some Tcl's freaks (the most notorious are "supposed comments" inside `list` and `switch` commands).

 Also, the trimmed code:

  1. performs a bit faster
  2. needs less a disk volume
  3. if necessary, impedes modifications


# License #

 MIT.


# Download #

 [trimmer.zip](https://chiselapp.com/user/aplsimple/repository/trimmer/download)


# Usage #

  The utility is run using the following syntax:

       tclsh trim.tcl [-i idir|ifile] [-o odir] [-r] [-f] [-n] [--] [app args]

  where:

  ` idir `  - a directory of files to process (by default `idir=./`)

  ` ifile ` - a file listing .tcl files (#-comments are ignored)

  ` odir `  - a directory of resulting files (by default `odir=../bin`)

  ` app `   - an application to be executed after trimming

  ` args `  - optional arguments of the `app`

 The `-i (--input)` can be multiple, `-o (--output)` can not.

 If `-r (--recursive)` is set, the input directories are processed
 recursively. By default, they are processed non-recursively.

 If `-f (--force)` is set, the existing output file(s) will be rewritten.
 By default, the *trim.tcl* doesn't rewrite the existing file(s).

 If `-n (or --no)` is set, no real changes made, supposed changes shown only.

 The *trim.tcl* by no means changes the input file(s).

 Example:

       tclsh trim.tcl -i ./lib -o ./bin tclsh ./bin/main.tcl arg1 "arg 2"


# Limitations #

The *trim.tcl* sets the following limitations for the code processed:

**1.** In general, multi-line strings should be double-quoted (not braced),
  because the braced strings would be trimmed. But there are two important
  exceptions: when `set` and `variable` commands use a braced string, it
  is not trimmed, e.g.

       set str1 "
          Correct"       ;# equals to set str1 "\n   Correct"
       set str1 {
          Correct}       ;# equals to set str1 "\n   Correct"
       variable str2 "
          Correct"       ;# equals to variable str2 "\n   Correct"
       variable str2 {
          Correct}       ;# equals to variable str2 "\n   Correct"
       puts "
          Correct"       ;# equals to puts "\n   Correct"
       puts {
           NOT CORRECT}  ;# equals to puts "NOT CORRECT"

**2.** Comments after "{" should begin with ";#", e.g.

       while {true} {  ;# infinite cycle
       }

**3.** `List` and `switch` commands can contain comments which are not
  considered to be meaningful items, e.g.

       switch $option {
          # it's a comment (and the error in standard Tcl switch)
          -opt1 {
            puts "-opt1 processed"
          }
          # ...
       }

 The 1st limitation is rarely encountered and easily overcome with
 \n escape sequences.

 The last two limitations are actually the advantages of the utility.

 The 2nd requires a bit more discipline of coders.

 The 3rd eliminates Tcl comment freaks, incl. unmatched braces.

 The *trim.tcl* and *trim_test.tcl* set examples of this in action:

       tclsh trim.tcl -f -o trimmed
  
       tclsh trim_test.tcl -f -o trimmed
  
       tclsh trimmed/trim.tcl -f -o trimmed
  
       tclsh trimmed/trim_test.tcl -f -o trimmed
