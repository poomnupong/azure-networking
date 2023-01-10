RGNAME="dev3-skytaplztype1-scus-rg"
REGION="southcentralus"
az group create --name=$RGNAME --location=$REGION
az deployment group create \
--name=deployment1 \
--resource-group=$RGNAME \
--template-file="skytaplz-type1.bicep" \
--parameters VM_PASSWORD='Azure123456$' DEPLOY_VPNGW=false DEPLOY_EXRGW=false DEPLOY_ROUTESERVER=false \
--mode=complete --no-wait
