kubectl apply -f .\vote.yml
kubectl apply -f .\result.yml

kubectl get pods

kubectl describe pods vote

kubectl exec -it vote -- sh
