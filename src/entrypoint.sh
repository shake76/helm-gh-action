#!/usr/bin/env bash

set -o errexit
set -o pipefail

GITHUB_TOKEN=$1
CHARTS_DIR=$2
CHARTS_URL=$3
OWNER=$4
REPOSITORY=$5
BRANCH=$6
HELM_VERSION=$7

CHARTS_TMP_DIR=$(mktemp -d)
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_URL=""

main() {
  if [[ -z "$HELM_VERSION" ]]; then
      HELM_VERSION="3.2.1"
  fi

  if [[ -z "$CHARTS_DIR" ]]; then
      CHARTS_DIR="charts"
  fi

  if [[ -z "$OWNER" ]]; then
      OWNER=$(cut -d '/' -f 1 <<< "$GITHUB_REPOSITORY")
  fi

  if [[ -z "$REPOSITORY" ]]; then
      REPOSITORY=$(cut -d '/' -f 2 <<< "$GITHUB_REPOSITORY")
  fi

  if [[ -z "$BRANCH" ]]; then
      BRANCH="gh-pages"
  fi

  if [[ -z "$CHARTS_URL" ]]; then
      CHARTS_URL="https://${OWNER}.github.io/${REPOSITORY}"
  fi

  if [[ -z "$REPO_URL" ]]; then
      REPO_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${OWNER}/helm-carts/${REPOSITORY}"
  fi

  download
  package
  upload
}

download() {
  tmpDir=$(mktemp -d)

  pushd $tmpDir >& /dev/null

  curl -sSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar xz
  cp linux-amd64/helm /usr/local/bin/helm

  popd >& /dev/null
  rm -rf $tmpDir
}

package() {
  cd ${REPO_ROOT}/helmcharts/${CHARTS_DIR}	
  helm package -u  .  --destination ${CHARTS_TMP_DIR}
}

upload() {
  tmpDir=$(mktemp -d)
  pushd $tmpDir >& /dev/null

  git clone ${REPO_URL}
  cd ${REPOSITORY}
  git config user.name "${GITHUB_ACTOR}"
  git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
  git remote set-url origin ${REPO_URL}
  git checkout gh-pages

  charts=$(cd ${CHARTS_TMP_DIR} && ls *.tgz | xargs)

  mv -f ${CHARTS_TMP_DIR}/*.tgz .
  helm repo index . --url ${CHARTS_URL}

  git add .
  git commit -m "Publish $charts"
  git push origin gh-pages

  popd >& /dev/null
  rm -rf $tmpDir
}

main
