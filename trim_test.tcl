#! /usr/bin/env tclsh
#
# This utility trims a Tcl source file off comments & needless whitespaces.
# See _ruff_preamble below for details.
#
# License: MIT.
#
###########################################################################

# Below is an example of code that uses "supposed comments" in switch and
# list commands and as such is not working. Disregarding this difference
# and this comment, the trim_test.tcl is the same as the trim.tcl.
#
# So, the trim_test.tcl would work only after being undergone the trimming.
#
# In other words, the trimmed trim_test.tcl works as well as the trim.tcl.

  switch a {
    # it's a supposed comment that makes an error
    b {}
    c {}
  }

  set l [list \
    # it's a supposed comment that makes an error
    a b c]

###########################################################################

package provide trimmer 1.4

namespace eval trimmer {

  source "[file dirname [info script]]/batchio.tcl"

  variable _ruff_preamble {
 Trimming a Tcl source file off comments and whitespaces.

 ## License

 MIT.

 ## Download

 [trimmer.zip](https://chiselapp.com/user/aplsimple/repository/trimmer/download)

 ## Usage

     tclsh trim.tcl [-i idir|ifile] [-o odir] [-r] [-f] [-n] [--] [app args]

 where:

    -i idir - a directory of files to process (by default ./)
    -i ifile - a file listing .tcl files (#-comments disregarded)
    -o odir - a directory of resulting files (by default ../release)
    app - an application to be run after trimming
    args - optional arguments of `app`

 The `-i` (or `--input`) can be multiple, `-o` (or `--output`) can not.

 The command switches mean:

  * If `-r` (or `--recursive`) is set, the input directories are processed recursively. By default, they are processed non-recursively.

  * If `-f` (or `--force`) is set, the existing output file(s) will be rewritten. By default, the *trim.tcl* doesn't rewrite the existing file(s).

  * If `-n` (or `--no`) is set, no real changes made, supposed changes shown only.

 The *trim.tcl* by no means changes the input file(s).

 Example:

     tclsh trim.tcl -i ./lib -o ./bin tclsh -f ./bin/main.tcl arg1 "arg 2"

 ## Limitations

 The *trim.tcl* sets the following limitations for the code processed:

 **1.** In general, multi-line strings should be double-quoted (not braced),
  because the braced strings would be trimmed. But there are two important
  exceptions: when *set* and *variable* commands use a braced string, it
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

 **2.** Comments after "\{" should begin with ";#", e.g.

     while {true} {  ;# infinite cycle
     }


 **3.** *List* or *switch* commands can contain comments which are not
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

     tclsh trimmed/trim_test.tcl -f -o trimmed}

}

###########################################################################

proc trimmer::countCh {str ch} {

  # Counts a character in a string.
  #   str - a string
  #   ch - a character
  #
  # Returns a number of non-escaped occurences of character *ch* in
  # string *str*.
  #
  # See also:
  # [wiki.tcl-lang.org](https://wiki.tcl-lang.org/page/Reformatting+Tcl+code+indentation)

  set icnt 0
  while {[set idx [string first $ch $str]] >= 0} {
    set backslashes 0
    set nidx $idx
    while {[string equal [string index $str [incr nidx -1]] \\]} {
      incr backslashes
    }
    if {$backslashes % 2 == 0} { incr icnt }
    set str [string range $str [incr idx] end]
  }
  return $icnt
}

###########################################################################

proc trimmer::trimFile {finp fout args} {

  # Trims an input file and writes a result to an output file.
  #   finp - input file name
  #   fout - output file name
  #   args - additional parameters (so far not used)

  if { [catch {set chani [open "$finp" "r"]} e] } {
    batchio::onError $e 0
    return
  }
  if { [catch {set chano [open "$fout" "w"]} e] } {
    close $chani
    batchio::onError $e 0
    return
  }
  set brace [set braceST [set ccmnt -2]]
  set quoted 0
  while {[gets $chani line] >= 0} {
    set ic -1
    if {!$quoted} {      ;# it's not a multi-line quoted string
      if {$braceST<1} {  ;# check a braced string at some important commands
        foreach {cmd a1} {set "\\S" variable "\\S"} {
          if {[set braceST [regexp "^\\s*$cmd\\s+$a1+\\s+\{" $line]]} {
            set line "\n[string trimleft $line]"
            set cbrc 0
            break
          }
        }
      }
      if {$braceST>0} {  ;# check matching left/right braces
        incr cbrc [ expr {[countCh $line "\{"] - [countCh $line "\}"]} ]
        if {$cbrc<=0} {
          set brace [set braceST -1]
        } else {
          puts $chano $line
          continue
        }
      }
      if {[regexp "^\\s*;*#" $line] || $ccmnt} {
        set cc [ expr {[string index $line end] eq "\\"} ]
        if {($ccmnt || $cc) && $brace<-1} { puts $chano $line }
        set ccmnt $cc  ;# comments continued
        continue
      }
      set line [string trimleft $line "\t\ "]
      if {$line eq ""} continue
      foreach s [regexp -all -inline -indices ";#" $line] {
        if {[countCh \
        [set _ [string range $line 0 [lindex $s 0]-1]] \
        "\""] % 2 == 0} { ;# example of continued command
          set ccmnt [ expr {[string index $line end] eq "\\"} ]
          set line [ string trimright $_ ]
          break   ;# the ending ";#" is a comment
        }
      }
      if {$ccmnt} {
        set brace [set braceST -1]
        puts $chano "\n$line"  ;# the ending ";#" is a comment continued \
           (example of continued comment) \
           (end of example)
        continue
      }
    }
    if {$ic==0} continue  ;# for comments beginning with ";#" 
    if {$ic>0} { set line [string range $line 0 $ic-1] }
    set line [string trimright $line]
    set prevbrace $brace
    set brace [ expr {$line eq "\}" ? 1 : 0} ]
    if {$prevbrace in {1 0} && !$brace} { puts $chano "" }
    if {[countCh $line "\""]%2} { set quoted [ expr {!$quoted} ] }
    if {[set _ [string index $line end]] eq "\{"} {
      set brace 2           ;# line ending with \{ will join with next line
    } elseif {$_ eq "\\"} {
      set brace 2           ;# the ending "\" should be removed
      set line [string range $line 0 end-1]
      if {!$quoted} { set line "[string trimright $line] " }
    }
    puts -nonewline $chano $line
  }
  puts $chano "\n#by trimmer"
  close $chani
  close $chano
}

###########################################################################
# main program huh

if {[info exist ::argv0] && $::argv0 eq [info script]} {
  trimmer::batchio::main trimmer::trimFile *.tcl {} {*}$::argv
}

#-ARGS0:
#-ARGS0: -f
#-ARGS0: -i .tmp/flist.txt -i . -r
#-ARGS1: -n -i .tmp/flist.txt -i . -r the-nonexisting-command arg1 "arg 2"
#-ARGS2: -n -r -o ../tmp
#-ARGS3: -n -o ../tmp
#-ARGS4: -n -r
#-ARGS5: -n
#ARGS6: -f -o trimmed
