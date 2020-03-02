#! /usr/bin/env tclsh
#
# This is for processing a batch of input files to make a batch of
# appropriate output files.
#
# See _ruff_preamble below for details.
#
# License: MIT.
#
###########################################################################


namespace eval batchio {

  variable SynShown false
  variable _ruff_preamble {
 Processing a batch of input files to make appropriate output files.

 ## Usage

     tclsh script.tcl [-i idir|ifile] [-o odir] [-r] [-f] [-n] [--] [app args]

  where
 
  *script.tcl* is a Tcl script sourcing *batchio.tcl* to call its 'main' proc

  arguments are:

    idir  - a directory of files to process (by default ./)
    ifile - a file listing .tcl files       (#-comments disregarded)
    odir  - a directory of resulting files  (by default ../release)
    app   - an application to be run after trimming
    args  - optional arguments of *app*

 The -i (or --input) can be multiple, -o (or --output) can not.

 If -r (or --recursive) is set, the input directories are processed
 recursively. By default, they are processed non-recursively.

 If -f (or --force) is set, the existing output file(s) will be rewritten.
 By default, the script.tcl doesn't rewrite the existing file(s).

 If -n (or --no) is set, no real changes made, supposed changes shown only.

 Example:

     tclsh trim.tcl -i ./lib -o ./bin tclsh -f ./bin/main.tcl arg1 "arg 2"

 ## License

 MIT.}

}

###########################################################################

proc batchio::synopsis {} {

  # Shows a syntax and a usage of namespace.
  #
  # If *_ruff_preamble* is defined in the parent namespace, puts it.
  # Otherwise puts its own *_ruff_preamble*.

  variable SynShown
  if {$SynShown} exit {set SynShown true}
  set preamble [namespace parent]::_ruff_preamble
  if {![info exist $preamble]} {
    set preamble [namespace current]::_ruff_preamble
  }
  puts [string map [list \\\{ \{] [set $preamble]]\n
}

###########################################################################

proc batchio::underLine {} {

  # Puts out an underlining string.

  puts " [string repeat - 75]"
}

###########################################################################

proc batchio::onError { {err ""} {doexit true}} {

  # Shows an error and optionally performs *exit*.
  #   err - optional error message (empty by default, to put the synopsis)
  #   doexit - optional boolean flag to perform *exit* (true by default)

  set err [string trim $err]
  if {$doexit} {
    synopsis
    if {$err != ""} { underLine; puts " $err" }
    underLine
    exit
  }
  puts " $err"
}

###########################################################################

proc batchio::doFile {procN noact pdirN root finp odir rm args} {

  # Prepares and does a call of procedure to process two files.
  #   procN - name of procedure to process two files
  #   noact - if true, no output file
  #   pdirN - variable's name of previous input directory
  #   root  - root of input directory
  #   finp  - input file
  #   odir  - output directory
  #   rm    - flag 'rewrite the existing output file or not'
  #   args  - other arguments
  #
  # If *noact* is true, no outputs are actually made (to show only).
  #
  # The *pdirN* is used to show an input directory when changed.
  # It needs only to be initialized with "".
  #
  # The *root* is a root name of input directory that is used to make
  # the output path from the *odir* and a relative (to *root*) part
  # of *finp*.
  #
  # If *root* is empty, an input file is set instead of a directory,
  # so the output path has no relative part.

  upvar $pdirN pdir
  if {$root ne ""} {
    # input subdir
    set idir [file dirname [file normalize $finp]]
    set idir [string range $idir [string length $root]+1 end]
    # outdir + input subdir + input filename = output file
    set fout [file join $odir $idir [file tail $finp]]
  } else {
    set fout [file join $odir [file tail $finp]]
  }
  set dinp [file dirname $finp]
  set dout [file normalize $odir]
  if {$pdir ne $dinp} {
    set pdir $dinp
    puts " Input directory : $dinp"
  }
  set fdisp "...[string range $fout [string length $dout] end]"
  append fdisp [string repeat " " 80]
  puts -nonewline "     Output file : [string range $fdisp 0 38]"
  if { "[file normalize $finp]" eq "[file normalize $fout]" } {
    onError "-       the same." 0
    return
  }
  if { !$rm && [file exists $fout] } {
    onError "- already exists." 0
    return
  }
  puts ""
  if {$noact} return
  catch {file mkdir [file dirname $fout]}
  $procN $finp $fout {*}$args
}

###########################################################################

proc batchio::recurseProc {procf dirname pattns} {

  # Applies a command to files of a directory, recursively.
  #   procf   - a command to apply
  #   dirname - a directory to scan
  #   pattns  - glob patterns of files (devided by " " or ",")
  #
  # See also: getInputFilesList

  foreach dir [glob -nocomplain [file join $dirname *]] {
    if {[file isdirectory $dir]} { recurseProc $procf $dir $pattns }
  }
  # no dirs anymore
  foreach filetempl [split $pattns ", "] {
    if {![catch { \
    set files [glob -nocomplain [file join $dirname $filetempl]]}]} {
      foreach f $files { {*}$procf [file normalize $f] }
    }
  }
}

###########################################################################

proc batchio::getInputFilesList {ilistN idir globPatt recursive} {

  # Gets a list of input files.
  #   ilistN    - a name of variable to contain the resulting list
  #   idir      - a name of input directory / file
  #   globPatt  - glob pattern for files to be processed
  #   recursive - a boolean to scan directories recursively
  #
  # If *idir* is a directory, it is scanned for files.
  #
  # If *idir* is a file, it should contain a list of directories (to scan
  # for files to be included in the list) and/or files (to be included in
  # the list directly).
  #
  # Returns a list of *roots*, i.e. root directory names for scanned
  # directories or "" for files included directly.
  #
  # See also: recurseProc

  if {![file exist $idir]} {
    onError "Input directory/file \"$idir\" does not exist."
  }
  set root {}
  if {[file isfile $idir]} {
    # it's a file containing a list of files and/or directories
    set ch [open $idir]
    foreach fin [split [read $ch] \n] {
      set fin [string trim $fin]
      if {$fin ne "" && [file exists $fin]} {
        if {[file isfile $fin]} {      ;# a file
          lappend $ilistN $fin
          lappend root ""
        } else {                       ;# a directory
          set [namespace current]::iltmp {}
          if {$recursive} {
            recurseProc "lappend [namespace current]::iltmp" $fin $globPatt
          } else {
            set [namespace current]::iltmp \
              [glob -nocomplain [file join $fin $globPatt]]
          }
          set rdir  [file normalize $fin]
          foreach f [set [namespace current]::iltmp] {
            lappend $ilistN $f
            lappend root $rdir
          }
          unset [namespace current]::iltmp
        }
      }
    }
  } else {
    if {$recursive} {
      recurseProc "lappend $ilistN" $idir $globPatt
    } else {
      lappend $ilistN {*}[glob -nocomplain [file join $idir $globPatt]]
    }
    lappend root [file normalize $idir]
  }
  return $root
}

###########################################################################

proc batchio::main {procN globPatt options args} {

  # Main procedure of batchio.
  #   procN - name of procedure to process two files
  #   globPatt - glob pattern for files to be processed
  #   options  - list of {opt optshort}, additional options
  #   args - arguments passed to script.tcl, containing switches and values:
  #   -i   - (or --input) input directory or file of processed list
  #   -o   - (or --output) output directory
  #   -r   - (or --recursive) a flag to scan directories recursively
  #   -f   - (or --force) a flag to rewrite existing output files
  #   -n   - (or --no) a flag to show output files only, without making
  #   --   - to end the switches and begin a command to run
  #   rest - resting arguments are a command to run and its arguments

  underLine
  
  # when run without arguments, put the synopsis
  if {![set ac [llength $args]]} {synopsis; underLine }
  
  # get arguments and check if the arguments are correct
  set mydir [file dirname [info script]]
  set err [set remove [set recursive [set noact false]]]
  lassign "" iopt odir mfile margs addargs
  for {set i 0} {$i<$ac} {incr i} {
    lassign [lrange $args $i end] opt val
    if {$opt eq "--"} {
      set mfile $val
      incr i
    } elseif {$mfile ne ""} {  ;# after an application, its arguments go
      lappend margs $opt
    } else {                   ;# here the batchio options go
      switch $opt {
        --input - -i {
           lappend iopt $val
           incr i
           }
        --output - -o {
           if {$odir ne ""} { onError "--output argument duplicated" }
           set odir $val
           incr i
           }
        --recursive - -r {
           if {$recursive} { onError "--recursive argument duplicated" }
           set recursive true
           }
        --force - -f {
           if {$remove} { onError "--force argument duplicated" }
           set remove true
           }
        --no - -n {
           if {$noact} { onError "--no argument duplicated" }
           set noact true
           }
        default {
          set isapp true
          set i2 0
          foreach {o osh} $options {
            if {$opt in "$o $osh"} {
              set isapp false
              lset options $i2 {}
              lappend addargs $val
              incr i
              break
            }
            incr i2
          }
          if {$isapp} { set mfile $opt }
        }
      }
    }
  }
  if {$iopt eq ""} { set iopt ./ }
  if {$odir eq ""} { set odir ../release }
  set odir [file normalize $odir]
  if {[file isfile $odir]} { onError "\"$odir\" is not a directory." }
  
  # get the input files list from the list of input directories and/or files
  set ilistALL [set rootlistALL {}]
  set tmpl [namespace current]::ilistTmp
  foreach idir $iopt {
    set $tmpl {}
    set rootlist [getInputFilesList $tmpl $idir $globPatt $recursive]
    lappend ilistALL {*}[set $tmpl]
    lappend rootlistALL {*}$rootlist
    unset $tmpl
  }
  
  # process all files
  puts " OUTPUT DIRECTORY: $odir"
  underLine
  set pdir ""
  lassign $rootlistALL root
  foreach fin $ilistALL rt $rootlistALL {
    if {$rt ne ""} { set root $rt }
    set fin [file normalize $fin]
    if {[file isfile $fin]} {
      doFile $procN $noact pdir $root $fin $odir $remove {*}$addargs
    }
  }
  underLine
  
  # run a command if set
  set dispargs ""
  foreach a $margs {
    if {[llength $a]>1} {set a "\"$a\""}
    append dispargs "$a "
  }
  if {$noact} {
    puts " Supposed run: \"$mfile\" $dispargs"
  } elseif {$mfile ne ""} {
    set err ""
    if {[set comm [auto_execok $mfile]] eq ""} {
      set err " Not found: $mfile"
    }
    if {$err ne "" || [catch {exec {*}$comm {*}$margs } err]} {
      onError "Run:\n   \"$mfile\" $dispargs\n$err" 0
    }
  }
}
