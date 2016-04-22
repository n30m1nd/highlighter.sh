#!/bin/bash

# Thanks to king no-so, master of bash-fu one-liners and tamer of the Kraken

# TODO: Effectively wait for background commands. 
# TODO: Add support for interactive commands such as /bin/bash (I expect not to use expect)
# TODO: Prevent file overwrite (In function: do_screenshot)
# TODO: Support multiple matching groups and generate an image per matching group

# UNCOMMENT THE NEXT LINE FOR DEBUGGING
# set -x

# ImageMagicks PANGO's CONFIG #
default_font="Courier"
default_font_color='green'
font_tag_start="<span font_family='monospace' background='black' fgcolor='$default_font_color'>"
font_tag_end="</span>"
# END OF CONFIG #

# Bash COLORS/FONTS
bold_bf=$(tput bold)
normal_bf=$(tput sgr0)

# BANNER #
echo -e "\e[101m\e[5m******* RECUADRER.SH *******\e[49m\e[39m"

# Auxiliary functions, keeps mental sanity

function print_red {
  echo -e "\e[31m$1\e[39m"
}

function print_green {
  echo -e "\e[32m$1\e[39m"
}

function print_yellow {
  echo -e "\e[33m$1\e[39m"
}

function get_targets {
  if [ -e $input ]; then
    echo "$(cat $input)"
  else
    echo "$input"
  fi
}

function exec_command {
  # We need to escape <>& in order for pango to work well
  local cmdoutput=$(2>&1 eval "$1" | sed -e 's|<|\&lt;|g' -e 's|>|\&gt;|g' -e 's#\&#\\\&amp;#gi') 
  echo "$cmdoutput"
}

function highlight {
  # Highlights by adding <span> tags for pango, an imagemagick's module
  local search_regex="$(echo "$1" | sed -e 's#\((\)#\\\1#g' -e 's#\()\)#\\\1#g')"
  local cmd_output="$2"
  echo "$(echo "$cmd_output" | sed "s#$search_regex#<span background='red' weight='bold' fgcolor='white'>\1</span>#ig")"
}

function do_screenshot {
  local output="$1"
  local save_to="$2"
  output_pango="<markup><tt>$font_tag_start$output$font_tag_end</tt></markup>"
  if [ -z "$output" ]; then
    print_red "[E] Couldn't generate screenshot at $save_to"
  else
    convert -border 10x10 -bordercolor black -background black -kerning 1 -size 1024x pango:"$output_pango" "$save_to" && \
    print_green "[+] Screenshot generated: $save_to" || \
    print_red "[E] Couldn't generate screenshot at $save_to"
  fi
}

function show_help {
  echo -e "Usage: $0 -c "command _target_" -h host_or_input_file -r regex [-t threads] [-O outputfile_or_path]"
  echo -e "  -c [command to run]: Sepcify the command to take a screenshot of."
  echo -e "\t Write the string ${bold_bf}_target_${normal_bf} in the position you want your target host replaced."
  echo -e "  -h [target]: Target can be an IP a domain or an input file with a list of hosts, each host per line"
  echo -e "  -r [regex]: Regex must contain a matching group that will be highlighted."
  echo -e "\t Example: -r \"(.*)\" Will match everything in the screenshot."
  echo -e "  -t [number]: Maximum number of threads to run"
  echo -e "  -O [output]: File or path to save images to."
  echo -e "\t Ex: -O \"myfolder/prepend-this-\" Will generate a file in \"myfolder\" with the name \"prepend-this-target.domain.com.png\""
  echo -e "Examples: "
  echo -e "\tRead domains/ips from a file and highlight the server header"
  echo -e "\t\t$0 -c \"curl -I -s _target_\" -h targets.txt -r \"(server.*)\\\r\" -t 3 -O server-header-"
  echo -e "\tHighlight open ports on a single domain/ip"
  echo -e "\t\t$0 -c \"nmap -F -sT _target_\" -h scanme.nmap.org -r \"(.*open.*)\""
}

# EOF auxiliary functions, mental insanity now

function main {
  local target="$2"
  local cmd="$(echo $1 | sed "s/_target_/$target/g")"
  local regex="$3"
  local save_to="$4$target.png"

  echo "[+] Running: $cmd"
  local output=$(exec_command "$cmd")

  if [ -n "$output" ]; then
    output="$(highlight "(.*)" "$target\n")$output"
    do_screenshot "$(highlight "$regex" "$output")" "$save_to"  
  else
    print_red "[-] Problems accessing $target"
  fi
}

function show_usage {
  echo -e "[+] Usage: \n\t$0 -c command -h input_target(s) -r regex -t max_threads_to_run -O output_path_or_file"

}


### Mandatory arguments ###
# Command to run
cmd=""

# Input: It can be a file, a domain or an ip
input=""

# Regular expression to highlight on command output
regex="(nothingToRECUADRERxXx)"

### Optional arguments ###

# Maximum threads to run, defaults to 5
max_threads=5

# Prepend this tring to file: for example -> xframetest-
prependtofile=""


while getopts ":c:h:r:t:O:" opt; do
  echo -e "[+] Optarg is ${OPTARG}"
  case $opt in
    c)
      cmd="$OPTARG"
      ;;
    h)
      input="$OPTARG"
      ;;
    r)
      regex="$OPTARG"
      ;;
    t)
      max_threads="$OPTARG"
      ;;
    O)
      prependtofile="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      show_help
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      show_help
      exit 1
      ;;
    esac
done

### End of program args ###


if [ -z "$cmd" ] ; then
  show_help
  exit
fi

for target in $(get_targets "$input"); do
  echo -e "[+] Target: $target"
  
  # Start the command in a background process
  main "$cmd" "$target" "$regex" "$prependtofile" &

  threads=$(($threads+1))
  if [[ "$threads" == "$max_threads" ]]; then
    print_yellow "Waiting for threads to finish"
    threads=0
	# Try to wait for all background processes to finish
    for thread in $(seq 0 $max_threads); do
      wait $!
    done
  fi
done

# Wait for orphaned processes?
for thread in $(seq 0 $max_threads); do
  wait $!
done

