# Heterogeneous Kubernetes cluster demo

## Build images

### redis-master

There is no need to build an image since the official `redis:3.0-nanoserver` will be used.

### redis-slave

```
cd docker/redis-slave
docker build -t redis-slave:3.0-nanoserver .
```

### guestbook

```
cd docker/guestbook
docker build -t guestbook:0.3-nanoserver .
```

## Deploy

```
cd deploy

kubectl create -f redis-master-svc.yaml
kubectl create -f redis-slave-svc.yaml
kubectl create -f guestbook-svc.yaml

kubectl create -f redis-master-deployment.yaml
kubectl create -f redis-slave-deployment.yaml
kubectl create -f guestbook-deployment.yaml
```