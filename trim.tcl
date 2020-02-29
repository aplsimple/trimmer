#! /usr/bin/env tclsh
#
# This utility trims a Tcl source file off comments & needless whitespaces.
# See _ruff_preamble below for details.
#
# License: MIT.
#
###########################################################################

package provide trimmer 1.0

namespace eval trimmer {

  source "[file dirname [info script]]/batchio.tcl"

  variable _ruff_preamble "
 Trimming a Tcl source file off comments and whitespaces.

 ## Usage

     tclsh trim.tcl ?-i idir|ifile? ?-o odir? ?-r? ?-f? ?-n? ?--? ?app args?

 where \"?\" means *optional argument* and the arguments are:

    idir  - a directory of files to process (by default *idir* is .)
    ifile - a file listing .tcl files       (# / empty lines are skipped)
    odir  - a directory of resulting files  (by default *odir* is ../release)
    app   - an application to be run after trimming
    args  - optional arguments of *app*

 The -i (or --input) can be multiple, -o (or --output) can not.

 If -r (or --recursive) is set, the input directories are processed
 recursively. By default, they are processed non-recursively.

 If -f (or --force) is set, the existing output file(s) will be rewritten.
 By default, the trim.tcl doesn't rewrite the existing file(s).

 If -n (or --no) is set, no real changes made, supposed changes shown only.

 The *trim.tcl* by no means changes the input file(s).

 Example:

     tclsh trim.tcl -i ./lib -o ./bin tclsh ./bin/main.tcl arg1 \"arg 2\"

 ## Limitations

 The *trim.tcl* sets the following limitations for the code processed:

 **1.** Multi-line strings should be double-quoted (not braced),
  because the braced strings would be trimmed, e.g.

     set str1 \"
        Correct\"      ;# equals to \"\\n    Correct\"
     set str2 {
         Not correct}  ;# equals to \"Not correct\"


 **2.** Comments after \"\{\" should begin with \";#\", e.g.

     while {true} {  ;# infinite cycle
     }


 **3.** *List* or *switch* commands can contain comments (lines beginning
  with # or ;#) which are not considered to be meaningful items, e.g.

     switch \$option {
        ;# it's a comment (and the error in standard Tcl switch)
        -opt1 {
          puts \"-opt1 processed\"
        }
        -opt2 {
          puts \"-opt2 processed\"
        }
     }

 The 1st limitation is rarely encountered and easily overcome with
 \\n escape sequences.

 The last two limitations are actually the advantages of the utility.
 The 2nd requires a bit more discipline of coders.
 The 3rd eliminates Tcl comment freaks.

 For example, compare the behavior of *trim.tcl* and *trim_test.tcl*:

     tclsh trim.tcl -f -o trimmed

     tclsh trim_test.tcl -f -o trimmed

     tclsh trimmed/trim.tcl -f -o trimmed

     tclsh trimmed/trim_test.tcl -f -o trimmed

 ## License

  MIT.
"
}

###########################################################################

proc trimmer::countChar {str char} {

  # Counts a character in a string.
  #   str - a string
  #   char - a character
  #
  # Returns a number of non-escaped occurences of character *char* in
  # string *str*.
  #
  # See also:
  # [wiki.tcl-lang.org](https://wiki.tcl-lang.org/page/Reformatting+Tcl+code+indentation)

  set icnt 0
  while {[set idx [string first $char $str]] >= 0} {
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

proc trimmer::trimFile { finp fout} {

  # Trims an input file and writes a result to an output file.
  #   finp - input file name
  #   fout - output file name

  if { [catch {set chani [open "$finp" "r"]} e] } {
    batchio::onError $e 0
    return
  }
  if { [catch {set chano [open "$fout" "w"]} e] } {
    close $chani
    batchio::onError $e 0
    return
  }
  set brace -1
  set nquote 0
  while {[gets $chani line] >= 0} {
    if {$nquote} {
      set ic -1
    } else {
      set line [string trimleft $line]
      if {$brace>=0 && ($line=="" || [string range $line 0 0]=="#")} continue
      set ic [string first ";#" $line]
      if {[trimmer::countChar [string range $line 0 $ic] \"] % 2} {
        set ic -1  ;# the ";#" occurs in 1st string: don't look at the rest
      }
    }
    if {$ic==0} continue
    if {$ic>0} { set line [string range $line 0 [expr {$ic-1}]] }
    set line [string trimright $line]
    set prevbrace $brace
    if {$line=="\}"} {set brace 1} {set brace 0}
    if {$prevbrace!=-1 && (($prevbrace==1 && !$brace) ||
    (!$prevbrace && !$brace)) } {
      puts $chano ""
    }
    if {[set nqtmp [expr {[trimmer::countChar $line \"] % 2}]] && !$nquote} {
      set nquote 1
    } elseif {$nqtmp && $nquote} {
      set nquote 0
    }
    set eos [string range $line end end]
    if {$eos=="\{"} {
      set brace 2 
    } elseif {$eos=="\\"} {
      set brace 2
      if {$nquote} {
        set line [string range $line 0 end-1]
      } else {
        set line "[string trimright [string range $line 0 end-1]] "
      }
    }
    puts -nonewline $chano $line
  }
  puts $chano "\n#trimmed"
  close $chani
  close $chano
}

###########################################################################
# main program huh

if {[info exist ::argv0] && $::argv0==[info script]} {
  trimmer::batchio::main trimmer::trimFile *.tcl {*}$::argv
}

#-ARGS0:
#-ARGS0: -i .tmp/flist.txt -i . -r
#ARGS1: -n -i .tmp/flist.txt -i . -r the-nonexisting-command arg1 "arg 2"
#-ARGS2: -n -r -o ../tmp
#-ARGS3: -n -o ../tmp
#-ARGS4: -n -r
#-ARGS5: -n
#ARGS6: -f -o trimmed
