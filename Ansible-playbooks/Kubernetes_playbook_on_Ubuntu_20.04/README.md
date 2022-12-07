# Instalar Cluster de Kubernetes en Ubuntu Server 20.04 (Instalación manual)

Para realizar una instalación desatendida ejecutar el playbook `Install_kubernetes.yml`.

```bash
ansible-playbook -i inventory_hosts -u vagrant -k Install_kubernetes.yml
```

Los requisitos minimos para formar el cluster tanto en el nodo Master como en los Workers son de 2GB de memoria RAM y 2 CPU's.

#### 1. Instalación de kubelet, kubeadm y kubectl

```bash
sudo apt-get update
```

```bash
sudo apt-get -y install curl apt-transport-https
```

```bash
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
```

```bash
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

```bash
sudo apt-get update
```

```bash
sudo apt-get -y install kubelet kubeadm kubectl
```

```bash
kubectl version --client && kubeadm version
```

#### 

#### 2. Desahabilitar Swap y Configurar sysctl

```bash
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

```bash
sudo swapoff -a
```

```bash
sudo modprobe overlay
```

```bash
sudo modprobe br_netfilter
```

```bash
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
```

```bash
sudo sysctl --system
```

#### 3. Instalar Docker como «Container runtime»

```bash
sudo apt-get update
```

```bash
sudo apt-get install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
```

```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - 
```

```bash
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" 
```

```bash
sudo apt-get update
```

```bash
sudo apt-get install -y containerd.io docker-ce docker-ce-cli 
```

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d 
```

```bash
sudo touch /etc/systemd/system/docker.service.d/http-proxy.conf
```

```bash
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF 
[Service]
Environment="HTTP_PROXY=http://10.40.56.3:8080"
Environment="HTTPS_PROXY=http://10.40.56.3:8080"
Environment="NO_PROXY=localhost,127.0.0.1,10.96.0.0/12,192.168.59.0/24,192.168.39.0/24,192.168.49.0/24,172.30.240.0/20" 
EOF
```

```bash
sudo tee /etc/docker/daemon.json <<EOF 
{ 
  "exec-opts": ["native.cgroupdriver=systemd"], 
  "log-driver": "json-file", 
  "log-opts": { 
    "max-size": "100m" 
  }, 
  "storage-driver": "overlay2" 
} 
EOF
```

```bash
sudo systemctl daemon-reload
```

```bash
sudo systemctl restart docker
```

```bash
sudo systemctl status docker
```

```bash
sudo systemctl show --property=Environment docker
```

#### 

#### 4. Ejecutar el comando Docker sin sudo (opcional)

```bash
sudo usermod -aG docker ${USER}
```

```bash
su - ${USER}
```

```bash
id -nG
```

#### 5. Inicializando el nodo maestro.

```bash
sudo systemctl enable kubelet
```

```bash
sudo kubeadm config images pull
```

```bash
sudo kubeadm init  --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address="IP DEL NODO MAESTRO"
```

#### 6. Configurando kubectl

```bash
mkdir -p $HOME/.kube
```

```bash
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
```

```bash
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### 7. Instalando plugin de red(Calico)

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

Verificamos que todos los pods se están ejecutando correctamente:

```bash
kubectl get pods --all-namespaces
```

#### 8. Agregando nodos al cluster

La salida del comando `sudo kubeadm init  --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=172.30.240.10`

nos mostrará por pantalla las instrucciones del punto `6. Configurando kubectl` y el comando que deberemos ejecutar en cada nodo `Worker` para unirlo al cluster. 

Sera algo similar a esto:

`kubeadm join 172.30.240.10:6443 --token mxnf93.vkhxapl03vvdprri \
        --discovery-token-ca-cert-hash sha256:19f9666059b6283ffa98e2061d3222f3518c0acae161f6a449e935f21dd35f7c` 

Para ver los nodos que forman parte del cluster podemos ejecutar:

```bash
kubectl get node
```

El valor de `STATUS` será `NotReady` hasta que no instalemos el plugin de red (en este caso Calico).

[Ejemplo: instalación de Calico y configuración de políticas de red](https://docs.oracle.com/es-ww/iaas/Content/ContEng/Tasks/contengsettingupcalico.htm)

# 
