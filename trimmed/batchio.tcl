#! /usr/bin/env tclsh
namespace eval batchio {variable SynShown false
variable _ruff_preamble {
 Processing a batch of input files to make appropriate output files.

 ## License

 MIT.

 ## Usage

     tclsh script.tcl [-i idir|ifile] [-o odir] [-r] [-f] [-n] [--] [app args]

  where
 
  *script.tcl* is a Tcl script sourcing *batchio.tcl* to call its 'main' proc

  arguments are:

    -i idir - a directory of files to process (by default ./)
    -i ifile - a file listing files to process (#-comments disregarded)
    -o odir - a directory of resulting files (by default ../release)
    app - an application to be run after trimming
    args - optional arguments of *app*

 The `-i` (or `--input`) can be multiple, `-o` (or `--output`) can not.

 The command switches mean:

  * If `-r` (or `--recursive`) is set, the input directories are processed recursively. By default, they are processed non-recursively.

  * If `-f` (or `--force`) is set, the existing output file(s) will be rewritten. By default, the existing file(s) aren't rewritten.

  * If `-n` (or `--no`) is set, no real changes made, supposed changes shown only.

 Example:

tclsh trim.tcl -i ./lib -o ./bin tclsh -f ./bin/main.tcl arg1 "arg 2"}}
proc batchio::synopsis {} {variable SynShown
if {$SynShown} exit {set SynShown true}
set preamble [namespace parent]::_ruff_preamble
if {![info exist $preamble]} {set preamble [namespace current]::_ruff_preamble}
puts [string map [list \\\{ \{] [set $preamble]]\n}
proc batchio::underLine {} {puts " [string repeat - 75]"}
proc batchio::onError { {err ""} {doexit true}} {set err [string trim $err]
if {$doexit} {synopsis
if {$err != ""} { underLine; puts " $err" }
underLine
exit}
puts " $err"}
proc batchio::doFile {procN noact pdirN root finp odir rm args} {upvar $pdirN pdir
if {$root ne ""} {set idir [file dirname [file normalize $finp]]
set idir [string range $idir [string length $root]+1 end]
set fout [file join $odir $idir [file tail $finp]]
} else {set fout [file join $odir [file tail $finp]]}
set dinp [file dirname $finp]
set dout [file normalize $odir]
if {$pdir ne $dinp} {set pdir $dinp
puts " Input directory : $dinp"}
set fdisp "...[string range $fout [string length $dout] end]"
append fdisp [string repeat " " 80]
puts -nonewline "     Output file : [string range $fdisp 0 38]"
if { "[file normalize $finp]" eq "[file normalize $fout]" } {onError "-       the same." 0
return}
if { !$rm && [file exists $fout] } {onError "- already exists." 0
return}
puts ""
if {$noact} return
catch {file mkdir [file dirname $fout]}
$procN $finp $fout {*}$args}
proc batchio::recurseProc {procf dirname pattns} {foreach dir [glob -nocomplain [file join $dirname *]] {if {[file isdirectory $dir]} { recurseProc $procf $dir $pattns }}
foreach filetempl [split $pattns ", "] {if {![catch { set files [glob -nocomplain [file join $dirname $filetempl]]}]} {foreach f $files { {*}$procf [file normalize $f] }}}}
proc batchio::getFilesList {ilistN idir globPatt recursive} {if {![file exist $idir]} {onError "Input directory/file \"$idir\" does not exist."}
set root {}
if {[file isfile $idir]} {set ch [open $idir]
foreach fin [split [read $ch] \n] {set fin [string trim $fin]
if {$fin ne "" && [file exists $fin]} {if {[file isfile $fin]} {lappend $ilistN $fin
lappend root ""
} else {set [namespace current]::iltmp {}
if {$recursive} {recurseProc "lappend [namespace current]::iltmp" $fin $globPatt
} else {set [namespace current]::iltmp [glob -nocomplain [file join $fin $globPatt]]}
set rdir  [file normalize $fin]
foreach f [set [namespace current]::iltmp] {lappend $ilistN $f
lappend root $rdir}
unset [namespace current]::iltmp}}}
} else {if {$recursive} {recurseProc "lappend $ilistN" $idir $globPatt
} else {lappend $ilistN {*}[glob -nocomplain [file join $idir $globPatt]]}
lappend root [file normalize $idir]}
return $root}
proc batchio::main {procN globPatt options args} {underLine
if {![set ac [llength $args]]} {synopsis; underLine }
set mydir [file dirname [info script]]
set err [set remove [set recursive [set noact false]]]
lassign "" iopt odir mfile margs addargs
for {set i 0} {$i<$ac} {incr i} {lassign [lrange $args $i end] opt val
if {$opt eq "--"} {set mfile $val
incr i
} elseif {$mfile ne ""} {lappend margs $opt
} else {switch $opt {--input - -i {lappend iopt $val
incr i}
--output - -o {if {$odir ne ""} { onError "--output argument duplicated" }
set odir $val
incr i}
--recursive - -r {if {$recursive} { onError "--recursive argument duplicated" }
set recursive true}
--force - -f {if {$remove} { onError "--force argument duplicated" }
set remove true}
--no - -n {if {$noact} { onError "--no argument duplicated" }
set noact true}
default {set isapp true
set i2 0
foreach {o osh} $options {if {$opt in "$o $osh"} {set isapp false
lset options $i2 {}
lappend addargs $val
incr i
break}
incr i2}
if {$isapp} { set mfile $opt }}}}}
if {$iopt eq ""} { set iopt ./ }
if {$odir eq ""} { set odir ../release }
set odir [file normalize $odir]
if {[file isfile $odir]} { onError "\"$odir\" is not a directory." }
set ilistALL [set rootlistALL {}]
set tmpl [namespace current]::ilistTmp
foreach idir $iopt {
set $tmpl {}
set rootlist [getFilesList $tmpl $idir $globPatt $recursive]
lappend ilistALL {*}[set $tmpl]
lappend rootlistALL {*}$rootlist
unset $tmpl}
puts " OUTPUT DIRECTORY: $odir"
underLine
set pdir ""
lassign $rootlistALL root
foreach fin $ilistALL rt $rootlistALL {if {$rt ne ""} { set root $rt }
set fin [file normalize $fin]
if {[file isfile $fin]} {doFile $procN $noact pdir $root $fin $odir $remove {*}$addargs}}
underLine
set dispargs ""
foreach a $margs {if {[llength $a]>1} {set a "\"$a\""}
append dispargs "$a "}
if {$noact} {puts " Supposed run: \"$mfile\" $dispargs"
} elseif {$mfile ne ""} {set err ""
if {[set comm [auto_execok $mfile]] eq ""} {set err " Not found: $mfile"}
if {$err ne "" || [catch {exec {*}$comm {*}$margs } err]} {onError "Run:\n   \"$mfile\" $dispargs\n$err" 0}}}
#by trimmer
