ZABBIX_USER="Admin"
ZABBIX_PASS="zabbix"
ZABBIX_API="http://192.168.1.97:8080/api_jsonrpc.php"
old_IFS=$IFS
IFS=$'\n'

: ${ZABBIX_USER:=Admin}
: ${ZABBIX_PASS:=zabbix}
########################################################################################
ZABBIX_AUTH_TOKEN=$( curl -s -H  'Content-Type: application/json-rpc' -d "
{
        \"jsonrpc\": \"2.0\",
        \"method\": \"user.login\",
        \"params\": {
                \"user\": \""${ZABBIX_USER}"\",
                \"password\": \""${ZABBIX_PASS}"\"
        },
        \"auth\": null,
        \"id\": 0
}" ${ZABBIX_API} \
| jq  -r 'if .result then .result else .error.data end')

if [[ "${ZABBIX_AUTH_TOKEN}" =~ ".*Incorrect.*" ]]; then
        : ${ZABBIX_AUTH_TOKEN:="$(echo "\t\t### Sem conexão estabelecida ###\n\t\tURL : "${ZABBIX_API})"}
        echo -e ${ZABBIX_AUTH_TOKEN}
        exit 1
fi
########################################################################################
for i in $(<$1); do
    GRP_NAME=$(curl -s -H  'Content-Type: application/json-rpc' -d "
    {
        \"jsonrpc\": \"2.0\",
        \"method\": \"hostgroup.create\",
        \"params\": {
            \"name\": \""UNIDADE/BR/${i}"\"
        },
        \"auth\": \"${ZABBIX_AUTH_TOKEN}\",
        \"id\": 1
    }" ${ZABBIX_API})
echo -e "\e[33mCriando grupo $i\e[0m"
    echo -n "$i: "
    echo $GRP_NAME | jq -r 'if has("result") then "criado com sucesso ID - \(.result.groupids[0])" elif .error.data | contains("already exists") then "WARNING grupo já existe " else "ERROR grupo não foi criado" end'
echo -e "\e[33m<------------------------->\e[0m"

    GRP_ID=$(echo $GRP_NAME | jq -r '.result? | .groupids[0] // empty')

    if [ -z "$GRP_ID" ]; then
	:
        continue
    fi

    ########################################################################################
    HOSTID=$(curl -s -H  'Content-Type: application/json-rpc' -d "
    {
        \"jsonrpc\": \"2.0\",
        \"method\": \"host.get\",
        \"params\": {
            \"output\": [\"hostid\"],
            \"selectTags\": \"extend\",
            \"evaltype\": 0,
            \"tags\": [
                {
                    \"tag\": \"unidade\",
                    \"value\": \""$i"\",
                    \"operator\": 1
                }
            ]
        },
        \"auth\": \"${ZABBIX_AUTH_TOKEN}\",
        \"id\": 1
    }" ${ZABBIX_API} | jq -r .result[].hostid)

    for j in $(echo "${HOSTID}"); do
HOST_ADDED=$(curl -s -H  'Content-Type: application/json-rpc' -d "
{
  \"jsonrpc\": \"2.0\",
  \"method\": \"hostgroup.massadd\",
  \"params\": {
    \"groups\": [
      {
        \"groupid\": \"${GRP_ID}\"
      }
    ],
    \"hosts\": [
      {
        \"hostid\": \"${j}\"
      }
    ]
  },
 \"auth\": \"${ZABBIX_AUTH_TOKEN}\",
        \"id\": 1
}" ${ZABBIX_API})

echo -e "\e[34mAdicionando host ao grupo\e[0m"
echo -n "Host de ID: ${j}" ;echo $HOST_ADDED | jq -r 'if .result.groupids[0] != "" then " adicionado ao grupo ID: \(.result.groupids[0])" else "ERROR" end'
echo -e "\e[34m<------------------------->\e[0m"

    done
done

IFS=${old_IFS}
