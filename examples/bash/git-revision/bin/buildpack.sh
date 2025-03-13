#!/usr/bin/env bash

create_buildpack_plan() {
  PROVIDES=$1
  REQUIRES=$2
  REQUIRES_META=$3

  echo -e "  Creating build plan:"
  echo -e "\033[90m    Provides: $PROVIDES\033[0m"
  echo -e "\033[90m    Requires: $REQUIRES\033[0m"
  # Update the build plan
  # See the spec at: https://github.com/buildpacks/spec/blob/main/buildpack.md#build-plan-toml
  cat <<-EOF > $CNB_BUILD_PLAN_PATH
    [[provides]]
    name = "$PROVIDES"

    [[requires]]
    name = "$REQUIRES"
EOF

  if [[ -n "$REQUIRES_META" ]]; then
    echo "[requires.metadata]" >> $CNB_BUILD_PLAN_PATH
    echo "$REQUIRES_META" >> $CNB_BUILD_PLAN_PATH

    echo -e "\033[90m    Metadata:"
    echo -e "$(echo $REQUIRES_META | sed 's/\(.*\)/\\033\[90m      \1\\033\[0m/')"
  fi
}

get_buildpack_plan_meta() {
  KEY=$1

  if [[ -n "$CNB_BUILD_PLAN_PATH" ]]; then
    get_data_from_toml "$CNB_BUILD_PLAN_PATH" "requires.first().metadata.$KEY"
  fi

  if [[ -n "$CNB_BP_PLAN_PATH" ]]; then
    get_data_from_toml "$CNB_BP_PLAN_PATH" "entries.first().metadata.$KEY"
  fi
}

create_layer() {
  NAME=$1
  LAUNCH=$2
  BUILD=$3
  CACHE=$4

  mkdir -p "$CNB_LAYERS_DIR/$NAME/"
  cat <<-EOF > "$CNB_LAYERS_DIR/$NAME.toml"
    [types]
    launch = $LAUNCH
    build = $BUILD
    cache = $CACHE
EOF
}

export HAS_PRINTED_ENV_VARS="false"

set_env_var() {
  LAYER=$1
  NAME=$2
  VALUE=$3
  TYPE=$4
  DELIMETER=$5

  if [[ "$HAS_PRINTED_ENV_VARS" == "false" ]]; then
    echo "  Setting environment variables"
    export HAS_PRINTED_ENV_VARS="true"
  fi

  TRUNCATED_VALUE="$(echo "$VALUE" | head -c 25)"
  if [[ "$TRUNCATED_VALUE" == "$VALUE" ]]; then
    echo -e "\033[90m    Setting $TYPE variable $NAME = $VALUE\033[0m"
  else
    echo -e "\033[90m    Setting $TYPE variable $NAME = $(echo $TRUNCATED_VALUE | sed -re 's/^[[:blank:]]+|[[:blank:]]+$//g' -e 's/[[:blank:]]+/ /g')...\033[0m"
  fi

  if [[ -z "$DELIMETER" ]]; then
    DELIMETER=":"
  fi

  ENV_DIR="$CNB_LAYERS_DIR/$LAYER/env"

  mkdir -p "$ENV_DIR"

  if [[ "$TYPE" == "default" ]]; then
    echo -n "$VALUE" > "$ENV_DIR/$NAME.default"
  fi

  if [[ "$TYPE" == "prepend" ]]; then
    echo -n "$VALUE" > "$ENV_DIR/$NAME.prepend"
    echo -n "$DELIMETER" > "$ENV_DIR/$NAME.delim"
  fi

  if [[ "$TYPE" == "append" ]]; then
    echo -n "$VALUE" > "$ENV_DIR/$NAME.append"
    echo -n "$DELIMETER" > "$ENV_DIR/$NAME.delim"
  fi
}

get_data_from_toml() {
  FILE=$1
  KEY=$2

  $CNB_BUILDPACK_DIR/bin/dasel --pretty=false -r toml "$KEY" < "$FILE" | cut -d "'" -f 2 | tr -d '\n'
}

load_configuration() {
  INDEX="0"
  HEADER_HAS_PRINTED="false"

  while true; do
    CONFIG=$($CNB_BUILDPACK_DIR/bin/dasel -r toml "metadata.configurations.index($INDEX)" < "$CNB_BUILDPACK_DIR/buildpack.toml" 2> /dev/null)
    if [[ "$?" -ne 0 ]]; then
      break
    fi

    NAME=$(echo "$CONFIG" | grep 'name' | sed -r "s/name = '([^\']*)'/\1/")
    DEFAULT=$(echo "$CONFIG" | grep 'default' | sed -r "s/default = '([^\']*)'/\1/")
    DESCRIPTION=$(echo "$CONFIG" | grep 'description' | sed -r "s/description = '([^\']*)'/\1/")
    USED_DEFAULT="true"

    if [[ "$HEADER_HAS_PRINTED" == "false" ]]; then
      echo "  Loading configuration:"
      HEADER_HAS_PRINTED="true"
    fi

    if [[ -z "${!NAME}" ]]; then
      export "$NAME=$DEFAULT"
    else
      USED_DEFAULT="false"
    fi

    echo -e "\033[90m    $DESCRIPTION\033[0m"

    if [[ "$USED_DEFAULT" == "true" ]]; then
      echo -e "\033[90m      $NAME = ${!NAME} (default)\033[0m"
    else
      echo -e "\033[90m      $NAME = ${!NAME}\033[0m"
    fi

    ((INDEX++))
  done
}

init() {
  export META_NAME="$(get_data_from_toml "$CNB_BUILDPACK_DIR/buildpack.toml" "buildpack.name")"
  export META_VERSION="$(get_data_from_toml "$CNB_BUILDPACK_DIR/buildpack.toml" "buildpack.version")"

  echo -e "\033[0;34m\033[1m$META_NAME\033[21m $META_VERSION\033[0m"

  load_configuration
}

init
