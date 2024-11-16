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

DEPENDENCIES=("dos2unix" "go")
NEED_INSTALL=()

for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v $dep &>/dev/null; then
        NEED_INSTALL+=($dep)
    else
        if [ $dep == "dos2unix" ]; then
            # Verificação para o "dos2unix", sem versão específica
            print_centered "$dep já está instalado."
        elif [ $dep == "go" ]; then
            # Mostra a saída completa do comando go version
            go_version=$(go version)
            print_centered "$dep já está instalado. $go_version"
        else
            # Para outros programas, caso haja versão
            current_version=$($dep -v | cut -d ' ' -f 2 | cut -d '.' -f 1)
            print_centered "$dep já está instalado. Versão atual: $current_version."
        fi
    fi
done

# Dependências a serem instaladas
NEED_INSTALL=("dos2unix" "go")

# Instala dependências necessárias
for dep in "${NEED_INSTALL[@]}"; do
    print_centered "Instalando $dep..."
    
    case $dep in
        dos2unix)
            sudo apt install dos2unix -y
            ;;
        go)
            sudo apt install golang-go -y &>/dev/null
            
            # Verificando a versão do Go
            go_version=$(go version 2>/dev/null)
            if [ $? -ne 0 ]; then
                print_centered "Erro ao verificar a versão do Go. O Go pode não estar instalado corretamente."
            else
                print_centered "$dep instalado com sucesso. Versão: $go_version."
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
sudo go mod init m-dulo &>/dev/null



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

go build -o /opt/myapp/m-dulo /opt/myapp/m-dulo.go


sudo chmod +x /opt/myapp/m-dulo


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