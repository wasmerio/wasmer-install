#!/bin/sh

# This install script is intended to download and install the latest available
# release of Wasmer.
# It attempts to identify the current platform and an error will be thrown if
# the platform is not supported.
#
# Environment variables:
# - WASMER_DIR (optional): defaults to $HOME/.wasmer
#
# You can install using this script:
# $ curl https://raw.githubusercontent.com/wasmerio/wasmer-install/master/install.sh | sh

# Installer script inspired by:
#  1) https://raw.githubusercontent.com/golang/dep/master/install.sh
#  2) https://sh.rustup.rs
#  3) https://yarnpkg.com/install.sh
#  4) https://raw.githubusercontent.com/brainsik/virtualenv-burrito/master/virtualenv-burrito.sh

set -e

reset="\033[0m"
red="\033[31m"
green="\033[32m"
yellow="\033[33m"
white="\033[37m"
bold="\e[1m"
dim="\e[2m"

RELEASES_URL="https://github.com/wasmerio/wasmer/releases"

WASMER_VERBOSE="verbose"
if [ -z "$WASMER_INSTALL_LOG" ]; then
  WASMER_INSTALL_LOG="$WASMER_VERBOSE"
fi

wasmer_download_json() {
  url="$2"

  # echo "Fetching $url.."
  if test -x "$(command -v curl)"; then
    response=$(curl -s -L -w 'HTTPSTATUS:%{http_code}' -H 'Accept: application/json' "$url")
    body=$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')
    code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  elif test -x "$(command -v wget)"; then
    temp=$(mktemp)
    body=$(wget -q --header='Accept: application/json' -O - --server-response "$url" 2>"$temp")
    code=$(awk '/^  HTTP/{print $2}' <"$temp" | tail -1)
    rm "$temp"
  else
    wasmer_error "Neither curl nor wget was available to perform http requests"
  fi
  if [ "$code" != 200 ]; then
    wasmer_error "File download failed with code $code"
  fi

  eval "$1='$body'"
}

wasmer_download_file() {
  url="$1"
  destination="$2"

  # echo "Fetching $url.."
  if test -x "$(command -v curl)"; then
    if [ "$WASMER_INSTALL_LOG" = "$WASMER_VERBOSE" ]; then
      code=$(curl --progress-bar -w '%{http_code}' -L "$url" -o "$destination")
      printf "\033[K\n\033[1A"
    else
      code=$(curl -s -w '%{http_code}' -L "$url" -o "$destination")
    fi
  elif test -x "$(command -v wget)"; then
    if [ "$WASMER_INSTALL_LOG" = "$WASMER_VERBOSE" ]; then
      code=$(wget --show-progress --progress=bar:force:noscroll -q -O "$destination" --server-response "$url" 2>&1 | awk '/^  HTTP/{print $2}' | tail -1)
      printf "\033[K\n\033[1A"
    else
      code=$(wget --quiet -O "$destination" --server-response "$url" 2>&1 | awk '/^  HTTP/{print $2}' | tail -1)
    fi
  else
    wasmer_error "Neither curl nor wget was available to perform http requests."
  fi

  if [ "$code" = 404 ]; then
    wasmer_error "Your platform is not yet supported ($OS-$ARCH).$reset\nPlease open an issue on the project if you would like to use wasmer in your project: https://github.com/wasmerio/wasmer"
  elif [ "$code" != 200 ]; then
    wasmer_error "File download failed with code $code"
  fi
}

wasmer_detect_profile() {
  if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
    echo "${PROFILE}"
    return
  fi

  local DETECTED_PROFILE
  DETECTED_PROFILE=''
  local SHELLTYPE
  SHELLTYPE="$(basename "/$SHELL")"

  if [ "$SHELLTYPE" = "bash" ]; then
    if [ -f "$HOME/.bashrc" ]; then
      DETECTED_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      DETECTED_PROFILE="$HOME/.bash_profile"
    fi
  elif [ "$SHELLTYPE" = "zsh" ]; then
    DETECTED_PROFILE="$HOME/.zshrc"
  elif [ "$SHELLTYPE" = "fish" ]; then
    DETECTED_PROFILE="$HOME/.config/fish/config.fish"
  fi

  if [ -z "$DETECTED_PROFILE" ]; then
    if [ -f "$HOME/.profile" ]; then
      DETECTED_PROFILE="$HOME/.profile"
    elif [ -f "$HOME/.bashrc" ]; then
      DETECTED_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      DETECTED_PROFILE="$HOME/.bash_profile"
    elif [ -f "$HOME/.zshrc" ]; then
      DETECTED_PROFILE="$HOME/.zshrc"
    elif [ -f "$HOME/.config/fish/config.fish" ]; then
      DETECTED_PROFILE="$HOME/.config/fish/config.fish"
    fi
  fi

  if [ ! -z "$DETECTED_PROFILE" ]; then
    echo "$DETECTED_PROFILE"
  fi
}

wasmer_link() {

  WASMER_PROFILE="$(wasmer_detect_profile)"

  LOAD_STR="\n# Wasmer\nexport WASMER_DIR=\"$INSTALL_DIRECTORY\"\n[ -s \"\$WASMER_DIR/wasmer.sh\" ] && source \"\$WASMER_DIR/wasmer.sh\"\n"
  SOURCE_STR="# Wasmer config\nexport WASMER_DIR=\"$INSTALL_DIRECTORY\"\nexport WASMER_CACHE_DIR=\"\$WASMER_DIR/cache\"\nexport PATH=\"\$WASMER_DIR/bin:\$PATH:\$WASMER_DIR/globals/wapm_packages/.bin\"\n"

  # We create the wasmer.sh file
  printf "$SOURCE_STR" >"$INSTALL_DIRECTORY/wasmer.sh"

  if [ -z "${WASMER_PROFILE-}" ]; then
    wasmer_error "Profile not found. Tried:\n* ${WASMER_PROFILE} (as defined in \$PROFILE)\n* ~/.bashrc\n* ~/.bash_profile\n* ~/.zshrc\n* ~/.profile.\n${reset}Append the following lines to the correct file yourself:\n${SOURCE_STR}"
  else
    printf "Updating bash profile $WASMER_PROFILE\n"
    if ! grep -q 'wasmer.sh' "$WASMER_PROFILE"; then
      # if [[ $WASMER_PROFILE = *"fish"* ]]; then
      #   command fish -c 'set -U fish_user_paths $fish_user_paths ~/.wasmer/bin'
      # else
      command printf "$LOAD_STR" >>"$WASMER_PROFILE"
      # fi
      if [ "$WASMER_INSTALL_LOG" = "$WASMER_VERBOSE" ]; then
        printf "we've added the following to your $WASMER_PROFILE\n"
        echo "If you have a different profile please add the following:"
        printf "$dim$LOAD_STR$reset"
      fi
      wasmer_fresh_install=true
    else
      wasmer_warning "the profile already has Wasmer and has not been changed"
    fi

    version=$($INSTALL_DIRECTORY/bin/wasmer --version) || (
      wasmer_error "wasmer was installed, but doesn't seem to be working :("
    )

    wasmer_install_status "check" "$version installed succesfully ✓"

    if [ "$WASMER_INSTALL_LOG" = "$WASMER_VERBOSE" ]; then
      if [ "$wasmer_fresh_install" = true ]; then
        printf "wasmer & wapm will be available the next time you open the terminal.\n"
        printf "If you want to have the commands available now please execute:\n\nsource $INSTALL_DIRECTORY/wasmer.sh$reset\n"
      fi
    fi
  fi
}

initArch() {
  ARCH=$(uname -m)
  # If you modify this list, please also modify scripts/binary-name.sh
  case $ARCH in
  amd64) ARCH="amd64" ;;
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)
    wasmer_error "The system architecture (${ARCH}) is not supported by this installation script."
    ;;
  esac
  # echo "ARCH = $ARCH"
}

initOS() {
  OS=$(uname | tr '[:upper:]' '[:lower:]')
  case "$OS" in
  darwin) OS='darwin' ;;
  linux) OS='linux' ;;
  freebsd) OS='freebsd' ;;
  # mingw*) OS='windows';;
  # msys*) OS='windows';;
  *)
    printf "$red> The OS (${OS}) is not supported by this installation script.$reset\n"
    exit 1
    ;;
  esac
}

wasmer_install() {
  magenta1="${reset}\033[34;1m"
  magenta2=""
  magenta3=""

  if which wasmer >/dev/null; then
    printf "${reset}Welcome to the Wasmer bash installer!$reset\n"
  else
    printf "${reset}Welcome to the Wasmer bash installer!$reset\n"
    if [ "$WASMER_INSTALL_LOG" = "$WASMER_VERBOSE" ]; then
      printf "
${magenta1}               ww
${magenta1}               wwwww
${magenta1}        ww     wwwwww  w
${magenta1}        wwwww      wwwwwwwww
${magenta1}ww      wwwwww  w     wwwwwww
${magenta1}wwwww      wwwwwwwwww   wwwww
${magenta1}wwwwww  w      wwwwwww  wwwww
${magenta1}wwwwwwwwwwwwww   wwwww  wwwww
${magenta1}wwwwwwwwwwwwwww  wwwww  wwwww
${magenta1}wwwwwwwwwwwwwww  wwwww  wwwww
${magenta1}wwwwwwwwwwwwwww  wwwww  wwwww
${magenta1}wwwwwwwwwwwwwww  wwwww   wwww
${magenta1}wwwwwwwwwwwwwww  wwwww
${magenta1}   wwwwwwwwwwww   wwww
${magenta1}       wwwwwwww
${magenta1}           wwww
${reset}
"
    fi
  fi

  wasmer_download $1 # $2
  wasmer_link
  wasmer_reset
}

wasmer_reset() {
  unset -f wasmer_install semver_compare wasmer_reset wasmer_download_json wasmer_link wasmer_detect_profile wasmer_download_file wasmer_download wasmer_verify_or_quit
}

version() {
  echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}

semverParseInto() {
  local RE='([0-9]+)[.]([0-9]+)[.]([0-9]+)([.0-9A-Za-z-]*)'

  # # strip word "v" if exists
  # version=$(echo "${1//v/}")

  #MAJOR
  eval $2=$(echo $1 | sed -E "s#$RE#\1#")
  #MINOR
  eval $3=$(echo $1 | sed -E "s#$RE#\2#")
  #MINOR
  eval $4=$(echo $1 | sed -E "s#$RE#\3#")
  #SPECIAL
  eval $5=$(echo $1 | sed -E "s#$RE#\4#")
}

###
# Code inspired (copied partially and improved) with attributions from:
# https://github.com/cloudflare/semver_bash/blob/master/semver.sh
# https://gist.github.com/Ariel-Rodriguez/9e3c2163f4644d7a389759b224bfe7f3
###
semver_compare() {
  local version_a version_b

  local MAJOR_A=0
  local MINOR_A=0
  local PATCH_A=0
  local SPECIAL_A=0

  local MAJOR_B=0
  local MINOR_B=0
  local PATCH_B=0
  local SPECIAL_B=0

  semverParseInto $1 MAJOR_A MINOR_A PATCH_A SPECIAL_A
  semverParseInto $2 MAJOR_B MINOR_B PATCH_B SPECIAL_B

  # Extract first subset version (x.y.z from x.y.z-foo.n)
  version_a="$MAJOR_A$MINOR_A$PATCH_A"
  version_b="$MAJOR_B$MINOR_B$PATCH_B"

  if [ "$version_a" \= "$version_b" ]; then
    # check for pre-release
    ####
    # Return 0 when A is equal to B
    [ "$SPECIAL_A" \= "$SPECIAL_B" ] && echo 0 && return 0

    ####
    # Return 1

    # Case when A is not pre-release
    if [ -z "$SPECIAL_A" ]; then
      echo 1 && return 0
    fi

    ####
    # Case when pre-release A exists and is greater than B's pre-release

    # extract numbers -rc.x --> x
    number_a=$(echo ${SPECIAL_A//[!0-9]/})
    number_b=$(echo ${SPECIAL_B//[!0-9]/})
    [ -z "${number_a}" ] && number_a=0
    [ -z "${number_b}" ] && number_b=0

    [ "$SPECIAL_A" \> "$SPECIAL_B" ] && [ -n "$SPECIAL_B" ] && [ "$number_a" -gt "$number_b" ] && echo 1 && return 0

    ####
    # Retrun -1 when A is lower than B
    echo -1 && return 0
  fi

  if [ $MAJOR_A -lt $MAJOR_B ]; then
    echo -1 && return 0
  fi

  if [ $MAJOR_A -le $MAJOR_B ] && [ $MINOR_A -lt $MINOR_B ]; then
    echo -1 && return 0
  fi

  if [ $MAJOR_A -le $MAJOR_B ] && [ $MINOR_A -le $MINOR_B ] && [ $PATCH_A -lt $PATCH_B ]; then
    echo -1 && return 0
  fi

  if [ "_$SPECIAL_A" == "_" ] && [ "_$SPECIAL_B" == "_" ]; then
    echo 1 && return 0
  fi
  if [ "_$SPECIAL_A" == "_" ] && [ "_$SPECIAL_B" != "_" ]; then
    echo 1 && return 0
  fi
  if [ "_$SPECIAL_A" != "_" ] && [ "_$SPECIAL_B" == "_" ]; then
    echo -1 && return 0
  fi

  if [ "_$SPECIAL_A" -lt "_$SPECIAL_B" ]; then
    echo -1 && return 0
  fi

  echo 1
}

wasmer_download() {
  # identify platform based on uname output
  initArch
  initOS

  # assemble expected release artifact name
  BINARY="wasmer-${OS}-${ARCH}.tar.gz"

  # add .exe if on windows
  # if [ "$OS" = "windows" ]; then
  #     BINARY="$BINARY.exe"
  # fi

  wasmer_install_status "downloading" "wasmer-$OS-$ARCH"
  if [ $# -eq 0 ]; then
    # The version was not provided, assume latest
    wasmer_download_json LATEST_RELEASE "$RELEASES_URL/latest"
    WASMER_RELEASE_TAG=$(echo "${LATEST_RELEASE}" | tr -s '\n' ' ' | sed 's/.*"tag_name":"//' | sed 's/".*//')
    printf "Latest release: ${WASMER_RELEASE_TAG}\n"
  else
    WASMER_RELEASE_TAG="${1}"
    printf "Installing provided version: ${WASMER_RELEASE_TAG}\n"
  fi

  if which $INSTALL_DIRECTORY/bin/wasmer >/dev/null; then
    WASMER_VERSION=$($INSTALL_DIRECTORY/bin/wasmer --version | sed 's/wasmer //g')
    printf "Wasmer already installed in ${INSTALL_DIRECTORY} with version: ${WASMER_VERSION}\n"

    local MAJOR=0
    local MINOR=0
    local PATCH=0
    local SPECIAL=""

    semverParseInto $WASMER_VERSION MAJOR MINOR PATCH SPECIAL
    echo "$WASMER_VERSION -> M: $MAJOR m:$MINOR p:$PATCH s:$SPECIAL"

    semverParseInto $WASMER_RELEASE_TAG MAJOR MINOR PATCH SPECIAL
    echo "$WASMER_RELEASE_TAG -> M: $MAJOR m:$MINOR p:$PATCH s:$SPECIAL"

    WASMER_COMPARE=$(semver_compare $WASMER_VERSION $WASMER_RELEASE_TAG)
    printf "semver comparison: $WASMER_COMPARE\n"
    case $WASMER_COMPARE in
    # WASMER_VERSION = WASMER_RELEASE_TAG
    0)
      if [ $# -eq 0 ]; then
        wasmer_warning "wasmer is already installed in the latest version: ${WASMER_RELEASE_TAG}"
      else
        wasmer_warning "wasmer is already installed with the same version: ${WASMER_RELEASE_TAG}"
      fi
      printf "Do you want to force the installation?"
      wasmer_verify_or_quit
      ;;
      # WASMER_VERSION > WASMER_RELEASE_TAG
    1)
      wasmer_warning "the selected version (${WASMER_RELEASE_TAG}) is lower than current installed version ($WASMER_VERSION)"
      printf "Do you want to continue installing Wasmer $WASMER_RELEASE_TAG?"
      wasmer_verify_or_quit
      ;;
      # WASMER_VERSION < WASMER_RELEASE_TAG (we continue)
    -1) ;;
    esac
  fi

  # fetch the real release data to make sure it exists before we attempt a download
  wasmer_download_json RELEASE_DATA "$RELEASES_URL/tag/$WASMER_RELEASE_TAG"

  BINARY_URL="$RELEASES_URL/download/$WASMER_RELEASE_TAG/$BINARY"
  DOWNLOAD_FILE=$(mktemp -t wasmer.XXXXXXXXXX)

  printf "Downloading archive from ${BINARY_URL}\n"

  wasmer_download_file "$BINARY_URL" "$DOWNLOAD_FILE"
  # echo -en "\b\b"
  printf "\033[K\n\033[1A"

  # windows not supported yet
  # if [ "$OS" = "windows" ]; then
  #     INSTALL_NAME="$INSTALL_NAME.exe"
  # fi

  # echo "Moving executable to $INSTALL_DIRECTORY/$INSTALL_NAME"

  wasmer_install_status "installing" "${INSTALL_DIRECTORY}"

  mkdir -p $INSTALL_DIRECTORY

  # Untar the wasmer contents in the install directory
  tar -C $INSTALL_DIRECTORY -zxf $DOWNLOAD_FILE
}

wasmer_error() {
  printf "$bold${red}error${white}: $1${reset}\n"
  exit 1
}

wasmer_install_status() {
  printf "$bold${green}${1}${white}: $2${reset}\n"
}

wasmer_warning() {
  printf "$bold${yellow}warning${white}: $1${reset}\n"
}

wasmer_verify_or_quit() {
  if [ -n "$BASH_VERSION" ]; then
    # If we are in bash, we can use read -n
    read -p "$1 [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      wasmer_error "installation aborted"
    fi
    return 0
  fi

  read -p "$1 [y/N]" yn
  case $yn in
  [Yy]*) break ;;
  [Nn]*) wasmer_error "installation aborted" ;;
  *) echo "Please answer yes or no." ;;
  esac

  return
}

# determine install directory if required
if [ -z "$WASMER_DIR" ]; then
  # If WASMER_DIR is not present
  INSTALL_DIRECTORY="$HOME/.wasmer"
else
  # If WASMER_DIR is present
  INSTALL_DIRECTORY="${WASMER_DIR}"
fi

wasmer_install $1 # $2
