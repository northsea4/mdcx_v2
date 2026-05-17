#!/bin/bash

OS=$(uname)
FILE_INITIALIZED=".mdcx_initialized"
COMPOSE_COMMAND=""
COMPOSE_DISPLAY_COMMAND=""

replace_in_file() {
  if [ "$OS" = 'Darwin' ]; then
    # for MacOS
    sed -i '' -r -e "$1" "$2"
  else
    # for Linux and Windows
    sed -i'' -r -e "$1" "$2"
  fi
}

run_compose() {
  if [ "$COMPOSE_COMMAND" = "docker-compose" ]; then
    docker-compose "$@"
  else
    docker compose "$@"
  fi
}

# 发生错误时的退出处理
on_error() {
  local projectDir=$1
  
  echo ""
  # 询问是否删除目录
  read -p "❓ 是否删除项目目录 ${projectDir}？（y/N，默认为N）：" DELETE_DIR
  DELETE_DIR=${DELETE_DIR:-N}
  echo ""
  if [[ "$DELETE_DIR" =~ ^[Yy]$ ]]; then
    rm -rf "$projectDir"
    echo "🗑 已删除目录：${projectDir}"
  else
    echo "📁 项目目录已被保留：${projectDir}"
  fi

  exit 1
}

check_dependencies() {
  # 检查是否有jq命令
  if ! command -v jq > /dev/null 2>&1; then
    echo "❌ 请先安装jq命令！参考：https://command-not-found.com/jq"
    exit 1
  fi

  # 必须有unzip或者7z
  if ! command -v unzip > /dev/null 2>&1 && ! command -v 7z > /dev/null 2>&1; then
    echo "❌ 未找到unzip或7z命令，请先安装unzip或7z命令。"
    exit 1
  fi

  # 检查是否有docker命令
  if ! command -v docker > /dev/null 2>&1; then
    echo "❌ 未找到docker命令，请先安装docker。"
    exit 1
  fi

  # 检查是否有docker-compose命令或docker compose子命令
  if command -v docker-compose > /dev/null 2>&1; then
    COMPOSE_COMMAND="docker-compose"
    COMPOSE_DISPLAY_COMMAND="docker-compose"
  elif docker compose version > /dev/null 2>&1; then
    COMPOSE_COMMAND="docker compose"
    COMPOSE_DISPLAY_COMMAND="docker compose"
  else
    echo "❌ 未找到 docker-compose 命令，也无法使用 docker compose，请先安装 Docker Compose。"
    exit 1
  fi
}

choose_template() {
  # 询问用户选择的模版
  echo "📖 下面请你回答几个问题，以完成MDCx Docker版的安装。"
  echo ""
  echo "❓ 请选择容器部署模版（输入数字进行选择）："
  echo " 1) mdcx-builtin-gui-base      轻量版，内置编译版应用，通过网页使用"
  echo " 2) mdcx-builtin-webtop-base   重量版，内置编译版应用，通过网页使用"

  read -p "📌 请输入数字（1 或 2）: " TEMPLATE_NUM

  case "$TEMPLATE_NUM" in
    1)
      TEMPLATE_NAME="mdcx-builtin-gui-base"
      ;;
    2)
      TEMPLATE_NAME="mdcx-builtin-webtop-base"
      ;;
    *)
      echo "无效的输入！请输入数字（1 或 2）."
      exit 1
      ;;
  esac

  echo "📝 您选择的模版为：$TEMPLATE_NUM) $TEMPLATE_NAME"
  echo ""
}

set_base_by_template() {
  if [[ "$TEMPLATE_NAME" == *"gui-base"* ]]; then
    BASE=gui
  else
    BASE=webtop
  fi
}

download_and_extract_template() {
  #拼接模版文件下载链接
  DOWNLOAD_URL="https://github.com/northsea4/mdcx-docker/releases/download/latest/template-$TEMPLATE_NAME.zip"

  echo "🔗 模版文件下载链接：$DOWNLOAD_URL"
  echo ""

  echo "⏳ 正在下载模版文件，请稍候..."

  # 下载zip文件并保存为随机文件名
  # RANDOM_NAME=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9-_' | fold -w 29 | sed 1q)
  # fold命令在某些系统上不支持，使用head命令代替
  RANDOM_NAME=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9-_' | head -c 29)
  if [ $? -ne 0 ]; then
    echo "❌ 生成随机文件名失败！"
    exit 1
  fi

  ZIP_FILE="${RANDOM_NAME}.zip"
  curl "$DOWNLOAD_URL" -L --connect-timeout 30 --max-time 300 -o "$ZIP_FILE"
  if [ $? -ne 0 ]; then
    echo "❌ 模版文件下载失败！"
    on_error "${DIR_FULL_PATH}"
  fi

  # 创建以文件名为名称的目录并解压zip文件
  mkdir "$RANDOM_NAME"
  # 如果有7z命令，则使用7z解压
  if command -v 7z > /dev/null 2>&1; then
    7z x "$ZIP_FILE" -o"$RANDOM_NAME"
  else
    unzip "$ZIP_FILE" -d "$RANDOM_NAME"
  fi

  if [ $? -ne 0 ]; then
    echo "❌ 模版文件解压失败！"
    on_error "${DIR_FULL_PATH}"
  fi

  echo "🎉 模版文件下载完成！"
  echo ""
}

setup_project_directory() {
  # 询问用户目录名称，默认为 `mdcx-docker`
  echo "选择一个目录作为本docker项目的根目录(存放应用或容器的相关数据)，可以是目录路径或目录名称。"
  read -p "❓ 请输入目录名称（默认为 mdcx-docker）：" DIR_NAME
  DIR_NAME=${DIR_NAME:-mdcx-docker}

  # 检查目录是否已存在
  while [ -d "$DIR_NAME" ]; do
    read -p "❌ 目录已存在，请输入其他目录名称：" DIR_NAME
  done

  # 移动mdcx-docker模版目录并重命名为用户输入的目录名称
  mv "$RANDOM_NAME/mdcx-docker" "$DIR_NAME"
  # 删除临时目录和zip文件
  rm -rf "$RANDOM_NAME"
  rm "$ZIP_FILE"

  # 进入用户输入的目录名称
  cd "$DIR_NAME" || exit 1
  DIR_FULL_PATH=$(pwd)
  echo "📁 已创建并进入目录：$(pwd)"

  source .env
}

collect_runtime_inputs() {
  USER_ID=$(id -u)
  GROUP_ID=$(id -g)
  # 不同模版使用不同的环境变量名称
  if [[ "$BASE" == "gui" ]]; then
    USER_ID_KEY="USER_ID"
    GROUP_ID_KEY="GROUP_ID"
  else
    USER_ID_KEY="PUID"
    GROUP_ID_KEY="PGID"
  fi

  echo ""
  echo "❓ 请输入${USER_ID_KEY}（容器使用的UID），默认为$(id -u)"
  read -p "${USER_ID_KEY}: " USER_ID
  USER_ID=${USER_ID:-$(id -u)}

  echo ""
  echo "❓ 请输入${GROUP_ID_KEY}（容器使用的GID），默认为$(id -g)"
  read -p "${GROUP_ID_KEY}: " GROUP_ID
  GROUP_ID=${GROUP_ID:-$(id -g)}

  # 不同的模版使用不同的端口环境变量名称
  if [[ "$BASE" == "gui" ]]; then
    echo ""
    echo "❓ 请输入WEB访问端口号， 默认为5800"
    read -p "WEB_PORT: " WEB_PORT
    WEB_PORT=${WEB_PORT:-5800}

    echo ""
    echo "❓ 请输入VNC端口号， 默认为5900"
    read -p "VNC_PORT: " VNC_PORT
    VNC_PORT=${VNC_PORT:-5900}
  else
    echo ""
    echo "❓ 请输入WEB访问端口号， 默认为3000"
    read -p "WEB_PORT: " WEB_PORT
    WEB_PORT=${WEB_PORT:-3000}

    echo ""
    echo "❓ 请输入HTTPS访问端口号， 默认为3001"
    read -p "HTTPS_PORT: " HTTPS_PORT
    HTTPS_PORT=${HTTPS_PORT:-3001}
  fi

  echo ""
  echo "❓ 请输入镜像TAG版本，默认为v2-latest"
  read -p "IMAGE_TAG: " IMAGE_TAG
  IMAGE_TAG=${IMAGE_TAG:-v2-latest}

  echo ""
  while true; do
    read -p "❓ 请输入需要映射的影片目录，格式为/path/to/movies:/movies，留空则跳过： " MOVIE_DIR
    if [ -z "$MOVIE_DIR" ]; then
      break
    elif ! echo "$MOVIE_DIR" | grep -qE '^[^:]+:[^:]+$'; then
      echo "❌ 错误：输入格式不正确，请按格式输入"
      continue
    fi
    VOLUMES="$VOLUMES\n      - $MOVIE_DIR"
  done
}

confirm_inputs() {
  # 展示用户所输入的信息，并询问确认信息是否正确
  echo ""
  echo "📝 您输入的信息如下："
  echo "🔘 $USER_ID_KEY: $USER_ID"
  echo "🔘 $GROUP_ID_KEY: $GROUP_ID"
  echo "🔘 IMAGE_TAG: $IMAGE_TAG"

  # 根据不同的模版，展示不同的端口信息
  if [[ "$BASE" == "gui" ]]; then
    echo "🔘 WEB_PORT: $WEB_PORT"
    echo "🔘 VNC_PORT: $VNC_PORT"
  else
    echo "🔘 WEB_PORT: $WEB_PORT"
    echo "🔘 HTTPS_PORT: $HTTPS_PORT"
  fi

  if [ -z "$VOLUMES" ]; then
    echo "🔘 映射目录：没有指定"
  else
    echo "🔘 映射目录："
    echo -e "${VOLUMES[*]}\n"
  fi

  echo ""
  read -p "❓ 确认信息是否填写正确（Y/n，默认为Y）：" CONFIRMED
  CONFIRMED=${CONFIRMED:-Y}

  if [[ "$CONFIRMED" =~ ^[nN](o)?$ ]]; then
    echo "❗ 操作已取消"
    on_error "${DIR_FULL_PATH}"
  fi
}

apply_replacements() {
  echo "⏳ 替换环境变量..."
  # 根据不同的模版，替换不同的环境变量名称
  if [[ "$BASE" == "gui" ]]; then
    replace_in_file "s/USER_ID=[0-9]+/USER_ID=$USER_ID/g" .env
    replace_in_file "s/GROUP_ID=[0-9]+/GROUP_ID=$GROUP_ID/g" .env
  else
    replace_in_file "s/PUID=[0-9]+/PUID=$USER_ID/g" .env
    replace_in_file "s/PGID=[0-9]+/PGID=$GROUP_ID/g" .env
  fi

  # 根据不同的模版，替换不同的端口信息
  if [[ "$BASE" == "gui" ]]; then
    replace_in_file "s/WEB_PORT=[0-9]+/WEB_PORT=$WEB_PORT/g" .env
    replace_in_file "s/VNC_PORT=[0-9]+/VNC_PORT=$VNC_PORT/g" .env
  else
    replace_in_file "s/WEB_PORT=[0-9]+/WEB_PORT=$WEB_PORT/g" .env
    replace_in_file "s/HTTPS_PORT=[0-9]+/HTTPS_PORT=$HTTPS_PORT/g" .env
  fi

  echo "✅ 替换环境变量完成"

  echo "⏳ 替换挂载卷..."
  # $VOLUMES不为空时才进行替换
  if [[ -n "$VOLUMES" ]]; then
    replace_in_file "s|# VOLUMES_REPLACEMENT|$VOLUMES|" docker-compose.yml
    echo "✅ 替换挂载卷完成"
  else
    echo "❗ 你没有指定映射影片目录，你可以之后在docker-compose.yml中手动添加。"
  fi

  # 询问输入容器名称
  echo ""
  echo "❓ 请输入容器名称（默认：${MDCX_CONTAINER_NAME}）"
  read -p "容器名称：" CONTAINER_NAME
  CONTAINER_NAME=${CONTAINER_NAME:-$MDCX_CONTAINER_NAME}

  echo "⏳ 替换容器名称..."
  replace_in_file "s/MDCX_CONTAINER_NAME=.*/MDCX_CONTAINER_NAME=$CONTAINER_NAME/g" .env
  echo "✅ 替换容器名称完成"

  echo "⏳ 替换镜像TAG..."
  replace_in_file "s/IMAGE_TAG=.*/IMAGE_TAG=$IMAGE_TAG/g" .env
  echo "✅ 替换镜像TAG完成"
}

pull_images() {
  # 拉取镜像
  echo ""
  echo "⏳ 拉取镜像..."
  run_compose pull
  if [ $? -eq 0 ]; then
    echo "✅ 拉取镜像完成"
  else
    echo "❌ 拉取镜像失败，请检查错误日志。如果是网络问题，在解决后你可以使用以下命令重新拉取和运行: "
    echo "cd ${DIR_FULL_PATH}"
    echo "${COMPOSE_DISPLAY_COMMAND} pull"
    echo "${COMPOSE_DISPLAY_COMMAND} up -d"

    on_error "${DIR_FULL_PATH}"
  fi
}

start_or_create_container() {
  echo ""
  read -p "❓ 是否运行容器？[y/n] " RUN_CONTAINER
  if [[ "$RUN_CONTAINER" =~ ^[Yy](es)?$ ]]; then
    run_compose up -d
    if [ $? -eq 0 ]; then
      echo "✅ 容器已经成功运行"
      echo ""
      echo "🔘 可以通过以下命令查看容器运行状态:"
      echo "🔘 docker ps -a | grep $CONTAINER_NAME"
    else
      echo "❌ 容器启动失败，请检查错误日志"

      on_error "${DIR_FULL_PATH}"
    fi
  else
    run_compose create

    echo "🔘 你可以之后通过以下命令启动容器:"
    echo "cd ${DIR_FULL_PATH} && ${COMPOSE_DISPLAY_COMMAND} up -d"
  fi
}

main() {
  check_dependencies
  choose_template
  set_base_by_template
  download_and_extract_template
  setup_project_directory
  collect_runtime_inputs
  confirm_inputs
  apply_replacements
  pull_images
  start_or_create_container

  echo ""
  echo "👋🏻 Enjoy!"
}

main "$@"