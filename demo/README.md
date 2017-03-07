# Heterogeneous Kubernetes cluster demo

## Build images

Since we are not caching the Windows Containers images to be used for this demo, you'll need to build them on every Windows node, as follows:

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
docker build -t guestbook:v0.3-nanoserver .
```

## Deploy

Deployment may happen anywhere for as long as there's access to the Kubernetes API, as follows:

```
cd deploy

kubectl create -f redis-master-svc.yaml
kubectl create -f redis-slave-svc.yaml
kubectl create -f guestbook-svc.yaml

kubectl create -f redis-master-deployment.yaml
kubectl create -f redis-slave-deployment.yaml
kubectl create -f guestbook-deployment.yaml
```