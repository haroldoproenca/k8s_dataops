# **Guia Rápido: Criando um Cluster Kubernetes com k3d**

Este guia descreve o processo de criação de um cluster Kubernetes local usando [k3d](https://k3d.io/). O k3d é uma ferramenta leve que executa o [K3s](https://k3s.io/) (uma distribuição Kubernetes mínima da Rancher) em contêineres Docker.

O cluster configurado por este guia é ideal para testes avançados, pois ele vem preparado para a instalação de um CNI (Container Network Interface) e um Ingress Controller customizados, como Cilium e NGINX Ingress.

## Pré-requisitos

Antes de começar, certifique-se de que você tem as seguintes ferramentas instaladas e configuradas em sua máquina:

* **[Docker](https://docs.docker.com/engine/install/):** Essencial para executar os nós do cluster em contêineres.
* **[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/):** A ferramenta de linha de comando para interagir com o cluster Kubernetes.

## 1\. Instalação do k3d

Você pode instalar o k3d usando o script de instalação oficial. O comando abaixo irá baixar e executar o script.

```bash
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

Após a instalação, verifique se o `k3d` foi instalado com sucesso:

```bash
k3d --version
```

## 2\. Criação do Cluster

O comando a seguir criará um cluster chamado `k8s-lab` com 1 master e 3 workers (agents).

```bash
k3d cluster create k8s-dataops --agents 3 \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:*" \
  --k3s-arg "--flannel-backend=none@server:*" \
  --k3s-arg "--disable-network-policy@server:*" \
  --k3s-arg "--cluster-cidr=192.168.0.0/16@server:*"
```

### Entendendo os Parâmetros

Vamos detalhar o que cada parâmetro do comando acima faz:

* `k3d cluster create k8s-dataops`: Cria um cluster com o nome `k8s-lab`.
* `--agents 3`: Especifica que o cluster deve ter **3 nós de agente (worker)**, além do nó de controle (master).
* `-p "80:80@loadbalancer"` e `-p "443:443@loadbalancer"`: Mapeia as portas **80 e 443** da sua máquina local (host) para o Load Balancer do k3d. Isso permite acessar serviços expostos via Ingress, como se estivessem rodando localmente.
* `--k3s-arg "--disable=traefik@server:*"`: Desabilita o **Traefik**, o Ingress Controller que vem instalado por padrão no K3s. Isso é necessário se você planeja instalar outro Ingress Controller, como NGINX, Istio ou Contour.
* `--k3s-arg '--flannel-backend=none@server:*'`: Desabilita o **Flannel**, o CNI (Container Network Interface) padrão do K3s. Esta etapa é crucial para instalar um CNI mais avançado, como **Cilium** ou **Calico**.
* `--k3s-arg '--disable-network-policy@server:*'`: Desabilita o controlador de políticas de rede padrão, já que o CNI que será instalado (ex: Cilium) será responsável por gerenciar e aplicar as Network Policies.
* `--k3s-arg '--cluster-cidr=192.168.0.0/16@server:*'`: Define um intervalo de IPs customizado para os Pods. Isso é útil para evitar conflitos de rede com a sua infraestrutura local ou outras redes Docker.

## 3\. Verificando o Cluster

Após a execução do comando de criação, o k3d automaticamente configurará seu `kubeconfig` para apontar para o novo cluster.

Para verificar se o cluster está no ar e se os nós estão prontos, use o `kubectl`:

```bash
kubectl get nodes
```

Você deverá ver uma saída semelhante a esta, com um nó `control-plane` e três `agent`:

```
NAME                       STATUS   ROLES           AGE   VERSION
k3d-k8s-lab-server-0       Ready    control-plane   1m    v1.28.x+k3s1
k3d-k8s-lab-agent-0        Ready    <none>          1m    v1.28.x+k3s1
k3d-k8s-lab-agent-1        Ready    <none>          1m    v1.28.x+k3s1
k3d-k8s-lab-agent-2        Ready    <none>          1m    v1.28.x+k3s1
```

> **Nota:** Como o Flannel foi desabilitado, os nós podem aparecer com o status `NotReady` até que um novo CNI seja instalado. Isso é esperado.

## 4\. Gerenciando o Cluster

Aqui estão alguns comandos úteis para gerenciar seu cluster k3d.

* **Listar clusters existentes:**

  ```bash
  k3d cluster list
  ```
* **Parar um cluster (sem deletar):**

  ```bash
  k3d cluster stop k8s-lab
  ```
* **Iniciar um cluster parado:**

  ```bash
  k3d cluster start k8s-lab
  ```
* **Deletar o cluster:**
  Quando não precisar mais do cluster, você pode removê-lo completamente para liberar os recursos da sua máquina.

  ```bash
  k3d cluster delete k8s-lab
  ```
