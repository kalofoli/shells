#! /bin/bash

# program constants
tmpdir=/tmp/
# Settable params
unlink=1;
log=''
nup=2x1
jobs=4
paperx=595
papery=842
marginx=18
marginy=$( echo "$marginx * $papery / $paperx" | bc -l)
offsetx=10
offsety=1
debug=0
verbose=0
dry=0
nocrop=0
nproc=4
gs=gs
pbmpsize=$(( 1024*1024 ))
dirout=''

opts="hl:n:j:dvp:D:C"
longopts="help,nproc:,paper-y:,paper-x:,margin-y:,dir:,margin-x:,dry,offset-x:,offset-y:,debug,verbose,nup:,jobs:,unlink,log:,no-crop"
usage="usage:
\t$(basename $0) [options] [long-options] [--] files\n
 	-h|--help       Help message\n
 	--paper-y    Y  paper vertical size (Default: $papery).\n
 	--paper-x    X  paper horizontal size (Default: $paperx).\n
 	--margin-y   Y  vertical margin (Default: $marginy).\n
 	--margin-x   X  horizontal margin (Default: $marginx).\n
 	--offset-y   Y  bottom offset (Default: $offsety).\n
 	--offset-x   X  left offset (Default: $offsetx).\n
 	--dry           Toggle dry-run (Default: $dry).\n
 	-C|--no-cpop C  No crop. (Default: $nocrop).\n
 	-D|--dir     D  Save resulting files to folder D. Set to '' to save in-place. (Default: $dry).\n
 	-n|--nup     N  Number of pages per side CxR (Defaulf: $nup).\n
 	-j|--jobs    N  Number of processor cores to use (Defaulf: $jobs).\n
 	-u|--unlink     Toggle unlink temporary files (Default: $unlink)\n
 	-l|--log     F  Use F as a log file, '' for none. (Default: $log)\n
 	-d|--debug      Toggle debugging. (Default: $debug)\n
 	-v|--verbose    Toggle verbose. (Default: $verbose)\n
 	-p|--nproc   N  Set number of parallel processes (Default: $nproc).\n
"
ARGS="`getopt -n "$0" -l $longopts -o $opts -- "$@"`"
if (( err=$? )); then echo -e $usage ; exit $err ; fi
eval set -- $ARGS

while true; do
	case "$1" in
	-l|--log) log="$2";shift 2;;
	-u|--unlink) unlink=$((!$unlink));shift;;
	-d|--debug) debug=$((!$debug));shift;;
	-v|--verbose) verbose=$((!$verbose));shift;;
	-n|--nup) nup="$2";shift 2;;
	-j|--jobs) jobs="$2";shift 2;;
	-C|--no-crop) nocrop=$((! $nocrop));shift 1;;
	-D|--dir) dirout="$2";shift 2;;
	--dry) dry=$((! $dry));shift;;
	--offset-y) offsety="$2";shift 2;;
	--offset-x) offsetx="$2";shift 2;;
	--nproc) nproc="$2";shift 2;;
	--paper-y) papery="$2";shift 2;;
	--paper-x) paperx="$2";shift 2;;
	--margin-y) marginy="$2";shift 2;;
	--margin-x) marginx="$2";shift 2;;
	-h|--help) echo -e $usage;exit 0;;
	--) shift;break;;
	*) echo "INTERNAL OPTION ERROR: $1";exit 1 ;;
	esac
done

if (( $debug )) ; then echo "\
Parameters used:
unlink="$unlink"
log="$log"
nup="$nup"
jobs="$jobs"
paperx="$paperx"
papery="$papery"
marginx="$marginx"
marginy="$marginy"
offsetx="$offsetx"
offsety="$offsety"
pbmpsize="$pbmpsize"
debug="$debug"
verbose="$verbose"
dry="$dry"
nocrop="$nocrop"
dirout="$dirout"
nproc="$nproc"
gs="$gs"
Files specified:\
" >&2
echo "$@" | while read each ; do echo "$each" >&2; done
echo >&2
fi
function calc() {
	echo "$@" | bc -l
}

function invoke () {
	if (( dry )); then for each in "$@"; do echo -n "'$each' "; done ; echo ;
	elif [ ! -z "$log" ] ; then "$@" &>>"$log"
	else "$@"
	fi
}
function gscall () {
	gsin="$1"
	gsout="$2"
	shift 2
	gscmd=($verb_gs -dNOPAUSE \
		-dBATCH \
		-sDEVICE=pdfwrite \
		-dSAFER \
		-dCompatibilityLevel="1.3" \
		-dNumRenderingThreads="$jobs" \
		-dMaxPatternBitmap="$pbmpsize" \
		-dPDFSETTINGS="/printer" \
		-dSubsetFonts=true \
		-dEmbedAllFonts=true \
		-sOutputFile="$gsout" \
		"$@" -f "$gsin")
	invoke "$gs" "${gscmd[@]}"
}
function pdfmargin () {
	marin="$1"
	marout="$2"
	scalex=$(calc "($paperx-$marginx*2)/$paperx")
	scaley=$(calc "($papery-$marginy*2)/$papery")
	pscmd="$(calc $marginx+$offsetx) $(calc $marginy+$offsety) translate $scalex $scaley scale"
	gscall "$marin" "$marout" -c "<</BeginPage{$pscmd}>> setpagedevice"
}

function pdfcenter() {
	gscall "$@" -dFIXMEDIA -dPDFFitPage -sPAPERSIZE=a4 
}
function prepare() {
	input_base=$(basename "$1")
	input_dir=$( dirname "$1");
	if [ ! -z "$log" ] ; then exec &> "$log" ; fi
	tempc=`mktemp -u -d "${tmpdir}tmp.$input_base.cropXXX.pdf"`
	tempcc=`mktemp -u -d "${tmpdir}tmp.$input_base.crop-centXXX.pdf"`
	tempn=`mktemp -u -d "${tmpdir}tmp.$input_base.nupXXX.pdf"`
	tempnc=`mktemp -u -d "${tmpdir}tmp.$input_base.nup-centXXX.pdf"`
	if [ -z "$dirout" ]; then dir="$input_dir"; else dir="$dirout";fi
	out="$dir/nup-$input_base"
	if (( $nocrop )); then 
		cp "$1" "$tempc"
	else
		invoke pdfcrop $verb_crop --margin '5 0' "$1" "$tempc" 
	fi
	pdfcenter "$tempc" "$tempcc" &&
	invoke pdfxup -x "${nup%x*}" -y "${nup#*x}" -o "$tempn" "$tempcc" &&
	pdfcenter "$tempn" "$tempnc" &&
	pdfmargin "$tempnc" "$out"
	status=$?
	if (( unlink )); then invoke rm -- "$tempn" "$tempc" "$tempcc" "$tempnc"; fi 
	return $isok
}
# Handle verbosity
if (( verbose )); then
        verb_crop=--verbose
        verb_gs=''
else
        verb_crop=''
        verb_gs='-q'
fi
	

p=0
while (( $# >0 )) ; do
	(prepare "$1" )&
	let p+=1
	if (( p>$nproc )) ; then p=0; wait; fi
	shift
done
wait
