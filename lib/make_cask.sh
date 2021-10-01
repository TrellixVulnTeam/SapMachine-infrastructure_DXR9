#!/bin/bash
set -ex

# expecting:
# GITHUB_API_ACCESS_TOKEN
# GIT_TAG_NAME
# JOB_NAME
# RELEASE

check_and_make () {
  BUNDLE=$1
    
  THIS_SHA_URL=https://github.com/SAP/SapMachine/releases/download/${ARTEFACT_DIR}/sapmachine-${BUNDLE}-${ARTEFACT_DESIG}_${OS_NAME}-${THIS_EXT}_bin.sha256.dmg.txt
  OTHER_SHA_URL=https://github.com/SAP/SapMachine/releases/download/${ARTEFACT_DIR}/sapmachine-${BUNDLE}-${ARTEFACT_DESIG}_${OS_NAME}-${OTHER_EXT}_bin.sha256.dmg.txt

  OTHER_SHA=`curl -L -H "Authorization: token ${GITHUB_API_ACCESS_TOKEN}" ${OTHER_SHA_URL} | cut -d ' ' -f 1`

  if [[ ${#OTHER_SHA} != 64 && ${ONLY_X64} != true ]]; then
    # Other pipe isn't ready yet, it'll do the work once it gets ready
    return
  fi

  THIS_SHA=`curl -L -H "Authorization: token ${GITHUB_API_ACCESS_TOKEN}" ${THIS_SHA_URL} | cut -d ' ' -f 1`
  
  if [[ ${#THIS_SHA} != 64 ]]; then
    # This ain't right!! Anyway, nothing we can do 
    return
  fi

  CASK_URL=https://github.com/SAP/homebrew-SapMachine/raw/master/Casks/sapmachine${MAJOR}${EA_DESIG}-${BUNDLE}.rb
  CASK_VER=`curl -L -H "Authorization: token ${GITHUB_API_ACCESS_TOKEN}" ${CASK_URL} | grep '^ *version *' | sed 's/ *version *//g' | sed "s/'//g"`

  if [[ ${CASK_VER} == ${TARGET_CASK_VER} ]]; then
    # Cask already there, don't change it
    return
  fi

  if [[ ${THIS_EXT} == x64 ]]; then
    X64_SHA=${THIS_SHA}
    AARCH_SHA=${OTHER_SHA}
  else
    X64_SHA=${OTHER_SHA}
    AARCH_SHA=${THIS_SHA}
  fi

  if [[ ${ONLY_X64} == true ]]; then
    python3 SapMachine-Infrastructure/lib/make_cask.py -t ${GIT_TAG_NAME} --sha256sum ${X64_SHA} -i ${BUNDLE} ${PRE_RELEASE_OPT}
  else
    python3 SapMachine-Infrastructure/lib/make_cask.py -t ${GIT_TAG_NAME} --sha256sum ${X64_SHA} --aarchsha256sum ${AARCH_SHA} -i ${BUNDLE} ${PRE_RELEASE_OPT}
  fi      
}

# Main
MAJOR="${GIT_TAG_NAME:11:2}"
VERSION=`echo "${GIT_TAG_NAME:11}" | cut -d '+' -f 1`

# change this to '[[ $MAJOR < 17 && $MAJOR != 11 ]]' once Apple Silicone is supported in 11
if [[ $MAJOR < 17 ]]; then
  ONLY_X64=true
  OS_NAME=osx
else
  ONLY_X64=false
  OS_NAME=macos
fi    

if [[ "${JOB_NAME: -6}" == x86_64 ]]; then
  THIS_EXT=x64
  OTHER_EXT=aarch64
else
  THIS_EXT=aarch64
  OTHER_EXT=x64
fi

ARTEFACT_DIR=`echo "$GIT_TAG_NAME" | sed 's/+/%2B/g'`

if [[ "$RELEASE" == true ]]; then
  ARTEFACT_DESIG="${GIT_TAG_NAME:11}"
  EA_DESIG=''
  TARGET_CASK_VER="${VERSION}"
  PRE_RELEASE_OPT=""
else
  BUILD_NUMBER=`echo "${GIT_TAG_NAME:11}" | cut -d '+' -f 2`
  ARTEFACT_DESIG="${VERSION}-ea.${BUILD_NUMBER}"
  EA_DESIG='-ea'
  TARGET_CASK_VER="${VERSION},${BUILD_NUMBER}"
  PRE_RELEASE_OPT="-p"
fi

check_and_make jre
check_and_make jdk
