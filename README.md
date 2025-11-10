# Laboratório de DataOps

## Introdução

Este repositório contém guias e configurações para criar um laboratório de DataOps utilizando Kubernetes (K3D) em sua máquina local.

O objetivo é servir como um playground para a instalação, integração e experimentação de soluções de dados, como Airflow, Langflow, MLflow e outras ferramentas do ecossistema MLOps/DataOps.

🚀 Sobre o Ambiente
Utilizamos o K3D, uma ferramenta leve para executar o k3s (uma distribuição Kubernetes leve) em Docker. Isso permite iniciar um cluster Kubernetes de forma rápida e com baixo consumo de recursos, ideal para desenvolvimento e estudos locais.

💻 Ambientes Testados
Os exemplos foram testados em Fedora Linux e Windows com WSL2 (Ubuntu), mas devem ser facilmente adaptáveis para outras distribuições Linux e macOS.

## Pré-requisitos

As ferramentas a seguir precisam ser instaladas na sua máquina local ou no ambiente WSL antes de prosseguir.

### Instalação do Docker, Helm e kubectl

O Docker é a base para executar contêineres e, consequentemente, os clusters locais com `k3d` ou `kind`.

**Fedora Desktop 43**

O método recomendado é configurar o repositório oficial do Docker para garantir que você receba as atualizações mais recentes.

```bash
# Adiciona o repositório do Docker
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo

# Instala a versão mais recente
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin --allowerasing

# Inicia e habilita o serviço do Docker
sudo systemctl start docker
sudo systemctl enable docker

# Adiciona seu usuário ao grupo do docker para executar comandos sem 'sudo'
sudo usermod -aG docker ${USER}

# Aplica as novas permissões do grupo (pode ser necessário um novo login)
newgrp docker

# Verifica a instalação
docker info

#Instalação do Helm
sudo dnf install helm
```

**Windows**

No Windows, inicialmente, precisamos instalar o Ubunto para WSL: https://ubuntu.com/desktop/wsl.

Após a instalação, é baixar e instalar o [Docker Desktop](https://www.docker.com/products/docker-desktop/), que se integra nativamente com o WSL2.

### Instalação do `kubectl`

O `kubectl` é a ferramenta de linha de comando para interagir com a API do Kubernetes. O comando abaixo funciona para qualquer distribuição Linux (incluindo Fedora e Ubuntu/WSL).

```bash
# Baixa a versão estável mais recente
curl -LO "[https://dl.k8s.io/release/$(curl](https://dl.k8s.io/release/$(curl) -L -s [https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl](https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl)"

# Torna o binário executável
chmod +x ./kubectl

# Move o binário para o seu PATH
sudo mv ./kubectl /usr/local/bin/kubectl

# Verifica a instalação
kubectl version --client
```

### Instalação do Helm

O Helm é o gerenciador de pacotes para o Kubernetes.

**Debian/Ubuntu (WSL)**

```bash
# Adiciona a chave de assinatura do Helm
curl [https://baltocdn.com/helm/signing.asc](https://baltocdn.com/helm/signing.asc) | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

# Adiciona o repositório do Helm
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] [https://baltocdn.com/helm/stable/debian/](https://baltocdn.com/helm/stable/debian/) all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

# Atualiza e instala o Helm
sudo apt-get update
sudo apt-get install helm --yes
```

### Instalação do Go

O Go é necessário para algumas ferramentas do ecossistema e para compilar projetos.

```bash
# Baixa uma versão específica (verifique a mais recente em [https://go.dev/dl/](https://go.dev/dl/))
wget https://go.dev/dl/go1.25.4.linux-amd64.tar.gz

# Remove instalações antigas e extrai a nova versão
sudo rm -rf /usr/local/go
gunzip go1.25.4.linux-amd64.tar.gz
sudo tar -C /usr/local -xvf go1.25.4.linux-amd64.tar

# Adiciona o Go ao seu PATH (essencial!)
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Verifica a instalação
go version
```

---

## Criação de Clusters

### Utilizando k3d

Para obter instruções sobre como criar um cluster com `k3d`, consulte o arquivo [k3d.md](k3d.md).

---



## Referências

* [Instalação do K3D](https://k3d.io/stable/#installation)
* [Instalação do Go (Golang)](https://go.dev/doc/install)
* [Instalação do Ubuntu no WSL](https://ubuntu.com/desktop/wsl)

<!-- end list -->
