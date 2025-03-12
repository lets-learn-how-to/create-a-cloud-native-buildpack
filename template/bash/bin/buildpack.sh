#!/usr/bin/env bash

set -eo pipefail

create_buildpack_plan() {
  PROVIDES=$1
  REQUIRES=$2
  REQUIRES_META=$3

  echo -e "\033[90m  Creating plan\033[0m"
  # Update the build plan
  # See the spec at: https://github.com/buildpacks/spec/blob/main/buildpack.md#build-plan-toml
  cat << EOF > $CNB_BUILD_PLAN_PATH
[[provides]]
name = "$PROVIDES"

[[requires]]
name = "$REQUIRES"

EOF

  if [[ -n "REQUIRES_META" ]]; then
    echo "[requires.metadata]" >> $CNB_BUILD_PLAN_PATH
    echo "$REQUIRES_META" >> $CNB_BUILD_PLAN_PATH
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
  cat << EOF > "$CNB_LAYERS_DIR/$NAME.toml"
[types]
launch = $LAUNCH
build = $BUILD
cache = $CACHE
EOF
}

set_env_var() {
  LAYER=$1
  NAME=$2
  VALUE=$3
  TYPE=$4
  DELIMETER=$5

  echo -e "\033[90m  Setting $TYPE variable $NAME = $VALUE\033[0m"

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

init() {
  export META_NAME="$(get_data_from_toml "$CNB_BUILDPACK_DIR/buildpack.toml" "buildpack.name")"
  export META_VERSION="$(get_data_from_toml "$CNB_BUILDPACK_DIR/buildpack.toml" "buildpack.version")"

  echo -e "\033[0;34m\033[1m$META_NAME\033[21m $META_VERSION\033[0m"
}

init
