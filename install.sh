#!/bin/bash

# Verifica se o script está sendo executado como root
if [[ $EUID -ne 0 ]]; then
    echo "Este script deve ser executado como root"
    exit 1
fi

# Função para centralizar texto
print_centered() {
    printf "%*s\n" $(((${#1} + $(tput cols)) / 2)) "$1"
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

GO_URL="https://go.dev/dl/go1.23.3.linux-amd64.tar.gz"
GO_INSTALL_DIR="/usr/local"
GO_BINARY="/usr/local/go/bin/go"
GO_VERSION_EXPECTED="go1.23.3"

# Verificar dependências
for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v $dep &>/dev/null; then
        NEED_INSTALL+=($dep)
    else
        print_centered "$dep já está instalado."
    fi
done

# Verificar se o Go está instalado e na versão correta
if [ -x "$GO_BINARY" ]; then
    current_go_version=$("$GO_BINARY" version | awk '{print $3}')
    if [ "$current_go_version" != "$GO_VERSION_EXPECTED" ]; then
        print_centered "Atualizando Go para a versão $GO_VERSION_EXPECTED..."
        NEED_INSTALL+=("go")
    else
        print_centered "Go já está instalado na versão correta: $current_go_version."
    fi
else
    print_centered "Go não está instalado ou o binário não foi encontrado em $GO_BINARY."
    NEED_INSTALL+=("go")
fi

# Instalar dependências necessárias
for dep in "${NEED_INSTALL[@]}"; do
    print_centered "Instalando $dep..."
    case $dep in
        dos2unix)
            apt install -y dos2unix
            ;;
        unzip)
            apt install -y unzip
            ;;
        wget)
            apt install -y wget
            ;;
        go)
            # Baixar e instalar o Go manualmente
            wget -q "$GO_URL" -O /tmp/go.tar.gz
            tar -C "$GO_INSTALL_DIR" -xzf /tmp/go.tar.gz
            rm /tmp/go.tar.gz

            # Adicionar Go ao PATH
            if ! grep -q "/usr/local/go/bin" ~/.profile; then
                echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.profile
            fi
            export PATH=$PATH:/usr/local/go/bin

            # Confirmar a instalação
            if [ -x "$GO_BINARY" ]; then
                go_version=$("$GO_BINARY" version | awk '{print $3}')
                if [ "$go_version" == "$GO_VERSION_EXPECTED" ]; then
                    print_centered "Go instalado com sucesso. Versão: $go_version."
                else
                    print_centered "Erro: versão instalada ($go_version) não corresponde à esperada ($GO_VERSION_EXPECTED)."
                fi
            else
                print_centered "Erro ao instalar o Go."
            fi
            ;;
    esac
done


# Configuração do diretório /opt/myapp/
if [ -d "/opt/myapp/" ]; then
    print_centered "Diretório /opt/myapp/ já existe. Excluindo antigo..."
    systemctl stop m-dulo.service &>/dev/null
    systemctl disable m-dulo.service &>/dev/null
    systemctl daemon-reload &>/dev/null
    rm -rf /opt/myapp/
fi

mkdir -p /opt/myapp/

# Baixar e configurar o repositório
print_centered "Baixando m-dulo-Go.zip..."
wget --timeout=30 -P /opt/myapp/ https://github.com/sshturbo/m-dulo-Go/raw/main/m-dulo-Go.zip &>/dev/null

print_centered "Extraindo arquivos..."
unzip /opt/myapp/m-dulo-Go.zip -d /opt/myapp/ &>/dev/null && rm /opt/myapp/m-dulo-Go.zip
progress_bar 5

# Configurar e compilar o projeto Go
print_centered "Instalando dependências do projeto..."
cd /opt/myapp 
/usr/local/go/bin/go mod init m-dulo &>/dev/null
/usr/local/go/bin/go build -o m-dulo m-dulo.go

chmod +x m-dulo

# Atualizar permissões de scripts auxiliares
print_centered "Atualizando permissões..."
for file in "SshturboMakeAccount.sh" "ExcluirExpiradoApi.sh" "killuser.sh"; do
    chmod +x /opt/myapp/"$file"
    dos2unix /opt/myapp/"$file" &>/dev/null
done

# Configurar serviço systemd
if [ -f "/opt/myapp/m-dulo.service" ]; then
    print_centered "Configurando serviço systemd..."
    cp /opt/myapp/m-dulo.service /etc/systemd/system/
    chown root:root /etc/systemd/system/m-dulo.service
    chmod 644 /etc/systemd/system/m-dulo.service
    systemctl daemon-reload
    systemctl enable m-dulo.service
    systemctl start m-dulo.service
else
    print_centered "Erro: Arquivo m-dulo.service não encontrado."
    exit 1
fi

progress_bar 10
print_centered "Modulos instalado e configurado com sucesso!"