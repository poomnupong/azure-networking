// generic hub vnet template
// able to host any common hub components
// - ExpressRoute, VPN Gateways
// - Route Server
// - Azure Firewall
// - Bastion

// samples:
// param siteName string = 'site${uniqueString(resourceGroup().id)}'
// param hostingPlanName string = '${siteName}-plan'

// *** deploy command:
// RGNAME="dev-skytaplz1-rg"
// az group create --name=$RGNAME --location="southcentralus"
// az deployment group create --name=deployment1 --resource-group=$RGNAME --template-file="skytaplzv1-deploy.bicep" --mode=complete

param REGION string = 'southcentralus'
// shorten southcentralus because it's too long
var REGION_SUFFIX = REGION == 'southcentralus' ? 'scus' : REGION
param DEPLOY_VPNGW bool = true
param DEPLOY_EXRGW bool = true
param DEPLOY_ROUTESERVER bool = true
param VM_USERNAME string = 'azureuser'
@secure()
param VM_PASSWORD string
param HOME_PUBIP string = '99.70.225.17'
param VNET_PREFIX string = 'skytaplz1'
param VNET_ADDRSPACE array = [ '10.2.27.0/24' ]
param VNET_SUBNET_ARRAY array = [
  {
    name: 'general1-snet'
    addressPrefix: '10.2.27.0/28'
  }
  {
    name: 'nvaoutside-snet'
    addressPrefix: '10.2.27.32/28'
  }
  {
    name: 'nvainside-snet'
    addressPrefix: '10.2.27.48/28'
  }
  {
    name: 'AzureFirewallSubnet'
    addressPrefix: '10.2.27.128/26'
  }
  {
    name: 'RouteServerSubnet'
    addressPrefix: '10.2.27.192/27'
  }
  {
    name: 'GatewaySubnet'
    addressPrefix: '10.2.27.224/27'
  }
]

// vnet1
resource vnet1 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: '${VNET_PREFIX}-${REGION_SUFFIX}-vnet'
  location: REGION
  properties: {
    addressSpace: {
      addressPrefixes: VNET_ADDRSPACE
    }
    // subnets: VNET_SUBNET_ARRAY
    subnets: [ for ITEM in VNET_SUBNET_ARRAY : {
      name: ITEM.name
      properties: { addressPrefix: ITEM.addressPrefix }
    }]
  }
}

// vpn gateway / public IP addresses, need 2x for active-active mode with route server
resource vpngwPip1 'Microsoft.Network/publicIPAddresses@2019-11-01' = if (DEPLOY_VPNGW) {
  name: '${VNET_PREFIX}-${REGION_SUFFIX}-vpngw-pip1'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}
resource vpngwPip2 'Microsoft.Network/publicIPAddresses@2019-11-01' = if (DEPLOY_VPNGW) {
  name: '${VNET_PREFIX}-${REGION_SUFFIX}-vpngw-pip2'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// vpn gateway
resource vpngw 'Microsoft.Network/virtualNetworkGateways@2020-11-01' = if (DEPLOY_VPNGW) {
  name: '${VNET_PREFIX}-${REGION_SUFFIX}-vpngw'
  location: REGION
  properties: {
    bgpSettings: {
      asn: 65027
    }
    activeActive: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet1.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: vpngwPip1.id
          }
        }
      }
      {
        name: 'ipconfig2'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet1.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: vpngwPip2.id
          }
        }
      }
    ]
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: true
  }
}

// azure route server / public ip
resource routeServer1Pip 'Microsoft.Network/publicIPAddresses@2019-11-01' = if (DEPLOY_ROUTESERVER) {
  name: '${VNET_PREFIX}-${REGION_SUFFIX}-ars-pip'
  location: REGION
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// azure route server
resource routeServer1 'Microsoft.Network/virtualHubs@2021-02-01' = if (DEPLOY_ROUTESERVER) {
  name: '${VNET_PREFIX}-${REGION_SUFFIX}-ars'
  location: REGION
  dependsOn: [
    vnet1
  ]
  properties: {
    sku: 'Standard'
    allowBranchToBranchTraffic: true
  }
}

// azure route server / ip config
resource routeServer1IPConfig 'Microsoft.Network/virtualHubs/ipConfigurations@2022-05-01' = if (DEPLOY_ROUTESERVER) {
  name: 'ipconfig1'
  parent: routeServer1
  properties: {
    subnet: {
      id: '${vnet1.id}/subnets/RouteServerSubnet'
    }
    publicIPAddress: {
      id: routeServer1Pip.id
    }
  }
}

// expressroute gateway / public ip
resource exrgwPip 'Microsoft.Network/publicIPAddresses@2019-11-01' = if (DEPLOY_EXRGW) {
  name: '${VNET_PREFIX}-${REGION_SUFFIX}-exrgw-pip'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// expressroute gateway
resource exrgw 'Microsoft.Network/virtualNetworkGateways@2020-11-01' = if (DEPLOY_EXRGW) {
  name: '${VNET_PREFIX}-${REGION_SUFFIX}-exrgw'
  location: REGION
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet1.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: exrgwPip.id
          }
        }
      }
    ]
    sku: {
      name: 'Standard'
      tier: 'Standard'
    }
    gatewayType: 'ExpressRoute'
    vpnType: 'PolicyBased'
    enableBgp: true
  }
}

//=== continue with nva from here:
// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/virtualhubs?pivots=deployment-language-bicep

// nva-vm / public ip
resource nva1VmPip 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: 'nva1-${REGION_SUFFIX}-vm-pip'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// nva-vm / nsg
resource nva1VmNsg 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: 'nva1-${REGION_SUFFIX}-vm-nsg'
  location: REGION
  properties: {
    securityRules: [
      {
        name: 'allow-ssh-hq'
        properties: {
          description: 'allow-ssh'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: HOME_PUBIP
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// nva-vm / nic1
resource nva1VmNic1 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'nva1-${REGION_SUFFIX}-vm-nic1'
  location: REGION
  properties: {
    enableIPForwarding: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet1.id}/subnets/nvaoutside-snet'
          }
          publicIPAddress: {
            id: nva1VmPip.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nva1VmNsg.id
    }
  }
}

// nva-vm / nic2
resource nva1VmNic2 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'nva1-${REGION_SUFFIX}-vm-nic2'
  location: REGION
  properties: {
    enableIPForwarding: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet1.id}/subnets/nvainside-snet'
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nva1VmNsg.id
    }
  }
}

// nva-vm 
resource nva1Vm 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'nva1-${REGION_SUFFIX}-vm'
  location: REGION
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2ds_v4'
    }
    osProfile: {
      computerName: 'skytaplz-nva1'
      adminUsername: VM_USERNAME
      adminPassword: VM_PASSWORD
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'nva1-${REGION_SUFFIX}-vm-disk0'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nva1VmNic1.id
          properties: {
            primary: true
          }
        }
        {
          id: nva1VmNic2.id
          properties: {
            primary: false
          }
        }
      ]
    }
    // diagnosticsProfile: {
    //   bootDiagnostics: {
    //     enabled: true
    //     storageUri: 'storageUri'
    //   }
    // }
  }
}

//===== Start configuration =====
//===============================

//=== BGP peering from Route Server
resource routeServer1BGPConnection 'Microsoft.Network/virtualHubs/bgpConnections@2022-07-01' = if (DEPLOY_ROUTESERVER) {
  name: 'nva1-bgpconn'
  parent: routeServer1
  properties: {
    peerAsn: 65027
    peerIp: nva1VmNic2.properties.ipConfigurations[0].properties.privateIPAddress
  }
  dependsOn: [
    routeServer1IPConfig
  ]
}

//=== install and configure FRR on nva
resource nva1linuxVMExtensions 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: nva1Vm
  name: 'nva1-${REGION_SUFFIX}-vm-extension'
  location: REGION
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      skipDos2Unix: true
      fileUris: [
        'fileUris'
      ]
    }
    protectedSettings: {
      commandToExecute: 'sh customScript.sh'
    }
  }
}
