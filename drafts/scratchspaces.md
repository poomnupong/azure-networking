# list learned route from ExpressRoute gateway in table format
az network vnet-gateway list-learned-routes --resource-group=$RGNAME --name="hub1-scus-exrgw" --query="value[].{network:network,nextHop:nextHop,origin:origin}" --output=table



# add spoke1 VNET and VMs

``` bash
REGION="southcentralus"
RGNAME="skytaplab-rg"
HUBVNET_NAME="hub1-scus-vnet"
SPOKEVNET_NAME="spoke1-scus-vnet"
SPOKEVNET_ADDRSPACE="10.2.22.0/24"
SPOKEGENSNET_NAME="genericvm1-snet"

VMSIZE="Standard_DS1_v2"
VMNAME="azurespoke1test1-vm"
VMIMAGE="ubuntults"
VMUSERNAME="azureuser"
VMPASSWORD="Azure123456$"

# create VNET and subnets
az network vnet create --resource-group=$RGNAME --location=$REGION --name=$SPOKEVNET_NAME --address-prefixes=$SPOKEVNET_ADDRSPACE

az network vnet subnet create --resource-group=$RGNAME --vnet-name=$SPOKEVNET_NAME --name=$SPOKEGENSNET_NAME --address-prefixes="10.2.22.0/27"

# peer VNET to hubs
(TODO)

# create network security group and note the public IP address in the output
az network nsg create --resource-group=$RGNAME --name="genericvm1-subn-nsg" --location=$REGION

# associate NSG to the VM subnet
az network vnet subnet update --id="$(az network vnet list --resource-group=$RGNAME --query='[?name==`'$SPOKEVNET_NAME'`].{id:subnets[0].id}' -o tsv)" --network-security-group="genericvm1-subn-nsg"

# create test VMs
az vm create --resource-group $RGNAME --name=$VMNAME --image=$VMIMAGE --public-ip-sku="Standard" --size=$VMSIZE --location=$REGION --vnet-name=$SPOKEVNET_NAME --subnet=$SPOKEGENSNET_NAME --admin-username=$VMUSERNAME --admin-password=$VMPASSWORD --nsg "" --no-wait
```


# add spoke2 VNET and VMs
```bash
SPOKE2VNET_NAME="spoke2-scus-vnet"
SPOKE2VNET_ADDRSPACE="10.2.23.0/24"
SPOKE2GENSNET_NAME="genericvm1-snet"
```