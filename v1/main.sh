#!/bin/bash
C=0
IFS=$'\n\t'
#set -eou pipefail
set -eo pipefail
IMAGE=`cat ./images.lst`
print_help () {
    echo -e "\nPlease call '$0 -p=\"Yor GCP Project ID\" -t=\"Threshold for Image deletion\" -k=\"Path to ServiceAccount json Key File\""
}

if [ -z "$1" ]; then
    print_help
    exit 1
fi

### Args parcing
for ARGUMENT in "$@"
do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)
    case "$KEY" in
            -p)           REGISTRY="gcr.io/${VALUE}" PROJECT=${VALUE};;
            -t)           THRESHOLD=${VALUE} ;;
            -k)           KEYFILE="${VALUE}" ;;
            *)
    esac
done

gcloud auth activate-service-account --key-file=$KEYFILE --project $PROJECT
for img in $IMAGE; do
CONTCOUNT="$(gcloud container images list-tags ${img} --limit=999999 --sort-by=TIMESTAMP  | grep -v DIGEST | wc -l)"
  for digest in $(gcloud container images list-tags ${img} --limit=999999 --sort-by=TIMESTAMP --format='get(digest)'); do
    if [ $(( $CONTCOUNT - $C )) -ge $THRESHOLD ]
    then
      (
        set -x
        gcloud container images delete -q --force-delete-tags "${img}@${digest}"
      )
      let C=C+1
    else
      echo "Deleted $(( $CONTCOUNT - $(($THRESHOLD - 1)) )) images in ${img}." >&2
      break
    fi
  done
done

