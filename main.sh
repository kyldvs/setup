#!/bin/bash

# We don't need return codes for "$(command)", only stdout is needed.
# Allow `[[ -n "$(command)" ]]`, `func "$(command)"`, pipes, etc.
# shellcheck disable=SC2312

set -u

abort() {
  printf "%s\n" "$@" >&2
  exit 1
}

# Fail fast with a concise message when not using bash
# Single brackets are needed here for POSIX compatibility
# shellcheck disable=SC2292
if [ -z "${BASH_VERSION:-}" ]
then
  abort "Bash is required to interpret this script."
fi

# Check if script is run with force-interactive mode in CI
if [[ -n "${CI-}" && -n "${INTERACTIVE-}" ]]
then
  abort "Cannot run force-interactive mode in CI."
fi

# Check if both `INTERACTIVE` and `NONINTERACTIVE` are set
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -n "${INTERACTIVE-}" && -n "${NONINTERACTIVE-}" ]]
then
  abort 'Both `$INTERACTIVE` and `$NONINTERACTIVE` are set. Please unset at least one variable and try again.'
fi

# string formatters
if [[ -t 1 ]]
then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"
  do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

chomp() {
  printf "%s" "${1/"$'\n'"/}"
}

ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

warn() {
  printf "${tty_red}Warning${tty_reset}: %s\n" "$(chomp "$1")" >&2
}

usage() {
  cat <<EOS
Setup
Usage: [NONINTERACTIVE=1] [CI=1] main.sh [options]
    -h, --help       Display this message.
    NONINTERACTIVE   Install without prompting for user input
    CI               Install in CI mode (e.g. do not prompt for user input)
EOS
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]
do
  case "$1" in
    -h | --help) usage ;;
    *)
      warn "Unrecognized option: '$1'"
      usage 1
      ;;
  esac
done

# USER isn't always set so provide a fall back for the installer and subprocesses.
if [[ -z "${USER-}" ]]
then
  USER="$(chomp "$(id -un)")"
  export USER
fi

# First check OS.
OS="$(uname)"
if [[ "${OS}" == "Linux" ]]
then
  KYLDVS_ON_LINUX=1
elif [[ "${OS}" == "Darwin" ]]
then
  KYLDVS_ON_MACOS=1
else
  abort "Setup is only supported on macOS and Linux."
fi

# Required installation paths.
if [[ -n "${KYLDVS_ON_MACOS-}" ]]
then
  UNAME_MACHINE="$(/usr/bin/uname -m)"

  # Install to /usr/local/kyldvs/setup
  KYLDVS_PREFIX="/usr/local/kyldvs/setup"
  KYLDVS_REPOSITORY="${KYLDVS_PREFIX}"

  # Define platform-specific commands and paths.
  STAT_PRINTF=("/usr/bin/stat" "-f")
  PERMISSION_FORMAT="%A"
  CHOWN=("/usr/sbin/chown")
  CHGRP=("/usr/bin/chgrp")
  GROUP="admin"
  TOUCH=("/usr/bin/touch")
  INSTALL=("/usr/bin/install" -d -o "root" -g "wheel" -m "0755")
else
  UNAME_MACHINE="$(uname -m)"

  # On Linux, this script installs to /home/kyldvs/setup only.
  KYLDVS_PREFIX="/home/kyldvs/setup"
  KYLDVS_REPOSITORY="${KYLDVS_PREFIX}"

  # Define platform-specific commands and paths.
  STAT_PRINTF=("/usr/bin/stat" "-c")
  PERMISSION_FORMAT="%a"
  CHOWN=("/bin/chown")
  CHGRP=("/bin/chgrp")
  GROUP="$(id -gn)"
  TOUCH=("/bin/touch")
  INSTALL=("/usr/bin/install" -d -o "${USER}" -g "${GROUP}" -m "0755")
fi
CHMOD=("/bin/chmod")
MKDIR=("/bin/mkdir" "-p")

KYLDVS_SETUP_GIT_REMOTE="https://github.com/kyldvs/setup"
# TODO: not sure if we'll use this.
KYLDVS_DOTFILES_GIT_REMOTE="https://github.com/kyldvs/dotfiles"

# TODO: bump version when new macOS is released or announced
MACOS_NEWEST_UNSUPPORTED="27.0"
# TODO: bump version when new macOS is released
MACOS_OLDEST_SUPPORTED="14.0"
REQUIRED_CURL_VERSION=7.41.0
REQUIRED_GIT_VERSION=2.7.0

# Unset this from the environment
unset HAVE_SUDO_ACCESS

have_sudo_access() {
  if [[ ! -x "/usr/bin/sudo" ]]
  then
    return 1
  fi

  local -a SUDO=("/usr/bin/sudo")
  if [[ -n "${SUDO_ASKPASS-}" ]]
  then
    SUDO+=("-A")
  elif [[ -n "${NONINTERACTIVE-}" ]]
  then
    SUDO+=("-n")
  fi

  if [[ -z "${HAVE_SUDO_ACCESS-}" ]]
  then
    if [[ -n "${NONINTERACTIVE-}" ]]
    then
      "${SUDO[@]}" -l mkdir &>/dev/null
    else
      "${SUDO[@]}" -v && "${SUDO[@]}" -l mkdir &>/dev/null
    fi
    HAVE_SUDO_ACCESS="$?"
  fi

  if [[ -n "${KYLDVS_ON_MACOS-}" ]] && [[ "${HAVE_SUDO_ACCESS}" -ne 0 ]]
  then
    abort "Need sudo access on macOS (e.g. the user ${USER} needs to be an Administrator)!"
  fi

  return "${HAVE_SUDO_ACCESS}"
}

execute() {
  if ! "$@"
  then
    abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
  fi
}

retry() {
  local tries="$1" n="$1" pause=2
  shift
  if ! "$@"
  then
    while [[ $((--n)) -gt 0 ]]
    do
      warn "$(printf "Trying again in %d seconds: %s" "${pause}" "$(shell_join "$@")")"
      sleep "${pause}"
      ((pause *= 2))
      if "$@"
      then
        return
      fi
    done
    abort "$(printf "Failed %d times doing: %s" "${tries}" "$(shell_join "$@")")"
  fi
}

execute_sudo() {
  local -a args=("$@")
  if [[ "${EUID:-${UID}}" != "0" ]] && have_sudo_access
  then
    if [[ -n "${SUDO_ASKPASS-}" ]]
    then
      args=("-A" "${args[@]}")
    fi
    ohai "/usr/bin/sudo" "${args[@]}"
    execute "/usr/bin/sudo" "${args[@]}"
  else
    ohai "${args[@]}"
    execute "${args[@]}"
  fi
}

getc() {
  local save_state
  save_state="$(/bin/stty -g)"
  /bin/stty raw -echo
  IFS='' read -r -n 1 -d '' "$@"
  /bin/stty "${save_state}"
}

ring_bell() {
  # Use the shell's audible bell.
  if [[ -t 1 ]]
  then
    printf "\a"
  fi
}

wait_for_user() {
  local c
  echo
  echo "Press ${tty_bold}RETURN${tty_reset}/${tty_bold}ENTER${tty_reset} to continue or any other key to abort:"
  getc c
  # we test for \r and \n because some stuff does \r instead
  if ! [[ "${c}" == $'\r' || "${c}" == $'\n' ]]
  then
    exit 1
  fi
}

major_minor() {
  echo "${1%%.*}.$(
    x="${1#*.}"
    echo "${x%%.*}"
  )"
}

version_gt() {
  [[ "${1%.*}" -gt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -gt "${2#*.}" ]]
}
version_ge() {
  [[ "${1%.*}" -gt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -ge "${2#*.}" ]]
}
version_lt() {
  [[ "${1%.*}" -lt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -lt "${2#*.}" ]]
}

check_run_command_as_root() {
  [[ "${EUID:-${UID}}" == "0" ]] || return

  # Allow Azure Pipelines/GitHub Actions/Docker/Concourse/Kubernetes to do everything as root (as it's normal there)
  [[ -f /.dockerenv ]] && return
  [[ -f /run/.containerenv ]] && return
  [[ -f /proc/1/cgroup ]] && grep -E "azpl_job|actions_job|docker|garden|kubepods" -q /proc/1/cgroup && return

  abort "Don't run this as root!"
}

should_install_command_line_tools() {
  if [[ -n "${KYLDVS_ON_LINUX-}" ]]
  then
    return 1
  fi

  if version_gt "${macos_version}" "10.13"
  then
    ! [[ -e "/Library/Developer/CommandLineTools/usr/bin/git" ]]
  else
    ! [[ -e "/Library/Developer/CommandLineTools/usr/bin/git" ]] ||
      ! [[ -e "/usr/include/iconv.h" ]]
  fi
}

get_permission() {
  "${STAT_PRINTF[@]}" "${PERMISSION_FORMAT}" "$1"
}

user_only_chmod() {
  [[ -d "$1" ]] && [[ "$(get_permission "$1")" != 75[0145] ]]
}

exists_but_not_writable() {
  [[ -e "$1" ]] && ! [[ -r "$1" && -w "$1" && -x "$1" ]]
}

get_owner() {
  "${STAT_PRINTF[@]}" "%u" "$1"
}

file_not_owned() {
  [[ "$(get_owner "$1")" != "$(id -u)" ]]
}

get_group() {
  "${STAT_PRINTF[@]}" "%g" "$1"
}

file_not_grpowned() {
  [[ " $(id -G "${USER}") " != *" $(get_group "$1") "* ]]
}

test_curl() {
  if [[ ! -x "$1" ]]
  then
    return 1
  fi

  if [[ "$1" == "/snap/bin/curl" ]]
  then
    warn "Ignoring $1 (curl snap is too restricted)"
    return 1
  fi

  local curl_version_output curl_name_and_version
  curl_version_output="$("$1" --version 2>/dev/null)"
  curl_name_and_version="${curl_version_output%% (*}"
  version_ge "$(major_minor "${curl_name_and_version##* }")" "$(major_minor "${REQUIRED_CURL_VERSION}")"
}

test_git() {
  if [[ ! -x "$1" ]]
  then
    return 1
  fi

  local git_version_output
  git_version_output="$("$1" --version 2>/dev/null)"
  if [[ "${git_version_output}" =~ "git version "([^ ]*).* ]]
  then
    version_ge "$(major_minor "${BASH_REMATCH[1]}")" "$(major_minor "${REQUIRED_GIT_VERSION}")"
  else
    abort "Unexpected Git version: '${git_version_output}'!"
  fi
}

# Search for the given executable in PATH (avoids a dependency on the `which` command)
which() {
  # Alias to Bash built-in command `type -P`
  type -P "$@"
}

# Search PATH for the specified program that satisfies Kyldvs requirements
# function which is set above
# shellcheck disable=SC2230
find_tool() {
  if [[ $# -ne 1 ]]
  then
    return 1
  fi

  local executable
  while read -r executable
  do
    if [[ "${executable}" != /* ]]
    then
      warn "Ignoring ${executable} (relative paths don't work)"
    elif "test_$1" "${executable}"
    then
      echo "${executable}"
      break
    fi
  done < <(which -a "$1")
}

# Usage: macos_ensure_defaults_string "com.apple.dock" "orientation" "left"
macos_ensure_defaults_string() {
  # Validate that all 3 parameters were provided
  if [[ $# -ne 3 ]]; then
    abort "macos_ensure_defaults_string requires 3 parameters: domain, key, value"
  fi

  local domain="$1"
  local key="$2"
  local value="$3"

  # Get current value (redirect stderr to avoid error if key doesn't exist)
  local current_value
  current_value=$(defaults read "$domain" "$key" 2>/dev/null)

  # Check if the current value matches the desired value
  if [[ "$current_value" != "$value" ]]; then
    # Set the value and echo message
    ohai "Setting $domain $key to '$value'"
    defaults write "$domain" "$key" -string "$value"
  fi
}

# Invalidate sudo timestamp before exiting (if it wasn't active before).
if [[ -x /usr/bin/sudo ]] && ! /usr/bin/sudo -n -v 2>/dev/null
then
  trap '/usr/bin/sudo -k' EXIT
fi

# Things can fail later if `pwd` doesn't exist.
# Also sudo prints a warning message for no good reason
cd "/usr" || exit 1

# =============================================================================
# Script Start
# =============================================================================

# shellcheck disable=SC2016
ohai 'Checking for `sudo` access (which may request your password)...'

if [[ -n "${KYLDVS_ON_MACOS-}" ]]
then
  [[ "${EUID:-${UID}}" == "0" ]] || have_sudo_access
elif ! [[ -w "${KYLDVS_PREFIX}" ]] &&
     ! [[ -w "/home/kyldvs" ]] &&
     ! [[ -w "/home" ]] &&
     ! have_sudo_access
then
  abort "$(
    cat <<EOABORT
Insufficient permissions to Setup at "${KYLDVS_PREFIX}" (the default prefix).
EOABORT
  )"
fi

check_run_command_as_root

if [[ -d "${KYLDVS_PREFIX}" && ! -x "${KYLDVS_PREFIX}" ]]
then
  abort "$(
    cat <<EOABORT
The prefix ${tty_underline}${KYLDVS_PREFIX}${tty_reset} exists but is not searchable.
If this is not intentional, please restore the default permissions and
try running the installer again:
    sudo chmod 775 ${KYLDVS_PREFIX}
EOABORT
  )"
fi

if [[ -n "${KYLDVS_ON_MACOS-}" ]]
then
  # On macOS, support 64-bit Intel and ARM
  if [[ "${UNAME_MACHINE}" != "arm64" ]] && [[ "${UNAME_MACHINE}" != "x86_64" ]]
  then
    abort "Setup is only supported on Intel and ARM processors!"
  fi
else
  if [[ "${UNAME_MACHINE}" != "x86_64" ]] && [[ "${UNAME_MACHINE}" != "aarch64" ]]
  then
    abort "Setup on Linux is only supported on Intel x86_64 and ARM64 processors!"
  fi
fi

if [[ -n "${KYLDVS_ON_MACOS-}" ]]
then
  macos_version="$(major_minor "$(/usr/bin/sw_vers -productVersion)")"
  if version_lt "${macos_version}" "10.7"
  then
    abort "$(
      cat <<EOABORT
Your Mac OS X version is too old. See:
  ${tty_underline}https://github.com/mistydemeo/tigerbrew${tty_reset}
EOABORT
    )"
  elif version_lt "${macos_version}" "10.11"
  then
    abort "Your OS X version is too old."
  elif version_ge "${macos_version}" "${MACOS_NEWEST_UNSUPPORTED}" ||
       version_lt "${macos_version}" "${MACOS_OLDEST_SUPPORTED}"
  then
    who="We"
    what=""
    if version_ge "${macos_version}" "${MACOS_NEWEST_UNSUPPORTED}"
    then
      what="pre-release version"
    else
      who+=" (and Apple)"
      what="old version"
    fi
    ohai "You are using macOS ${macos_version}."
    ohai "${who} do not provide support for this ${what}."

    echo "$(
      cat <<EOS
This installation may not succeed. You are responsible for resolving any
issues you experience while you are running this ${what}.
EOS
    )
" | tr -d "\\"
  fi
fi

directories=(
  bin lib
)
group_chmods=()
for dir in "${directories[@]}"
do
  if exists_but_not_writable "${KYLDVS_PREFIX}/${dir}"
  then
    group_chmods+=("${KYLDVS_PREFIX}/${dir}")
  fi
done

# zsh refuses to read from these directories if group writable
directories=(share/zsh share/zsh/site-functions)
zsh_dirs=()
for dir in "${directories[@]}"
do
  zsh_dirs+=("${KYLDVS_PREFIX}/${dir}")
done

directories=(
  bin lib
  share/zsh share/zsh/site-functions
)
mkdirs=()
for dir in "${directories[@]}"
do
  if ! [[ -d "${KYLDVS_PREFIX}/${dir}" ]]
  then
    mkdirs+=("${KYLDVS_PREFIX}/${dir}")
  fi
done

user_chmods=()
mkdirs_user_only=()
if [[ "${#zsh_dirs[@]}" -gt 0 ]]
then
  for dir in "${zsh_dirs[@]}"
  do
    if [[ ! -d "${dir}" ]]
    then
      mkdirs_user_only+=("${dir}")
    elif user_only_chmod "${dir}"
    then
      user_chmods+=("${dir}")
    fi
  done
fi

chmods=()
if [[ "${#group_chmods[@]}" -gt 0 ]]
then
  chmods+=("${group_chmods[@]}")
fi
if [[ "${#user_chmods[@]}" -gt 0 ]]
then
  chmods+=("${user_chmods[@]}")
fi

chowns=()
chgrps=()
if [[ "${#chmods[@]}" -gt 0 ]]
then
  for dir in "${chmods[@]}"
  do
    if file_not_owned "${dir}"
    then
      chowns+=("${dir}")
    fi
    if file_not_grpowned "${dir}"
    then
      chgrps+=("${dir}")
    fi
  done
fi

if [[ "${#group_chmods[@]}" -gt 0 ]]
then
  ohai "The following existing directories will be made group writable:"
  printf "%s\n" "${group_chmods[@]}"
fi
if [[ "${#user_chmods[@]}" -gt 0 ]]
then
  ohai "The following existing directories will be made writable by user only:"
  printf "%s\n" "${user_chmods[@]}"
fi
if [[ "${#chowns[@]}" -gt 0 ]]
then
  ohai "The following existing directories will have their owner set to ${tty_underline}${USER}${tty_reset}:"
  printf "%s\n" "${chowns[@]}"
fi
if [[ "${#chgrps[@]}" -gt 0 ]]
then
  ohai "The following existing directories will have their group set to ${tty_underline}${GROUP}${tty_reset}:"
  printf "%s\n" "${chgrps[@]}"
fi
if [[ "${#mkdirs[@]}" -gt 0 ]]
then
  ohai "The following new directories will be created:"
  printf "%s\n" "${mkdirs[@]}"
fi

if should_install_command_line_tools
then
  ohai "The Xcode Command Line Tools will be installed."
fi

if [[ -z "${NONINTERACTIVE-}" ]]
then
  ring_bell
  wait_for_user
fi

if [[ -d "${KYLDVS_PREFIX}" ]]
then
  if [[ "${#chmods[@]}" -gt 0 ]]
  then
    execute_sudo "${CHMOD[@]}" "u+rwx" "${chmods[@]}"
  fi
  if [[ "${#group_chmods[@]}" -gt 0 ]]
  then
    execute_sudo "${CHMOD[@]}" "g+rwx" "${group_chmods[@]}"
  fi
  if [[ "${#user_chmods[@]}" -gt 0 ]]
  then
    execute_sudo "${CHMOD[@]}" "go-w" "${user_chmods[@]}"
  fi
  if [[ "${#chowns[@]}" -gt 0 ]]
  then
    execute_sudo "${CHOWN[@]}" "${USER}" "${chowns[@]}"
  fi
  if [[ "${#chgrps[@]}" -gt 0 ]]
  then
    execute_sudo "${CHGRP[@]}" "${GROUP}" "${chgrps[@]}"
  fi
else
  execute_sudo "${INSTALL[@]}" "${KYLDVS_PREFIX}"
fi

if [[ "${#mkdirs[@]}" -gt 0 ]]
then
  execute_sudo "${MKDIR[@]}" "${mkdirs[@]}"
  execute_sudo "${CHMOD[@]}" "ug=rwx" "${mkdirs[@]}"
  if [[ "${#mkdirs_user_only[@]}" -gt 0 ]]
  then
    execute_sudo "${CHMOD[@]}" "go-w" "${mkdirs_user_only[@]}"
  fi
  execute_sudo "${CHOWN[@]}" "${USER}" "${mkdirs[@]}"
  execute_sudo "${CHGRP[@]}" "${GROUP}" "${mkdirs[@]}"
fi

if ! [[ -d "${KYLDVS_REPOSITORY}" ]]
then
  execute_sudo "${MKDIR[@]}" "${KYLDVS_REPOSITORY}"
fi
execute_sudo "${CHOWN[@]}" "-R" "${USER}:${GROUP}" "${KYLDVS_REPOSITORY}"

if should_install_command_line_tools && version_ge "${macos_version}" "10.13"
then
  ohai "Searching online for the Command Line Tools"
  # This temporary file prompts the 'softwareupdate' utility to list the Command Line Tools
  clt_placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  execute_sudo "${TOUCH[@]}" "${clt_placeholder}"

  clt_label_command="/usr/sbin/softwareupdate -l |
                      grep -B 1 -E 'Command Line Tools' |
                      awk -F'*' '/^ *\\*/ {print \$2}' |
                      sed -e 's/^ *Label: //' -e 's/^ *//' |
                      sort -V |
                      tail -n1"
  clt_label="$(chomp "$(/bin/bash -c "${clt_label_command}")")"

  if [[ -n "${clt_label}" ]]
  then
    ohai "Installing ${clt_label}"
    execute_sudo "/usr/sbin/softwareupdate" "-i" "${clt_label}"
    execute_sudo "/usr/bin/xcode-select" "--switch" "/Library/Developer/CommandLineTools"
  fi
  execute_sudo "/bin/rm" "-f" "${clt_placeholder}"
fi

# Headless install may have failed, so fallback to original 'xcode-select' method
if should_install_command_line_tools && test -t 0
then
  ohai "Installing the Command Line Tools (expect a GUI popup):"
  execute "/usr/bin/xcode-select" "--install"
  echo "Press any key when the installation has completed."
  getc
  execute_sudo "/usr/bin/xcode-select" "--switch" "/Library/Developer/CommandLineTools"
fi

if [[ -n "${KYLDVS_ON_MACOS-}" ]] && ! output="$(/usr/bin/xcrun clang 2>&1)" && [[ "${output}" == *"license"* ]]
then
  abort "$(
    cat <<EOABORT
You have not agreed to the Xcode license.
Before running the installer again please agree to the license by opening
Xcode.app or running:
    sudo xcodebuild -license
EOABORT
  )"
fi

USABLE_GIT=/usr/bin/git
if [[ -n "${KYLDVS_ON_LINUX-}" ]]
then
  USABLE_GIT="$(find_tool git)"
  if [[ -z "$(command -v git)" ]]
  then
    abort "$(
      cat <<EOABORT
  You must install Git before setting up.
EOABORT
    )"
  fi
  if [[ -z "${USABLE_GIT}" ]]
  then
    abort "$(
      cat <<EOABORT
  The version of Git that was found does not satisfy requirements for Setup.
  Please install Git ${REQUIRED_GIT_VERSION} or newer and add it to your PATH.
EOABORT
    )"
  fi
  if [[ "${USABLE_GIT}" != /usr/bin/git ]]
  then
    export KYLDVS_GIT_PATH="${USABLE_GIT}"
    ohai "Found Git: ${KYLDVS_GIT_PATH}"
  fi
fi

if ! command -v curl >/dev/null
then
  abort "$(
    cat <<EOABORT
You must install cURL before setting up.
EOABORT
  )"
elif [[ -n "${KYLDVS_ON_LINUX-}" ]]
then
  USABLE_CURL="$(find_tool curl)"
  if [[ -z "${USABLE_CURL}" ]]
  then
    abort "$(
      cat <<EOABORT
The version of cURL that was found does not satisfy requirements for Homebrew.
Please install cURL ${REQUIRED_CURL_VERSION} or newer and add it to your PATH.
EOABORT
    )"
  elif [[ "${USABLE_CURL}" != /usr/bin/curl ]]
  then
    export KYLDVS_CURL_PATH="${USABLE_CURL}"
    ohai "Found cURL: ${KYLDVS_CURL_PATH}"
  fi
fi

# TODO: Linux support.
if [[ -n "${KYLDVS_ON_MACOS-}" ]]
then
  echo
  ohai "Setting up machine..."
else
  echo
  abort "Linux not yet supported."
fi

# =============================================================================
# Setup Start
# =============================================================================

(
  cd "${KYLDVS_REPOSITORY}" >/dev/null || return

  # we do it in four steps to avoid merge errors when reinstalling
  execute "${USABLE_GIT}" "-c" "init.defaultBranch=main" "init" "--quiet"

  # "git remote add" will fail if the remote is defined in the global config
  execute "${USABLE_GIT}" "config" "remote.origin.url" "${KYLDVS_SETUP_GIT_REMOTE}"
  execute "${USABLE_GIT}" "config" "remote.origin.fetch" "+refs/heads/*:refs/remotes/origin/*"
  execute "${USABLE_GIT}" "config" "--bool" "fetch.prune" "true"

  # ensure we don't munge line endings on checkout
  execute "${USABLE_GIT}" "config" "--bool" "core.autocrlf" "false"

  # make sure symlinks are saved as-is
  execute "${USABLE_GIT}" "config" "--bool" "core.symlinks" "true"

  if [[ -z "${NONINTERACTIVE-}" ]]
  then
    quiet_progress=("--quiet" "--progress")
  else
    quiet_progress=("--quiet")
  fi
  retry 5 "${USABLE_GIT}" "fetch" "${quiet_progress[@]}" "--force" "origin"
  retry 5 "${USABLE_GIT}" "fetch" "${quiet_progress[@]}" "--force" "--tags" "origin"

  execute "${USABLE_GIT}" "remote" "set-head" "origin" "--auto" >/dev/null

  # TODO: Verify if this works.
  execute "${USABLE_GIT}" "checkout" "--quiet" "--force" "-B" "main" "main"

  # ===========================================================================
  # Mac Settings via Defaults
  # ===========================================================================

  macos_ensure_defaults_string "com.apple.dock" "orientation" "left"

  # Restart the dock to apply. (TODO: Prompt user?)
  killall Dock

) || exit 1

ohai "Installation successful!"
echo

# Homebrew pre-requisites.
# TODO: Install git.
# TODO: Install curl.

ohai "Next steps:"
case "${SHELL}" in
  */bash*)
    if [[ -n "${KYLDVS_ON_LINUX-}" ]]
    then
      shell_rcfile="${HOME}/.bashrc"
    else
      shell_rcfile="${HOME}/.bash_profile"
    fi
    ;;
  */zsh*)
    if [[ -n "${KYLDVS_ON_LINUX-}" ]]
    then
      shell_rcfile="${ZDOTDIR:-"${HOME}"}/.zshrc"
    else
      shell_rcfile="${ZDOTDIR:-"${HOME}"}/.zprofile"
    fi
    ;;
  */fish*)
    shell_rcfile="${HOME}/.config/fish/config.fish"
    ;;
  *)
    shell_rcfile="${ENV:-"${HOME}/.profile"}"
    ;;
esac

cat <<EOS
- Run this command in your terminal to setup your ${tty_bold}PATH${tty_reset}:
    (todo - figure out a setup command)
EOS
