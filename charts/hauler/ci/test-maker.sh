#for testvalue in $(ls *-values.yaml)
#do
#  name=$(basename ${testvalue}| rev | cut -c13- | rev)
#  namespace=hauler-${name}
#  helm install $name .. --namespace ${namespace} --values ${testvalue} --create-namespace
#  helm uninstall $name --namespace ${namespace}
#  REGISTRY_URL=http://hauler-registry.${namespace}.svc.cluster.local:5000/v2/_catalog
#  kubectl exec -q test-pod -- curl -s ${REGISTRY_URL} > expected/${name}-reg-output.txt
#  HTTP_URL=http://hauler-fileserver.${namespace}.svc.cluster.local:8080
#  kubectl exec -q test-pod -- curl -s ${HTTP_URL} > expected/${name}-web-output.txt
#done
