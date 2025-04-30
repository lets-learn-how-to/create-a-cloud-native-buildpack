#!/usr/bin/env bash

# If we are in the build stage, load build functions
if [[ "${0}" == *build ]]; then
  export HAS_PRINTED_ENV_VARS="false"

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

  write_layer_metadata() {
    LAYER=$1
    $CNB_BUILDPACK_DIR/bin/dasel -r toml "entries.first().metadata" < "$CNB_BP_PLAN_PATH" 2> /dev/null > "$CNB_LAYERS_DIR/$LAYER/metadata.toml"
  }

  read_layer_metadata() {
    LAYER=$1
    KEY=$2

    if [[ -f "$CNB_LAYERS_DIR/$LAYER/metadata.toml" ]]; then
      if [[ -n "$KEY" ]]; then
        get_data_from_toml "$CNB_LAYERS_DIR/$LAYER/metadata.toml" "$KEY" true
      else
        get_data_from_toml "$CNB_LAYERS_DIR/$LAYER/metadata.toml" "."
      fi
    fi
  }

  export_env_var() {
    LAYER=$1
    NAME=$2
    VALUE=$3
    TYPE=$4
    DELIMITER=$5

    if [[ "$HAS_PRINTED_ENV_VARS" == "false" ]]; then
      log_topic "Setting environment variables"
      export HAS_PRINTED_ENV_VARS="true"
    fi

    TRUNCATED_VALUE="$(echo "$VALUE" | head -c 25)"
    if [[ "$TRUNCATED_VALUE" == "$VALUE" ]]; then
      log_topic_info "Setting $TYPE variable $NAME = $VALUE"
    else
      log_topic_info "Setting $TYPE variable $NAME = $(echo $TRUNCATED_VALUE | sed -re 's/^[[:blank:]]+|[[:blank:]]+$//g' -e 's/[[:blank:]]+/ /g')..."
    fi

    if [[ -z "$DELIMITER" ]]; then
      DELIMITER=":"
    fi

    ENV_DIR="$CNB_LAYERS_DIR/$LAYER/env"

    mkdir -p "$ENV_DIR"

    if [[ "$TYPE" == "default" ]]; then
      echo -n "$VALUE" >"$ENV_DIR/$NAME.default"
    fi

    if [[ "$TYPE" == "prepend" ]]; then
      echo -n "$VALUE" >"$ENV_DIR/$NAME.prepend"
      echo -n "$DELIMITER" >"$ENV_DIR/$NAME.delim"
    fi

    if [[ "$TYPE" == "append" ]]; then
      echo -n "$VALUE" >"$ENV_DIR/$NAME.append"
      echo -n "$DELIMITER" >"$ENV_DIR/$NAME.delim"
    fi
  }

  create_plan() {
    log_error "create_plan is only usable in the detect phase"
  }
fi

# If we are in the detect stage, load detect functions
if [[ "${0}" == *detect ]]; then
  create_plan() {
    PROVIDES=$1
    REQUIRES=$2
    REQUIRES_META=""

    while read -r METADATA; do
      REQUIRES_META="$METADATA\n$REQUIRES_META"
    done

    log_topic "Creating build plan"
    log_topic_info "Provides: $PROVIDES"
    log_topic_info "Requires: $REQUIRES"

    # Update the build plan
    # See the spec at: https://github.com/buildpacks/spec/blob/main/buildpack.md#build-plan-toml
    cat <<-EOF >$CNB_BUILD_PLAN_PATH
      [[provides]]
      name = "$PROVIDES"

      [[requires]]
      name = "$REQUIRES"
EOF

    if [[ -n "$REQUIRES_META" ]]; then
      echo "[requires.metadata]" >>$CNB_BUILD_PLAN_PATH
      echo -e "$REQUIRES_META" >>$CNB_BUILD_PLAN_PATH

      log_topic_info "Metadata:"
      log_topic_info "$(echo -e $REQUIRES_META | sed -u 's/\(.*\)/  \1/')"
    fi
  }

  create_layer() {
    log_error "create_layer is only usable in the build phase"
  }
  write_layer_metadata() {
    log_error "write_layer_metadata is only usable in the build phase"
  }
  read_layer_metadata() {
    log_error "read_layer_metadata is only usable in the build phase"
  }
  export_env_var() {
    log_error "export_env_var is only usable in the build phase"
  }
fi

## Generic functions
read_plan_metadata() {
  KEY=$1

  if [[ -n "$CNB_BUILD_PLAN_PATH" ]]; then
    if [[ -n "$KEY" ]]; then
      get_data_from_toml "$CNB_BUILD_PLAN_PATH" "requires.first().metadata.$KEY" true
    else
      get_data_from_toml "$CNB_BUILD_PLAN_PATH" "requires.first().metadata"
    fi
  fi

  if [[ -n "$CNB_BP_PLAN_PATH" ]]; then
    if [[ -n "$KEY" ]]; then
      get_data_from_toml "$CNB_BP_PLAN_PATH" "entries.first().metadata.$KEY" true
    else
      get_data_from_toml "$CNB_BP_PLAN_PATH" "entries.first().metadata"
    fi
  fi
}

get_data_from_toml() {
  FILE=$1
  KEY=$2
  TRIM=$3

  if [[ "$TRIM" == "true" ]]; then
    $CNB_BUILDPACK_DIR/bin/dasel --pretty=false -r toml "$KEY" < "$FILE" | cut -d "'" -f 2 | tr -d '\n'
  else
    $CNB_BUILDPACK_DIR/bin/dasel --pretty=false -r toml "$KEY" < "$FILE"
  fi
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
      log_topic "Loading configuration"
      HEADER_HAS_PRINTED="true"
    fi

    if [[ -z "${!NAME}" ]]; then
      export "$NAME=$DEFAULT"
    else
      USED_DEFAULT="false"
    fi

    log_topic_info "$DESCRIPTION"

    if [[ "$USED_DEFAULT" == "true" ]]; then
      log_topic_info "  $NAME = ${!NAME} (default)"
    else
      log_topic_info "  $NAME = ${!NAME}"
    fi

    ((INDEX++))
  done
}

log_title() {
  echo -e "\033[34m\033[1m$1\033[0m"
}

log_topic() {
  echo -e "  $1:"
}

log_topic_info() {
  echo -e "\033[90m    $1\033[0m"
}

log_error() {
  echo -e "\033[31m!!! $1 !!!\033[0m"
  exit 1
}

init() {
  export META_NAME="$(get_data_from_toml "$CNB_BUILDPACK_DIR/buildpack.toml" "buildpack.name" true)"
  export META_VERSION="$(get_data_from_toml "$CNB_BUILDPACK_DIR/buildpack.toml" "buildpack.version" true)"

  log_title "$META_NAME: $META_VERSION"

  load_configuration

  if [[ ! -f "$CNB_BUILDPACK_DIR/bin/dasel" ]]; then
    log_topic "Downloading dasel"
    curl -sL \
      -o "$CNB_BUILDPACK_DIR/bin/dasel" \
      "https://github.com/TomWright/dasel/releases/download/v2.8.1/dasel_linux_$(uname -m)"
    chmod +x "$CNB_BUILDPACK_DIR/bin/dasel"
    log_topic_info "Download complete"
  fi
}

init
