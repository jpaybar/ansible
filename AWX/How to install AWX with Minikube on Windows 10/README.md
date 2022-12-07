# Como instalar AWX con Minikube en Windows 10

###### By Juan Manuel Payán / jpaybar

st4rt.fr0m.scr4tch@gmail.com



Basado en la guia de instalación oficial bajo GNU/Linux y adaptado para Windows 10.

https://github.com/ansible/awx-operator

## ¿Qué es AWX?

`AWX` es una aplicación web de código abierto que proporciona una interfaz de usuario, una API REST y un motor de tareas para `Ansible`. Es la versión de código abierto de `Ansible Tower`. `AWX` te permite gestionar los `playbooks de Ansible`, los `inventarios` y `programar trabajos` para que se ejecuten mediante la interfaz web.

[GitHub - ansible/awx: AWX provides a web-based user interface, REST API, and task engine built on top of Ansible. It is one of the upstream projects for Red Hat Ansible Automation Platform.](https://github.com/ansible/awx)

[Red Hat Ansible Tower - Red Hat Customer Portal](https://access.redhat.com/products/ansible-tower-red-hat)

## ¿Qué es Minikube?

`Minikube` es una herramienta que facilita la ejecución local de `Kubernetes` en un `cluster de un solo nodo` dentro de una Máquina Virtual (por ejemplo, `Virtualbox`) en un entorno de desarrollo local. Está orientado a los desarrolladores que buscan probar aplicaciones para Kubernetes o Administradores de Sistemas que quieren tener una primera toma de contacto y ver su funcionamiento.

[minikube start | minikube](https://minikube.sigs.k8s.io/docs/start/)

##### Requisitos:

- Host, Windows 10 (20H2 version) x64, Intel(R) Core(TM) i5 3.10GHz, 16GB RAM, 256GB SSD Disk
- VirtualBox 6.1.28 
- Minikube version: v1.28.0
- Kubectl Version: v1.25.3 (Opcional)
- Chocolatey v1.2.0
- Kustomize Version: v4.5.7
- git version 2.38.1.windows.1



## Instalación de Minikube:

La instalación ejecutará una máquina virtual de `VirtualBox` y arrancará una versión de `GNU/Linux` con `Docker` instalado después levantará un container con la versión de `Minikube` (kubernetes simplificado de un solo nodo).

https://minikube.sigs.k8s.io/docs/start/

Creamos un directorio en `C:\` llamado `minikube` y descargamos los ejecutables `minikube.exe` y `kubectl.exe`, además añadiremos el Path a la variable de entorno.

```powershell
New-Item -Path 'c:\' -Name 'minikube' -ItemType Directory -Force
```

```powershell
Invoke-WebRequest -OutFile 'c:\minikube\minikube.exe' -Uri 'https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe' -UseBasicParsing
```

```powershell
Invoke-WebRequest -OutFile 'c:\minikube\kubectl.exe' -Uri 'https://dl.k8s.io/release/v1.25.0/bin/windows/amd64/kubectl.exe' -UseBasicParsing
```

```powershell
$oldPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine)
if ($oldPath.Split(';') -inotcontains 'C:\minikube'){ `
  [Environment]::SetEnvironmentVariable('Path', $('{0};C:\minikube' -f $oldPath), [EnvironmentVariableTarget]::Machine) `
}
```

Será necesario abrir una nueva consola de `Powershell` para refrescar el Path.

##### **NOTA:**

No es necesario que `kubectl` se instale por separado, ya que viene envuelto dentro de `minikube`. Prefijamos `minikube kubectl --` antes del comando `kubectl`, es decir, `kubectl get nodes` se convertiría en `minikube kubectl -- get nodes`

También podemos crear un alias (Windows):

[Alias de la consola - Windows Console | Microsoft Learn](https://learn.microsoft.com/es-es/windows/console/console-aliases)



## Creamos el cluster de Minikube:

Si estamos detrás de un proxy fallará la descarga e instalación de la máquina virtual, por lo tanto, primero deberemos añadir las variables `http_proxy` a nuestro entorno:

Ejecutar en una `Powershell`:

```powershell
$ENV:http_proxy="http://your.proxy.here:8080"
$ENV:https_proxy="http://your.proxy.here:8080"
```

Iniciamos el cluster (podemos modificar la cantidad de `cpus` y `memoria`):

```powershell
minikube start --memory 6g --cpus 4 --addons=ingress
```

De esta forma se podrá descargar la imágen y arrancar la MV en `VirtualBox`, pero no se podrá configurar el cluster. Durante la instalación aparecerá un simbolo de exclamacion rojo que nos informará que la dirección IP del Nodo no está excluida del Proxy.

❗  You appear to be using a proxy, but your NO_PROXY environment does not include the minikube IP (192.168.59.105). LA IP VARIARÁ SEGÚN CREEMOS EL CLUSTER.

Ejecutar en una `Powershell`:

```powershell
$ENV:no_proxy="192.168.59.105"
```

Una vez que hemos añadido la variable de entorno excluyendo la ip del cluster `minikube`, paramos el cluster y lo volvemos a iniciar:

```powershell
minikube stop
minikube start
```

Para ver la lista de comandos:

```powershell
minikube help
```

Si nos aparece alguna advertencia por haber descargado una versión de `kubectl` incompatible, solo debemos descargar la versión que nos pida.

❗  C:\minikube\kubectl.exe is version 1.25.0, which may have incompatibilities with Kubernetes 1.23.3.
    ▪ Want kubectl v1.23.3? Try 'minikube kubectl -- get pods -A'



Una vez que se implementa `Minikube`, verificamos si los `nodos` y la comunicación con `kube-apiserver` funcionan correctamente. Para ello ejecutamos:

```powershell
minikube kubectl -- get nodes
```

Y veremos una salida por consola similar a la siguiente:

```powershell
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   12m   v1.25.3
```

Comprobamos `Kube-apiserver`:

```powershell
minikube kubectl -- get pods -A
```

y la salida será similar:

```powershell
NAMESPACE       NAME                                        READY   STATUS      RESTARTS        AGE
ingress-nginx   ingress-nginx-admission-create-m2f8t        0/1     Completed   0               13m
ingress-nginx   ingress-nginx-admission-patch-km6hk         0/1     Completed   0               13m
ingress-nginx   ingress-nginx-controller-5959f988fd-6zj8m   1/1     Running     1 (6m58s ago)   13m
kube-system     coredns-565d847f94-hwnms                    1/1     Running     1 (6m58s ago)   13m
kube-system     etcd-minikube                               1/1     Running     1 (6m58s ago)   13m
kube-system     kube-apiserver-minikube                     1/1     Running     1 (6m57s ago)   13m
kube-system     kube-controller-manager-minikube            1/1     Running     1 (6m58s ago)   13m
kube-system     kube-proxy-gvspl                            1/1     Running     1 (6m58s ago)   13m
kube-system     kube-scheduler-minikube                     1/1     Running     1 (6m58s ago)   13m
kube-system     storage-provisioner                         1/1     Running     1 (6m58s ago)   13m
```

## Instalación de AWX (awx-operator)

Una vez que tengamos el clúster de Kubernetes en ejecución, podemos implementar AWX Operator mediante `Kustomize`. Siga las instrucciones aquí para instalar la última versión de Kustomize:

 https://kubectl.docs.kubernetes.io/installation/kustomize/

Hay varias opciones de instalación en este caso trabajamos con Windows 10 por lo que la haremos con `Chocolately`. `Chocolately` es un gestor de paquetes de línea de comandos para `Microsoft Windows`. Utiliza la infraestructura de empaquetado de `NuGet`y `PowerShell` para simplificar el proceso de descarga e instalación de software.



#### Instalamos primero `Chocolately`:

1.- Inicio y escribimos `powershell`.
2.- Hacemos clic derecho en `Windows Powershell` y elegimos `Ejecutar como administrador`.
3.- Pegamos el siguiente comando en `Powershell` y presionamos enter.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; `
  iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
```

4.- Respondemos Sí cuando se nos solicite.
5.- Cerramos y volvemos a abrir una ventana de `PowerShell` elevada para comenzar a usar `Chocolately`.

#### Instalación de `Kustomize` con `Chocolately`:

`Kustomize` es una herramienta que nos permitira hacer modificaciones en nuestro cluster de `Kubernetes` usando ficheros YAML. Esta herramienta está enfocada a `K8s`. Esto significa que entiende y modifica objetos del API de `K8s` siguiendo el mismo estilo.

[Kustomize | SIG CLI](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/)

Instalamos `kustomize` con el gestor de paquetes `Chocolately`:

```powershell
choco install kustomize
```

y veremos la siguiente salida por consola, indicandonos que se ha realizado la instalación:

```powershell
Environment Vars (like PATH) have changed. Close/reopen your shell to
 see the changes (or in powershell/cmd.exe just type `refreshenv`).
 The install of kustomize was successful.
  Software installed to 'C:\ProgramData\chocolatey\lib\kustomize\tools'

Chocolatey installed 1/1 packages.
 See the log for details (C:\ProgramData\chocolatey\logs\chocolatey.log).
```

#### Instalamos `git for Windows` :

Simplemente descargamos el ejecutable y lo instalamos.

[Git for Windows](https://gitforwindows.org/index.html)



#### Configuración e Instalación de `AWX` con `kustomize`

[GitHub - ansible/awx-operator: An Ansible AWX operator for Kubernetes built with Operator SDK and Ansible. 🤖](https://github.com/ansible/awx-operator#basic-install)

Como hemos comentado más arriba `kustomize` es una herramienta que nos permite modificar `kubernetes` usando ficheros `YAML`.

Para ello creamos un archivo principal llamado `kustomization.yaml` con el siguiente contenido:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  # Find the latest tag here: https://github.com/ansible/awx-operator/releases
  - github.com/ansible/awx-operator/config/default?ref=<tag>

# Set the image tags to match the git version from above
images:
  - name: quay.io/ansible/awx-operator
    newTag: <tag>

# Specify a custom namespace in which to install AWX
namespace: awx
```

Como nos indican los comentarios del fichero `YAML` debemos de especificar la versión de `awx-operator` en la etiqueta `<tag>`. Podemos encontrar las versiones en la url que nos indica:

https://github.com/ansible/awx-operator/releases

Usaremos la versión `1.1.0` y nuestro fichero `kustomization.yaml` quedaría así:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  # Find the latest tag here: https://github.com/ansible/awx-operator/releases
  - github.com/ansible/awx-operator/config/default?ref=1.1.0

# Set the image tags to match the git version from above
images:
  - name: quay.io/ansible/awx-operator
    newTag: 1.1.0

# Specify a custom namespace in which to install AWX
namespace: awx
```

Ejectuamos nuestro fichero con `kustomize` y `kubectl` aplica la modificación:

```powershell
kustomize build . | kubectl apply -f -
```

Verificamos que el `controller-manager` de `awx-operator` se está ejecutando:

```powershell
kubectl get pods -n awx
```

Configuramos el `namespace` como `awx`:

```powershell
kubectl config set-context --current --namespace=awx
```

Por último, creamos un archivo llamado `awx-demo.yaml` en la misma carpeta, el cual levantará el servicio en el puerto que le indiquemos:

```yaml
---
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-demo
spec:
  service_type: nodeport
  # default nodeport_port is 30080
  nodeport_port: <nodeport_port>
```

Configuramos el puerto, por defecto es el `30080` como nos muestra el comentario en la directiva `nodeport_port` quedando de la siguiente forma:

```yaml
nodeport_port: 30080
```

Agregamos el nuevo fichero que levantará el servicio a la directiva `resources` de nuestro archivo `kustomization.yaml` que quedaría de la siguiente forma:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  # Find the latest tag here: https://github.com/ansible/awx-operator/releases
  - github.com/ansible/awx-operator/config/default?ref=1.1.0
  # Add this extra line:
  - awx-demo.yaml

# Set the image tags to match the git version from above
images:
  - name: quay.io/ansible/awx-operator
    newTag: 1.1.0

# Specify a custom namespace in which to install AWX
namespace: awx
```

Finalmente, ejecutamos `kustomize` nuevamente para crear la instancia `AWX` en nuestro clúster:

```powershell
kustomize build . | kubectl apply -f -
```

Después de unos minutos, se implementará la nueva instancia de `AWX`. Podemos consultar los `logs` del `pod` de `operator` para ver en que estado está el proceso de instalación:

```powershell
kubectl logs -f deployments/awx-operator-controller-manager -c awx-manager
```

Una vez que terminen de ejecutarse todas las tareas, se nos mostrará un resumen de la misma forma que al correr un playbook de Ansible. Después de unos segundos, deberíamos ver que `operator` comienza a crear nuevos recursos:

```powershell
kubectl get pods -l "app.kubernetes.io/managed-by=awx-operator"
NAME                        READY   STATUS    RESTARTS   AGE
awx-demo-77d96f88d5-pnhr8   4/4     Running   0          3m24s
awx-demo-postgres-0         1/1     Running   0          3m34s

kubectl get svc -l "app.kubernetes.io/managed-by=awx-operator"
NAME                TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
awx-demo-postgres   ClusterIP   None           <none>        5432/TCP       4m4s
awx-demo-service    NodePort    10.109.40.38   <none>        80:31006/TCP   3m56s
```

Una vez implementado, se podrá acceder a la `URL` de la instancia de `AWX` ejecutando:

```powershell
minikube service -n awx awx-demo-service --url
```

```powershell
http://192.168.59.110:30080
```



#### Redireccionamiento de puertos en `VirtualBox`

Para mayor comodidad, podemos agregar una regla en el adaptador `NAT` de `VirtualBox` que redireccione dicha `URL` al puerto 80, de la siguiente forma:

```
Nombre    Protocolo    IP Anfitrion    Puerto Anfitrión    Ip Invitado    Puerto Invitado
awc        TCP            127.0.0.1        80                               30080     
```

Ahora podremos acceder a `AWX` escribiendo:

```powershell
http://localhost
```

![AWX_console.PNG](https://github.com/jpaybar/Ansible/blob/main/AWX/How%20to%20install%20AWX%20with%20Minikube%20on%20Windows%2010/_images/AWX_console.PNG)

De forma predeterminada, el usuario administrador es `admin` y la contraseña está disponible en `<resourcename>-admin-password`. Para obtener la contraseña de administrador, ejecutaremos:

```powershell
$PASSWD=kubectl get secret awx-demo-admin-password -o jsonpath="{.data.password}"; $DECODED=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($PASSWD)); echo $DECODED > passwd.txt
```

Dicho comando obtiene la `password` del cluster en `base64`, la decodifica a `UTF-8` y la guarda en un fichero de texto llamado `passwd.txt`



## Author Information

Juan Manuel Payán Barea    (IT Technician) [st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

[jpaybar (Juan M. Payán Barea) · GitHub](https://github.com/jpaybar)

https://es.linkedin.com/in/juanmanuelpayan
