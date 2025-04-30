#!/usr/bin/env bash

MAX_PRIME=$1

PRIMES=""
for ((n = 1; n <= MAX_PRIME; n++)); do
  IS_PRIME="true"

  for ((i=2; i<= n/2; i++)); do
    ans=$(( n%i ))
    if [ $ans -eq 0 ]; then
      IS_PRIME="false"
      break
    fi
  done

  if [[ "$IS_PRIME" == "true" ]]; then
    PRIMES="$PRIMES $n"
  fi
done

echo "$PRIMES" | sed -re 's/^[[:blank:]]+|[[:blank:]]+$//g' -e 's/[[:blank:]]+/ /g'
