#! /usr/bin/env tclsh
package provide trimmer 1.2
namespace eval trimmer {source "[file dirname [info script]]/batchio.tcl"
variable _ruff_preamble {
 Trimming a Tcl source file off comments and whitespaces.

 ## Usage

     tclsh trim.tcl [-i idir|ifile] [-o odir] [-r] [-f] [-n] [--] [app args]

 where:

    -i idir - a directory of files to process (by default ./)
    -i ifile - a file listing .tcl files (#-comments disregarded)
    -o odir - a directory of resulting files (by default ../release)
    app - an application to be run after trimming
    args - optional arguments of *app*

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

 The 3rd eliminates Tcl comment freaks.

 The *trim.tcl* and *trim_test.tcl* set examples of this in action:

     tclsh trim.tcl -f -o trimmed

     tclsh trim_test.tcl -f -o trimmed

     tclsh trimmed/trim.tcl -f -o trimmed

     tclsh trimmed/trim_test.tcl -f -o trimmed

 ## License

MIT.}}
proc trimmer::countChar {str char} {set icnt 0
while {[set idx [string first $char $str]] >= 0} {set backslashes 0
set nidx $idx
while {[string equal [string index $str [incr nidx -1]] \\]} {incr backslashes}
if {$backslashes % 2 == 0} { incr icnt }
set str [string range $str [incr idx] end]}
return $icnt}
proc trimmer::trimFile {finp fout args} {if { [catch {set chani [open "$finp" "r"]} e] } {batchio::onError $e 0
return}
if { [catch {set chano [open "$fout" "w"]} e] } {close $chani
batchio::onError $e 0
return}
set brace [set braceST -1]
set nquote 0
while {[gets $chani line] >= 0} {if {$nquote} {set ic -1
} else {if {$braceST<1} {foreach cmd {set variable} {if {[set braceST [regexp "^\\s*$cmd\\s+\\S+\\s+\{" $line]]} {set line "\n[string trimleft $line]"
set cbrc 0
break}}}
if {$braceST>0} {incr cbrc [expr {[countChar $line \{] - [countChar $line \}]}]
if {$cbrc<=0} {set brace [set braceST -1]
} else {puts $chano $line
continue}}
set line [string trimleft $line " \t"]
if {$brace>=0 && [string index $line 0] in {"" "#"}} continue
set ic [string first ";#" $line]   ;# if ;# in string, ignore the rest
if {[countChar [string range $line 0 $ic] \"] % 2} { set ic -1 }}
if {$ic==0} continue
if {$ic>0} { set line [string range $line 0 [expr {$ic-1}]] }
set line [string trimright $line]
set prevbrace $brace
set brace [expr {$line eq "\}" ? 1 : 0}]
if {($prevbrace==1 || $prevbrace==0) && !$brace} { puts $chano "" }
if {[set _ [expr {[countChar $line \"] % 2}]]} {set nquote [expr {!$nquote}]}
if {[set _ [string index $line end]] eq "\{"} {set brace 2
} elseif {$_ eq "\\"} {set brace 2
if {$nquote} {set line [string range $line 0 end-1]
} else {set line "[string trimright [string range $line 0 end-1]] "}}
puts -nonewline $chano $line}
puts $chano "\n#by trimmer"
close $chani
close $chano}
if {[info exist ::argv0] && $::argv0 eq [info script]} {trimmer::batchio::main trimmer::trimFile *.tcl {} {*}$::argv}
#by trimmer
