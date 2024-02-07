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

# Verifica e instala dependências, incluindo o supervisor e o Go
DEPENDENCIES=("dos2unix" "supervisord" "go")
NEED_INSTALL=()
for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v $dep &>/dev/null; then
        NEED_INSTALL+=($dep)
    else
        if [ $dep == "dos2unix" ] || [ $dep == "supervisord" ]; then
            # Para programas sem verificação de versão específica
            print_centered "$dep já está instalado."
        elif [ $dep == "go" ]; then
            go_version=$(go version | awk '{print $3}')
            print_centered "$dep já está instalado. Versão atual: $go_version."
        else
            # Para programas com verificação de versão
            current_version=$($dep -v | cut -d 'v' -f 2 | cut -d '.' -f 1)
            print_centered "$dep já está instalado. Versão atual: $current_version."
        fi
    fi
done

# Instala dependências necessárias
for dep in "${NEED_INSTALL[@]}"; do
    print_centered "Instalando $dep..."
    case $dep in
        dos2unix)
            apt install dos2unix -y
            ;;
        supervisord)
            apt install supervisor -y
            supervisor_version=$(supervisord --version | awk 'NR==1{print $NF}')
            print_centered "$dep instalado com sucesso. Versão: $supervisor_version."
            ;;
        go)
            sudo apt install golang-go -y &>/dev/null
            go_version=$(go version | awk '{print $3}')
            print_centered "$dep instalado com sucesso. Versão: $go_version."
            ;;
    esac
    progress_bar 10
done


# Verifica se o diretório /opt/myapp/ existe
if [ -d "/opt/myapp/" ]; then
    print_centered "Diretório /opt/myapp/ já existe. Parando e excluindo processo se existir..."
    sudo supervisorctl stop m-dulo &>/dev/null
    sudo supervisorctl remove m-dulo &>/dev/null
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
print_centered "Baixando github.com/gorilla/mux..."
sudo go get github.com/gorilla/mux &>/dev/null

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

go build -o /opt/myapp/m-dulo

sudo chmod +x /opt/myapp/m-dulo


# Copiar o arquivo m-dulo.conf para /etc/supervisor/conf.d
if [ -f "/opt/myapp/m-dulo.conf" ]; then
    print_centered "Copiando m-dulo.conf para /etc/supervisor/conf.d..."
    sudo cp /opt/myapp/m-dulo.conf /etc/supervisor/conf.d/
    sudo chown root:root /etc/supervisor/conf.d/m-dulo.conf
    sudo chmod 644 /etc/supervisor/conf.d/m-dulo.conf
    print_centered "Arquivo copiado com sucesso."
else
    print_centered "Arquivo m-dulo.conf não encontrado. Verifique se o arquivo existe no repositório."
fi

# Atualizar a configuração do Supervisor
sudo supervisorctl update &>/dev/null

# Iniciar o serviço
print_centered "Iniciando o modulos do painel..."
sudo supervisorctl start m-dulo &>/dev/null

progress_bar 10

print_centered "Modulos instalado com sucesso!"
