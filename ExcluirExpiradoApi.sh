#!/bin/bash

excluir_uuid_do_xray() {
    local config_file="$1"
    local uuid_para_excluir="$2"

    # Remove o cliente com o UUID informado de todos os inbounds do tipo vless
    jq '(.inbounds[] | select(.protocol == "vless") | .settings.clients) |= map(select(.id != "'$uuid_para_excluir'"))' "$config_file" > tmp_config.json && mv tmp_config.json "$config_file"
}

excluir_uuid_do_registro() {
    local registro_file="$1"
    local uuid_para_excluir="$2"

    if [ ! -f "$registro_file" ]; then
        echo "Arquivo de registro não encontrado."
        return 1
    fi

    sed -i "/$uuid_para_excluir/d" "$registro_file"
}

excluir_usuario_do_sistema() {
    local usuario="$1"

    if user_exists_by_id "$usuario"; then
        # Matar processos do usuário
        pkill -u "$usuario"

        # Deletar o usuário
        userdel "$usuario"
        echo "Usuário '$usuario' excluído do sistema."
    else
        echo "Usuário '$usuario' não existe no sistema."
    fi
}

user_exists_by_id() {
    id "$1" &>/dev/null
}

CONFIG_FILE="/usr/local/etc/xray/config.json"
REGISTRO_FILE="/root/xrayusers.db"

if [ "$#" -lt 1 ]; then
    echo "Erro: Argumentos insuficientes."
    exit 1
fi

USUARIO="$1"
UUID_PARA_EXCLUIR="$2"

if [ -z "$UUID_PARA_EXCLUIR" ]; then
    excluir_usuario_do_sistema "$USUARIO"
else
    excluir_uuid_do_xray "$CONFIG_FILE" "$UUID_PARA_EXCLUIR"
    excluir_uuid_do_registro "$REGISTRO_FILE" "$UUID_PARA_EXCLUIR"
    excluir_usuario_do_sistema "$USUARIO"
fi

# Reiniciar o serviço xray
systemctl restart xray || service xray restart
echo "Serviço Xray reiniciado."
return 0

echo "Operações concluídas com sucesso."
