#!/bin/bash
C=0
REGISTRY="gcr.io/deep-wares-144610"
IFS=$'\n\t'
set -eou pipefail
IMAGE=`cat ./images.lst`

gcloud auth activate-service-account --key-file=./gcr.key --project deep-wares-144610

for img in $IMAGE; do
COUNTALL="$(gcloud container images list-tags ${img} --limit=999999 --sort-by=TIMESTAMP  | grep -v DIGEST | wc -l)"

  for digest in $(gcloud container images list-tags ${img} --limit=999999 --sort-by=TIMESTAMP --format='get(digest)'); do

    if [ $(( $COUNTALL - $C )) -ge 3 ]
    then
      (
        set -x
        gcloud container images delete -q --force-delete-tags "${img}@${digest}"
      )
      let C=C+1
    else
      echo "Deleted $(( $COUNTALL - 2 )) images in ${img}." >&2
      break
    fi
  done
done

