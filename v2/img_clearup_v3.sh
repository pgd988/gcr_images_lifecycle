#!/bin/bash
#set -eou pipefail

### Args parcing
for ARGUMENT in "$@"
do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)
    case "$KEY" in
            --project)              PROJECT=${VALUE} ;;
            --threshold)            THRESHOLD=${VALUE} ;;
            --auth-key)             AUTH_KEY=${VALUE} ;;
            *)
    esac
done

START=$(date +%s.%N)
REGISTRY="gcr.io/$PROJECT"
CURRENT_PATH="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"
IMAGE=( `cat $CURRENT_PATH/images.lst` )
Num_File="$CURRENT_PATH/img_clean.log"
BRANCHES=( `cat $CURRENT_PATH/branches.lst` )
#THRESHOLD=2

##########################################################################################################################
if [ ! -f $Num_File ]; then touch $Num_File; else mv $Num_File $Num_File-`date +%Y%m%e%H%M%S` && touch $Num_File; fi
Count=( `ls -1 --sort=time $Num_File-*` )

if [ ${#Count[@]} -gt 2 ]; then
  total_del=`echo "${Count[@]:1}"`
  rm -r $total_del
fi
##########################################################################################################################

/usr/bin/gcloud auth activate-service-account --key-file=$CURRENT_PATH/$AUTH_KEY --project $PROJECT

##########################################################################################################################

delete(){
    COUNTALL=${#digest[@]}
    if [[ ${COUNTALL} -gt ${THRESHOLD} ]]; then
      Include=${digest[*]::${COUNTALL}-${THRESHOLD}};
      Exclude=${digest[*]:${COUNTALL}-${THRESHOLD}};
    elif [[ ${COUNTALL} -eq ${THRESHOLD} ]]; then
      Include="";
      Exclude=${digest[*]};
    else
      Include="";
      Exclude=${digest[*]};
    fi
    for digest_inc in ${Include}; do
        (
          set -x
          /usr/bin/gcloud container images delete -q --force-delete-tags "${img}@${digest_inc}"
           echo " Deleting: ${img}@${digest_inc}" >> $Num_File
        )
    done
    for digest_ext in ${Exclude}; do
      ( set -x; echo "Skipped: ${img}@${digest_ext}" >> $Num_File )
    done
  }

##########################################################################################################################

echo "Clearing up branches tagged images"
for i in ${BRANCHES[@]}; do 
  BRANCH_STRING+=$i"|";
done;
BRANCH_STRING=${BRANCH_STRING%"|"}

for img in ${IMAGE[@]}; do
  TAG_ALL=( `/usr/bin/gcloud container images list-tags ${img} --limit=999999 --sort-by=TIMESTAMP --format=json|jq -r ".[].tags[]"` )
  ContainerALL=( `echo -e "${TAG_ALL[*]}"| tr ' ' '\n'|grep -E "$BRANCH_STRING"` )
  if [[ ${#ContainerALL[*]} -eq 0 ]]; then
    Cont_TAG=( `echo "${TAG_ALL[*]}"| tr ' ' '\n'` )
    digest=( `/usr/bin/gcloud container images list-tags ${img} --limit=unlimited --sort-by=TIMESTAMP --filter="tags: (${Cont_TAG[*]})" --format='get(digest)'` )
    delete 
  else
    for branch in ${BRANCHES[@]}; do
      #a="True"
      if [[ $branch == "develop" ]]; then
        Container_TAG=( `echo "${TAG_ALL[*]}"| tr ' ' '\n'|grep ${branch}|grep -v 'deploy'` )
      else
        Container_TAG=( `echo "${TAG_ALL[*]}"| tr ' ' '\n'|grep ${branch}` )
      fi
      if [[ ${#Container_TAG[@]} -eq 0 ]]; then
        continue
      else
        Cont_TAG=( `echo "${TAG_ALL[*]}"| tr ' ' '\n'|grep ${branch}` )
        digest=( `/usr/bin/gcloud container images list-tags ${img} --limit=unlimited --sort-by=TIMESTAMP --filter="tags: (${Cont_TAG[*]})" --format='get(digest)'` )
        delete
      fi
    done
  fi
done
END=$(date +%s.%N)
DIFF=`echo "$END-$START" | bc -l`
  h=`bc <<< "$DIFF/60/60"`
  m=`bc <<< "$DIFF/60%60"`
  s=`bc <<< "$DIFF%60%60"`
( set -x; echo "Script's execution time is $DIFF sec. ($h:$m:$s)" >> $Num_File )
