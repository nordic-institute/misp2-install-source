##
# Tab-complete for build.sh script
##
function _build { 
  # Pointer to current completion word
  # COMP_WORDS associative array and COMP_CWORD key weremade available by bash
  local cur=${COMP_WORDS[COMP_CWORD]}
  local options='-nogit -nobuild -nosign -nodebian xenial bionic postgresql base orbeon application'

  # filter out options that have been already entered
  local filtered="$(echo "$options" | sed -e 's/ /\n/g')"
  for i in "${!COMP_WORDS[@]}"
  do
      local filtered="$(echo "$filtered" | grep -xv -- "${COMP_WORDS[$i]}")"
  done

  # Load available options into the following array
  COMPREPLY=( $(compgen -W "$filtered" -- $cur) )

  return 0
}
complete -F _build -o filenames build.sh

