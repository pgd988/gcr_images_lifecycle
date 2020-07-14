#!/bin/bash

CURRENT_PATH="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"
### Args parcing
for ARGUMENT in "$@"
do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)
    case "$KEY" in
            --project)              PROJECT=${VALUE} ;;
            --auth-key)                 AUTH_KEY=${VALUE} ;;
            *)
    esac
done
List_File="$CURRENT_PATH/image_list_template.tmp"
START=$(date +%s.%N)
A1=( `/usr/bin/gcloud container images list --repository gcr.io/$PROJECT` )


/usr/bin/gcloud auth activate-service-account --key-file=$CURRENT_PATH/$AUTH_KEY --project $PROJECT

if [ ! -f $List_File ]; then touch $List_File; else rm $List_File && touch $List_File; fi

for Cont_Level1 in ${A1[*]:1}
do
  B1=`echo ${Cont_Level1}|cut -d"/" -f3`
  A2=( `/usr/bin/gcloud container images list --repository gcr.io/$PROJECT/$B1 2>&1` )
  for Cont_Level2 in ${A2[*]:1}; do
    B2=( `echo ${Cont_Level2}|cut -d"/" -f4` )
    echo gcr.io/$PROJECT/$B1/$B2
    if [ $B2 == 0 ]; then
       echo "gcr.io/$PROJECT/$B1" >> $List_File
    elif [ $B2 == "items." ]; then
       B2=null
    else
       A3=( `/usr/bin/gcloud container images list --repository gcr.io/$PROJECT/$B1/$B2 2>&1` )
       for Cont_Level3 in ${A3[*]:1}; do
         B3=( `echo ${Cont_Level3}|cut -d"/" -f5` )
         echo gcr.io/$PROJECT/$B1/$B2/$B3
           if [[ $B3 == 0 ]]; then
             echo "gcr.io/$PROJECT/$B1/$B2" >> $List_File
           elif [[ $B3 == "items." ]]; then
             B3=null;
           else
             A4=( `/usr/bin/gcloud container images list --repository gcr.io/$PROJECT/$B1/$B2/$B3 2>&1` )
             for Cont_Level4 in ${A4[*]:1}; do
               B4=( `echo ${Cont_Level4}|cut -d"/" -f6` )
               echo gcr.io/$PROJECT/$B1/$B2/$B3/$B4
               if [[ $B4 == 0 ]]; then
                 echo "gcr.io/$PROJECT/$B1/$B2/$B3" >> $List_File
               elif [[ $B4 == "items." ]]; then
                 B4=null;
               else
                 A5=( `/usr/bin/gcloud container images list --repository gcr.io/$PROJECT/$B1/$B2/$B3/$B4 2>&1` )
                 for Cont_Level5 in ${A5[*]:1}; do
                   B5=( `echo ${Cont_Level5}|cut -d"/" -f7` )
                   echo gcr.io/$PROJECT/$B1/$B2/$B3/$B4/$B5
                   if [[ $B5 == 0 ]]; then
                     echo "gcr.io/$PROJECT/$B1/$B2/$B3/$B4" >> $List_File
                   elif [[ $B5 == "items." ]]; then
                     B5=null;
                   else
                     echo "$B5 ------------------------------------- Next level needs to be added"
                   fi
                 done
               fi
             done
           fi 
       done
    fi
  done
done
cat $List_File|wc -l
cp $List_File $CURRENT_PATH/images.lst
if [[ $? -eq 0 ]]; then rm $List_File; fi
END=$(date +%s.%N)
DIFF=`echo "$END-$START" | bc -l`
echo "Script's execution time is $DIFF sec."
