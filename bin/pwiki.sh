#!/bin/bash

PROJECT_NAME=docker-web-wiki

# =================================================================
# 宣告函數

openURL() {
  url="$1"
  echo "${url}"

  if command -v xdg-open &> /dev/null; then
    xdg-open "${url}" &
  elif command -v open &> /dev/null; then
    open "${url}" &
  fi
}

# ------------------
# 確認環境

if ! command -v git &> /dev/null
then
  echo "git could not be found"

  openURL https://git-scm.com/downloads &

  exit
fi

if ! command -v docker-compose &> /dev/null
then
  echo "docker-compose could not be found"

  openURL https://docs.docker.com/compose/install/ &

  exit
fi

# ---------------
# 安裝或更新專案

if [ -d "/tmp/${PROJECT_NAME}" ];
then
  cd "/tmp/${PROJECT_NAME}"

  git reset --hard
  git pull --force
else
	# echo "$DIR directory does not exist."
  cd /tmp
  git clone "https://github.com/pulipulichen/${PROJECT_NAME}.git"
  cd "/tmp/${PROJECT_NAME}"
fi

# -----------------
# 確認看看要不要做docker-compose build

mkdir -p "/tmp/${PROJECT_NAME}.cache"

cmp --silent "/tmp/${PROJECT_NAME}/Dockerfile" "/tmp/${PROJECT_NAME}.cache/Dockerfile" && cmp --silent "/tmp/${PROJECT_NAME}/package.json" "/tmp/${PROJECT_NAME}.cache/package.json" || docker-compose build

cp "/tmp/${PROJECT_NAME}/Dockerfile" "/tmp/${PROJECT_NAME}.cache/"
cp "/tmp/${PROJECT_NAME}/package.json" "/tmp/${PROJECT_NAME}.cache/"

# =================
# 從docker-compose-template.yml來判斷參數

INPUT_FILE="false"
if [ -f "/tmp/${PROJECT_NAME}/docker-compose-template.yml" ]; then
    INPUT_FILE="true"
fi

# Using grep and awk to extract the public port from the docker-compose.yml file
PUBLIC_PORT="false"
if [ -f "/tmp/${PROJECT_NAME}/docker-compose-template.yml" ]; then
  PUBLIC_PORT=$(grep "ports" "/tmp/${PROJECT_NAME}/docker-compose-template.yml" | awk -F "[: ]" '{print $3}')
else
  PUBLIC_PORT=$(grep "ports" "/tmp/${PROJECT_NAME}/docker-compose.yml" | awk -F "[: ]" '{print $3}')
fi

# =================
# 讓Docker能順利運作的設定

if [ -z "$DOCKER_HOST" ]; then
    
    if [[ "$(uname)" == "Darwin" ]]; then
      echo "Running on macOS"
    else
      echo "DOCKER_HOST is not set, setting it to 'unix:///run/user/1000/docker.sock'"
      export DOCKER_HOST="unix:///run/user/1000/docker.sock"
    fi
else
    echo "DOCKER_HOST is set to '$DOCKER_HOST'"
fi

# -------------------
# 檢查有沒有輸入檔案參數

var="$1"
useParams="true"
WORK_DIR=`pwd`
if [ "$INPUT_FILE" != "false" ]; then
  if [ ! -f "$var" ]; then
    # echo "$1 does not exist."
    # exit
    if command -v kdialog &> /dev/null; then
      var=$(kdialog --getopenfilename --multiple ~/ 'Files')
      
    elif command -v osascript &> /dev/null; then
      selected_file="$(osascript -l JavaScript -e 'a=Application.currentApplication();a.includeStandardAdditions=true;a.chooseFile({withPrompt:"Please select a file to process:"}).toString()')"

      # Storing the selected file path in the "var" variable
      var="$selected_file"

    fi
    var=`echo "${var}" | xargs`
    useParams="false"
  fi
fi

# =================================================================
# 宣告函數

setDockerComposeYML() {
  file="$1"
  echo "${file}"

  filename=$(basename "$file")
  dirname=$(dirname "$file")


  template=$(<"/tmp/${PROJECT_NAME}/docker-compose-template.yml")
  echo "$template"

  template="${template/\[SOURCE\]/$dirname}"
  template="${template/\[INPUT\]/$filename}"

  echo "$template" > "/tmp/${PROJECT_NAME}/docker-compose.yml"
}

runDockerCompose() {
  must_sudo="false"
  if [[ "$(uname)" == "Darwin" ]]; then
    if ! chown -R $(whoami) ~/.docker; then
      sudo chown -R $(whoami) ~/.docker
      must_sudo="true"
      exit 0
    fi
  fi

  if [ "$PUBLIC_PORT" != "false" ]; then
    if [ "$must_sudo" != "false" ]; then
      if ! docker-compose up --build; then
        echo "Error occurred. Trying with sudo..."
        sudo docker-compose up --build
      fi
    else
      sudo docker-compose up --build
    fi
  else
    # Set up a trap to catch Ctrl+C and call the cleanup function
    trap 'cleanup' INT

    if [ "$must_sudo" != "false" ]; then
      if ! docker-compose up --build -d; then
        echo "Error occurred. Trying with sudo..."
        sudo docker-compose up --build -d
      fi
    else
      sudo docker-compose up --build -d
    fi

    echo "================================================================"
    openURL "http://127.0.0.1:$PUBLIC_PORT"

    echo "You can link the website via following URL:"
    echo "http://127.0.0.1:$PUBLIC_PORT"

    echo ""
    
    # Keep the script running to keep the container running
    # until the user decides to stop it
    echo "Press Ctrl+C to stop the Docker container and exit"
    echo "================================================================"

    # Wait indefinitely, simulating a long-running process
    # This is just to keep the script running until the user interrupts it
    # You might replace this with an actual running process that should keep the script alive
    while true; do
        sleep 1
    done
  fi
}

# Function to handle clean-up on script exit or Ctrl+C
cleanup() {
  echo "Stopping the Docker container..."
  docker-compose down
  exit 1
}

# -----------------
# 執行指令

if [ "$INPUT_FILE" != "false" ]; then
  if [ "${useParams}" == "true" ]; then
    # echo "use parameters"
    for var in "$@"
    do
      cd "${WORK_DIR}"
      

      if command -v realpath &> /dev/null; then
        var=`realpath "${var}"`
      else
        var=$(cd "$(dirname "${var}")"; pwd)/"$(basename "${var}")"
      fi
      cd "/tmp/${PROJECT_NAME}"
      setDockerComposeYML "${var}"

      runDockerCompose
    done
  else
    if [ ! -f "${var}" ]; then
      echo "$var does not exist."
    else
      setDockerComposeYML "${var}"

      runDockerCompose
    fi
  fi
else
  cd "/tmp/${PROJECT_NAME}"
  runDockerCompose
fi
