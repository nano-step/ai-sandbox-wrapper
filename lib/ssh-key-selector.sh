#!/usr/bin/env bash
# SSH Key Selector Library
# Provides interactive multi-select for SSH keys with search capability

# Multi-select SSH keys
# Usage: select_ssh_keys
# Returns: SELECTED_SSH_KEYS array
select_ssh_keys() {
  local ssh_dir="$HOME/.ssh"
  local title="🔑 Select SSH Keys to Allow"

  # Analyze git remotes to recommend keys
  local -a recommended_keys=()
  if [ -f ".git/config" ]; then
    # Extract SSH URLs from git config
    local git_hosts
    git_hosts=$(grep -E "url.*@" .git/config 2>/dev/null | sed -E 's/.*@([^:]+).*/\1/' | sort -u)

    # Look for keys matching these hosts in SSH config
    if [ -f "$ssh_dir/config" ]; then
      for host in $git_hosts; do
        # Find IdentityFile entries for this host
        local keys
        keys=$(awk -v host="$host" '
          /^Host / { current_host=$2 }
          current_host ~ host && /IdentityFile/ {
            gsub(/^~\/\.ssh\//, "", $2)
            print $2
          }
        ' "$ssh_dir/config" 2>/dev/null)

        for key in $keys; do
          [[ -f "$ssh_dir/$key" ]] && recommended_keys+=("$key")
        done
      done
    fi
  fi

  # Find all private key files (including in subdirectories)
  local -a key_files=()
  local file_list
  file_list=$(cd "$ssh_dir" && find . -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "config" 2>/dev/null | sed 's|^\./||' | sort)

  while IFS= read -r file; do
    # Skip if it's a public key, known_hosts, config
    [[ "$file" == *.pub ]] && continue
    [[ "$file" == *"known_hosts"* ]] && continue
    [[ "$file" == *"config"* ]] && continue
    [[ "$file" == *"/"*.pub ]] && continue
    [[ -z "$file" ]] && continue
    key_files+=("$file")
  done <<< "$file_list"

  if [ ${#key_files[@]} -eq 0 ]; then
    echo "No SSH keys found in $ssh_dir"
    SELECTED_SSH_KEYS=()
    return 1
  fi

  # Sort: recommended keys first, then alphabetically
  local -a sorted_keys=()
  local -a is_recommended=()

  # Add recommended keys first
  for key in "${recommended_keys[@]}"; do
    for i in "${!key_files[@]}"; do
      if [[ "${key_files[$i]}" == "$key" ]]; then
        sorted_keys+=("${key_files[$i]}")
        is_recommended+=(1)
        unset 'key_files[i]'
        break
      fi
    done
  done

  # Add remaining keys
  for key in "${key_files[@]}"; do
    [[ -n "$key" ]] && sorted_keys+=("$key") && is_recommended+=(0)
  done

  key_files=("${sorted_keys[@]}")

  # Interactive multi-select
  local cursor=0
  local -a selected=()

  # Initialize selected array to match key_files length
  for ((i=0; i<${#key_files[@]}; i++)); do
    selected[$i]=0
  done

  tput civis # Hide cursor

  while true; do
    clear
    echo "$title"
    echo "Found ${#key_files[@]} keys (${#recommended_keys[@]} recommended for this repo)"
    echo "Use ARROWS to move, SPACE to toggle, ENTER to confirm"
    echo "Press / to search, A to select all recommended"
    echo ""

    for i in "${!key_files[@]}"; do
      local prefix="   "
      if [ "$i" -eq "$cursor" ]; then
        prefix="➔  "
      fi

      local checkbox="[ ]"
      if [ "${selected[$i]}" -eq 1 ]; then
        checkbox="[x]"
      fi

      local marker=""
      if [ "${is_recommended[$i]}" -eq 1 ]; then
        marker="⭐ "
      fi

      echo "$prefix$checkbox $marker${key_files[$i]}"
    done

    # Read single key
    IFS= read -rsn1 key

    # Handle escape sequences (arrow keys)
    if [[ "$key" == $'\x1b' ]]; then
      read -rsn1 -t 1 next1
      read -rsn1 -t 1 next2
      case "$next1$next2" in
        '[A') # Up arrow
          ((cursor--)) || true
          ;;
        '[B') # Down arrow
          ((cursor++)) || true
          ;;
      esac
    # Handle regular keys
    else
      case "$key" in
        ' ') # Space - toggle selection
          if [ "${selected[$cursor]}" -eq 0 ]; then
            selected[$cursor]=1
          else
            selected[$cursor]=0
          fi
          ;;
        '') # Enter - confirm
          break
          ;;
        'A'|'a') # Select all recommended
          for i in "${!key_files[@]}"; do
            if [ "${is_recommended[$i]}" -eq 1 ]; then
              selected[$i]=1
            fi
          done
          ;;
        '/') # Search (case-insensitive)
          tput cnorm
          echo ""
          read -p "Search (case-insensitive): " search_term
          tput civis
          # Find first match
          for i in "${!key_files[@]}"; do
            if [[ "${key_files[$i],,}" == *"${search_term,,}"* ]]; then
              cursor=$i
              break
            fi
          done
          ;;
      esac
    fi

    # Keep cursor in bounds
    if [ "$cursor" -lt 0 ]; then cursor=$((${#key_files[@]} - 1)); fi
    if [ "$cursor" -ge "${#key_files[@]}" ]; then cursor=0; fi
  done

  tput cnorm # Show cursor
  clear

  # Prepare result
  SELECTED_SSH_KEYS=()
  for i in "${!key_files[@]}"; do
    if [ "${selected[$i]}" -eq 1 ]; then
      SELECTED_SSH_KEYS+=("${key_files[$i]}")
    fi
  done

  return 0
}
