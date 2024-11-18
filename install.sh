#!/bin/bash

# Verifica se o script está sendo executado como root
if [[ $EUID -ne 0 ]]; then
    echo "Este script deve ser executado como root"
    exit 1
fi

# Função para centralizar texto
print_centered() {
    term_width=$(tput cols)
    text="$1"
    padding=$(( (term_width - ${#text}) / 2 ))
    printf "%${padding}s" '' # Adiciona espaços antes do texto
    echo "$text"
}

# Função para simular uma barra de progresso
progress_bar() {
    local total_steps=$1
    local current_step=0

    echo -n "Progresso: ["
    while [ $current_step -lt $total_steps ]; do
        echo -n "#"
        ((current_step++))
        sleep 0.1
    done
    echo "] Completo!"
}

DEPENDENCIES=("dos2unix" "unzip" "wget")
NEED_INSTALL=()

GO_URL="https://go.dev/dl/go1.21.1.linux-arm64.tar.gz"
GO_INSTALL_DIR="/usr/local"
GO_BINARY="/usr/local/go/bin/go"

for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v $dep &>/dev/null; then
        NEED_INSTALL+=($dep)
    else
        if [ $dep == "dos2unix" ]; then
            print_centered "$dep já está instalado."
        elif [ $dep == "unzip" ] || [ $dep == "wget" ]; then
            print_centered "$dep já está instalado."
        fi
    fi
done

# Verificar se o Go está instalado e na versão correta
if command -v go &>/dev/null; then
    current_go_version=$(go version | awk '{print $3}')
    if [ "$current_go_version" != "go1.21.1" ]; then
        print_centered "Atualizando Go para a versão 1.21.1..."
        NEED_INSTALL+=("go")
    else
        print_centered "Go já está instalado na versão correta: $current_go_version."
    fi
else
    print_centered "Go não está instalado."
    NEED_INSTALL+=("go")
fi

# Instala dependências necessárias
for dep in "${NEED_INSTALL[@]}"; do
    print_centered "Instalando $dep..."
    case $dep in
        dos2unix)
            sudo apt install dos2unix -y
            ;;
        unzip)
            sudo apt install unzip -y
            ;;
        wget)
            sudo apt install wget -y
            ;;
        go)
            # Baixar e instalar o Go manualmente
            wget -q "$GO_URL" -O /tmp/go.tar.gz
            sudo tar -C "$GO_INSTALL_DIR" -xzf /tmp/go.tar.gz
            rm /tmp/go.tar.gz
            
            # Adicionar Go ao PATH
            if ! grep -q "/usr/local/go/bin" <<<"$PATH"; then
                echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.profile
                source ~/.profile
            fi
            
            if [ -f "$GO_BINARY" ]; then
                go_version=$("$GO_BINARY" version 2>/dev/null)
                print_centered "Go instalado com sucesso. Versão: $go_version."
            else
                print_centered "Erro ao instalar o Go."
            fi
            ;;
    esac
    progress_bar 10
done




# Verifica se o diretório /opt/myapp/ existe
if [ -d "/opt/myapp/" ]; then
    print_centered "Diretório /opt/myapp/ já existe. Parando e desabilitando o serviço se existir..."
    sudo systemctl stop m-dulo.service &>/dev/null
    sudo systemctl disable m-dulo.service &>/dev/null
    sudo systemctl daemon-reload &>/dev/null
    
    print_centered "Excluindo arquivo de configuração do serviço..."
    sudo rm -f /etc/systemd/system/m-dulo.service
    
    print_centered "Recarregando daemon do systemd..."
    sudo systemctl daemon-reload &>/dev/null
    
    print_centered "Excluindo arquivos e pastas antigos..."
    sudo rm -rf /opt/myapp/
else
    print_centered "Diretório /opt/myapp/ não existe. Criando..."
fi

# Criar o diretório para o aplicativo
sudo mkdir -p /opt/myapp/


# Baixar o ZIP do repositório ModulosPro diretamente no diretório /opt/myapp/
print_centered "Baixando m-dulo-Go.zip..."
sudo wget --timeout=30 -P /opt/myapp/ https://github.com/sshturbo/m-dulo-Go/raw/main/m-dulo-Go.zip &>/dev/null

# Extrair o ZIP diretamente no diretório /opt/myapp/ e remover o arquivo ZIP após a extração
print_centered "Extraindo arquivos..."
sudo unzip /opt/myapp/m-dulo-Go.zip -d /opt/myapp/ &>/dev/null && sudo rm /opt/myapp/m-dulo-Go.zip
progress_bar 5

# Baixar o pacote github.com/gorilla/mux
print_centered "instalando dependicias"
cd /opt/myapp 

sudo go mod init m-dulo

sudo go build -o m-dulo m-dulo.go

sudo chmod +x m-dulo

# Dar permissão de execução para scripts .sh e converter para o formato Unix
print_centered "Atualizando permissões..."
files=(
    "SshturboMakeAccount.sh"
    "ExcluirExpiradoApi.sh"
    "killuser.sh"
)

for file in "${files[@]}"; do
    sudo chmod +x /opt/myapp/"$file"
    dos2unix /opt/myapp/"$file" &>/dev/null
done


if [ -f "/opt/myapp/m-dulo.service" ]; then
    print_centered "Copiando m-dulo.service para /etc/systemd/system/"
    sudo cp /opt/myapp/m-dulo.service /etc/systemd/system/
    sudo chown root:root /etc/systemd/system/m-dulo.service
    sudo chmod 644 /etc/systemd/system/m-dulo.service
    print_centered "Arquivo copiado com sucesso."
else
    print_centered "Arquivo m-dulo.service não encontrado. Verifique se o arquivo existe no repositório."
fi

# Atualizar a configuração do systemctl
sudo systemctl daemon-reload &>/dev/null

# Iniciar o serviço
print_centered "Iniciando o modulos do painel..."
sudo systemctl start m-dulo.service &>/dev/null
sudo systemctl enable m-dulo.service &>/dev/null

progress_bar 10

print_centered "Modulos instalado com sucesso!"