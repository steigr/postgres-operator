#!/usr/bin/env sh

[[ "$1" ]] && namespace="$1" || read -p "Enter your namespace for the example application: "  namespace
[[ "$2" ]] && repository="$2" || read -p "Enter the Docker repository in which to place the built operator (example: quay.io/mynamespace/example-sao): " repository
[[ "$3" ]] && version="$3" || read -p "Enter the Version of the operator image: (example: v0.0.1): " version
[[ "$4" ]] && prefix="$4" || read -p "Enter the Prefix for Deployments: (example: myapp): " prefix

if [ -z "$namespace" ]; then
    echo "Missing namespace";
    exit 1;
fi

if [ -z "$repository" ]; then
    echo "Missing repository";
    exit 1;
fi

if [ -z "$version" ]; then
    echo "Missing version";
    exit 1;
fi

if [ -z "$prefix" ]; then
    echo "Missing prefix";
    exit 1;
fi

TEMP_DIR=`mktemp -d`

function cleanup {
  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

# Copy the yaml files and Dockerfile into the temp directory
cp Dockerfile $TEMP_DIR
cp *.yaml $TEMP_DIR
cp -r chart $TEMP_DIR/
cd $TEMP_DIR

# Replace all required "variables"
ls *.clusterserviceversion.yaml | xargs -n1 -I{} cp {} {}.old
sed -i.bak "s/YOUR_NAMESPACE_HERE/${namespace}/g" *.yaml
sed -i.bak "s/YOUR_REPO_IMAGE_HERE/${repository//\//\\/}/g" *.yaml
sed -i.bak "s/YOUR_PREFIX_HERE/${prefix}/g" *.yaml
sed -i.bak "s/YOUR_VERSION_HERE/${version}/g" *.yaml
sed -i.bak "s/YOUR_SEM_VERSION_HERE/${version##v}/g" *.yaml
sed -i.bak "s/YOUR_SEM_VERSION_HERE/${version##v}/g" chart/Chart.yaml

# Build and push
echo "Building and pushing stateless app operator"
docker build -t $repository:$version .
docker tag $repository:$version $repository:latest
docker push $repository:$version
docker push $repository:latest

# Create in cluster
echo "Registering app"
( cat *.crd.yaml | kubectl replace -f - ) || ( cat *.crd.yaml | kubectl create -f - )
if cat *.clusterserviceversion.yaml | kubectl replace -f - ; then
    true
else
    cat *.clusterserviceversion.yaml | kubectl create -f -
    # should remove old deployments here
    for clusterserviceversion in $(kubectl get clusterserviceversion-v1s -n "$namespace" -o name | grep "$(basename "$repository")" | grep -v "$version$"); do
        kubectl delete "$clusterserviceversion"
    done
fi
