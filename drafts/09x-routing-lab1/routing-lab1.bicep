param REGION string = 'southcentralus'
// shorten southcentralus because it's too long
var REGION_SUBFIX = REGION == 'southcentralus' ? 'scus' : REGION
param VM_USERNAME string = 'azureuser'
@secure()
param VM_PASSWORD string = 'Azure123456$'

// == deploy hub1-vnet and components ===================

// hub1-vnet
resource hub1Vnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'hub1-${REGION_SUBFIX}-vnet'
  location: REGION
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.2.20.0/24'
      ]
    }
    subnets: [
      {
        name: 'general1-snet'
        properties: {
          addressPrefix: '10.2.20.0/28'
        }
      }
      {
        name: 'nva1front-snet'
        properties: {
          addressPrefix: '10.2.20.32/28'
        }
      }
      {
        name: 'nva1back-snet'
        properties: {
          addressPrefix: '10.2.20.48/28'
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.2.20.128/26'
        }
      }
      {
        name: 'RouteServerSubnet'
        properties: {
          addressPrefix: '10.2.20.192/27'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.2.20.224/27'
        }
      }
    ]
  }
}

// hub1-vnet / virtual network gateway / public ip 1
resource hub1VgwPip1 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'hub1-${REGION_SUBFIX}-vgw-pip1'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// hub1-vnet / virtual network gateway / public ip 2
resource hub1VgwPip2 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'hub1-${REGION_SUBFIX}-vgw-pip2'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// hub1-vnet / vnet gateway
resource hub1Vgw 'Microsoft.Network/virtualNetworkGateways@2020-11-01' = {
  name: 'hub1-${REGION_SUBFIX}-vgw'
  location: REGION
  properties: {
    bgpSettings: {
      asn: 65220
    }
    activeActive: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${hub1Vnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: hub1VgwPip1.id
          }
        }
      }
      {
        name: 'ipconfig2'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${hub1Vnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: hub1VgwPip2.id
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

// hub1-vnet / azure firewall / public ip
resource hub1FirewallPip 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'hub1-${REGION_SUBFIX}-azfw-pip1'
  location: REGION
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// hub1-vnet / azure firewall / firewall policy
resource hub1FirewallPolicy 'Microsoft.Network/firewallPolicies@2021-05-01' = {
  name: 'hub1-${REGION_SUBFIX}-azfw-pol'
  location: REGION
  properties: {
    sku: {
      tier: 'Standard'
    }
    dnsSettings: {
      enableProxy: true
    }
    threatIntelMode: 'Alert'
  }
}

// hub1-vnet / azure firewall
resource hub1Firewall 'Microsoft.Network/azureFirewalls@2021-05-01' = {
  name: 'hub1-${REGION_SUBFIX}-azfw'
  location: REGION
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }    
    firewallPolicy: {
      id: hub1FirewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${hub1Vnet.id}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: hub1FirewallPip.id
          }
        }
      }
    ]
  }
}

// hub1-vnet / azure route server / public ip
resource hub1RouteServerPip 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'hub1-${REGION_SUBFIX}-ars-pip'
  location: REGION
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// hub1-vnet / azure route server
resource hub1RouteServer 'Microsoft.Network/virtualHubs@2021-02-01' = {
  name: 'hub1-${REGION_SUBFIX}-ars'
  location: REGION
  dependsOn: [
    hub1Vnet
  ]
  properties: {
    sku: 'Standard'
    allowBranchToBranchTraffic: true
  }
}

// hub1-vnet / azure route server / ip config
resource hub1RouteServerIPConfig 'Microsoft.Network/virtualHubs/ipConfigurations@2022-05-01' = {
  name: 'ipconfig1'
  parent: hub1RouteServer
  properties: {
    subnet: {
      id: '${hub1Vnet.id}/subnets/RouteServerSubnet'
    }
    publicIPAddress: {
      id: hub1RouteServerPip.id
    }
  }
}

// hub1-vnet / hub1test vm / public ip
resource hub1test1VmPip 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'hub1test1-${REGION_SUBFIX}-pip'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// hub1-vnet / hub1test vm / nsg
resource hub1test1VmNsg 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: 'hub1test1-${REGION_SUBFIX}-nsg'
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
          sourceAddressPrefix: '99.70.225.17'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// hub1-vnet / hub1test vm / nic
resource hub1test1VmNic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'hub1test1-${REGION_SUBFIX}-nic'
  location: REGION
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${hub1Vnet.id}/subnets/general1-snet'
          }
          publicIPAddress: {
            id: hub1test1VmPip.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: hub1test1VmNsg.id
    }
  }
}

// hub1-vnet / hub1test vm
resource hub1test1Vm 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'hub1test1-${REGION_SUBFIX}-vm'
  location: REGION
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: 'hub1test1'
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
        name: 'hub1test1-${REGION_SUBFIX}-vm-disk0'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: hub1test1VmNic.id
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

// hub1-vnet / expressroute gateway / public ip
resource hub1ExrgwPip 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'hub1-${REGION_SUBFIX}-exrgw-pip'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// hub1-vnet / expressroute gateway
resource hub1Exrgw 'Microsoft.Network/virtualNetworkGateways@2020-11-01' = {
  name: 'hub1-${REGION_SUBFIX}-exrgw'
  location: REGION
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${hub1Vnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: hub1ExrgwPip.id
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



// == deploy avs1nva-vnet and components ===================

// avs1nva-vnet
resource avs1nvaVnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'avs1nva-${REGION_SUBFIX}-vnet'
  location: REGION
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.2.27.0/24'
      ]
    }
    subnets: [
      {
        name: 'general1-snet'
        properties: {
          addressPrefix: '10.2.27.0/28'
        }
      }
      {
        name: 'nva1front-snet'
        properties: {
          addressPrefix: '10.2.27.32/28'
        }
      }
      {
        name: 'nva1back-snet'
        properties: {
          addressPrefix: '10.2.27.48/28'
        }
      }
      {
        name: 'RouteServerSubnet'
        properties: {
          addressPrefix: '10.2.27.192/27'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.2.27.224/27'
        }
      }
    ]
  }
}

// avs1nva-vnet / virtual network gateway public ip
resource avs1nvaVgwPip1 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'avs1nva-${REGION_SUBFIX}-vgw-pip1'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource avs1nvaVgwPip2 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'avs1nva-${REGION_SUBFIX}-vgw-pip2'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// avs1nva-vnet / virtual network gateway
resource avs1nvaVgw 'Microsoft.Network/virtualNetworkGateways@2020-11-01' = {
  name: 'avs1nva-${REGION_SUBFIX}-vgw'
  location: REGION
  properties: {
    bgpSettings: {
      asn: 65227
    }
    activeActive: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${avs1nvaVnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: avs1nvaVgwPip1.id
          }
        }
      }
      {
        name: 'ipconfig2'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${avs1nvaVnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: avs1nvaVgwPip2.id
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

// avs1nva-vnet / expressroute gateway / public ip
resource avs1nvaExrgwPip 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'avs1nva-${REGION_SUBFIX}-exrgw-pip'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// avs1nva-vnet / expressroute gateway
resource avs1nvaExrgw 'Microsoft.Network/virtualNetworkGateways@2020-11-01' = {
  name: 'avs1nva-${REGION_SUBFIX}-exrgw'
  location: REGION
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${avs1nvaVnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: avs1nvaExrgwPip.id
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

// avs1nva-vnet / azure route server / public ip
resource avs1nvaRouteServerPip 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'avs1nva-${REGION_SUBFIX}-ars-pip'
  location: REGION
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// avs1nva-vnet / azure route server
resource avs1nvaRouteServer 'Microsoft.Network/virtualHubs@2021-02-01' = {
  name: 'avs1nva-${REGION_SUBFIX}-ars'
  location: REGION
  dependsOn: [
    avs1nvaVnet
  ]
  properties: {
    sku: 'Standard'
    allowBranchToBranchTraffic: true
  }
}

// avs1nva-vnet / azure route server / ip config
resource avs1nvaRouteServerIPConfig 'Microsoft.Network/virtualHubs/ipConfigurations@2022-05-01' = {
  name: 'ipconfig1'
  parent: avs1nvaRouteServer
  properties: {
    subnet: {
      id: '${avs1nvaVnet.id}/subnets/RouteServerSubnet'
    }
    publicIPAddress: {
      id: avs1nvaRouteServerPip.id
    }
  }
}

// avs1nva-vnet / avs1nva1 vm / public ip
resource avs1nva1VmPip 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'avs1nva1-${REGION_SUBFIX}-pip'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// avs1nva-vnet / avs1nva1 vm / nsg
resource avs1nva1VmNsg 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: 'avs1nva1-${REGION_SUBFIX}-nsg'
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
          sourceAddressPrefix: '99.70.225.17'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// avs1nva-vnet / avs1nva1 vm / nic1
resource avs1nva1VmNic1 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'avs1nva1-${REGION_SUBFIX}-nic1'
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
            id: '${avs1nvaVnet.id}/subnets/nva1front-snet'
          }
          publicIPAddress: {
            id: avs1nva1VmPip.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: avs1nva1VmNsg.id
    }
  }
}

// avs1nva-vnet / avs1nva1 vm / nic2
resource avs1nva1VmNic2 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'avs1nva1-${REGION_SUBFIX}-nic2'
  location: REGION
  properties: {
    enableIPForwarding: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${avs1nvaVnet.id}/subnets/nva1back-snet'
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: avs1nva1VmNsg.id
    }
  }
}

// avs1nva1-vnet / avs1nva1 vm
resource avs1nva1Vm 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'avs1nva1-${REGION_SUBFIX}-vm'
  location: REGION
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2ds_v4'
    }
    osProfile: {
      computerName: 'avs1nva1'
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
        name: 'avs1nva1-${REGION_SUBFIX}-vm-disk0'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: avs1nva1VmNic1.id
          properties: {
            primary: true
          }
        }
        {
          id: avs1nva1VmNic2.id
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

// == peer hub1 & avs1nva ===================

resource hub1_avs1nva_peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  name: '${hub1Vnet.name}/${hub1Vnet.name}_to_${avs1nvaVnet.name}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: avs1nvaVnet.id
    }
  }
}

resource avs1nva_hub1_peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  name: '${avs1nvaVnet.name}/${avs1nvaVnet.name}_to_${hub1Vnet.name}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hub1Vnet.id
    }
  }
}

// == deploy onprem1-vnet ===================

// onprem1-vnet
resource onprem1Vnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'onprem1-${REGION_SUBFIX}-vnet'
  location: REGION
  properties: {
    addressSpace: {
      addressPrefixes: [
        '192.168.91.0/24'
      ]
    }
    subnets: [
      {
        name: 'general1-snet'
        properties: {
          addressPrefix: '192.168.91.0/28'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '192.168.91.224/27'
        }
      }
    ]
  }
}

// onprem1-vnet / virtual network gateway / public ip
resource onprem1VgwPip1 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'onprem1-${REGION_SUBFIX}-vgw-pip1'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// onprem1-vnet / virtual network gateway
resource onprem1Vgw 'Microsoft.Network/virtualNetworkGateways@2020-11-01' = {
  name: 'onprem1-${REGION_SUBFIX}-vgw'
  location: REGION
  properties: {
    bgpSettings: {
      asn: 64891
    }
    activeActive: false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${onprem1Vnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: onprem1VgwPip1.id
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

// onprem1-vnet / onprem1a1 vm / nsg
resource onprem1a1VmNsg 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: 'onprem1a1-${REGION_SUBFIX}-nsg'
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
          sourceAddressPrefix: '99.70.225.17'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// onprem1-vnet / onprem1a1 vm / nic
resource onprem1a1VmNic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'onprem1a1-${REGION_SUBFIX}-nic'
  location: REGION
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${onprem1Vnet.id}/subnets/general1-snet'
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: onprem1a1VmNsg.id
    }
  }
}

// onprem1-vnet / onprem1a1 vm
resource onprem1a1Vm 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'onprem1a1-${REGION_SUBFIX}-vm'
  location: REGION
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: 'onprem1a1'
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
        name: 'onprem1a1-${REGION_SUBFIX}-vm-disk0'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: onprem1a1VmNic.id
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

// == deploy avs1-vnet ===================

// avs1-vnet
resource avs1Vnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'avs1-${REGION_SUBFIX}-vnet'
  location: REGION
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.17.1.0/24'
      ]
    }
    subnets: [
      {
        name: 'general1-snet'
        properties: {
          addressPrefix: '172.17.1.0/28'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '172.17.1.224/27'
        }
      }
    ]
  }
}

// avs1-vnet / virtual network gateway / public ip
resource avs1VgwPip1 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: 'avs1-${REGION_SUBFIX}-vgw-pip1'
  location: REGION
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// avs1-vnet / virtual network gateway
resource avs1Vgw 'Microsoft.Network/virtualNetworkGateways@2020-11-01' = {
  name: 'avs1-${REGION_SUBFIX}-vgw'
  location: REGION
  properties: {
    bgpSettings: {
      asn: 65171
    }
    activeActive: false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${avs1Vnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: avs1VgwPip1.id
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

// avs1-vnet / avs1a1 vm / nsg
resource avs1a1VmNsg 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: 'avs1a1-${REGION_SUBFIX}-nsg'
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
          sourceAddressPrefix: '99.70.225.17'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// avs1-vnet / avs1a1 vm / nic
resource avs1a1VmNic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'avs1a1-${REGION_SUBFIX}-nic'
  location: REGION
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${avs1Vnet.id}/subnets/general1-snet'
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: avs1a1VmNsg.id
    }
  }
}

// avs1-vnet / avs1a1 vm
resource avs1a1Vm 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'avs1a1-${REGION_SUBFIX}-vm'
  location: REGION
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: 'avs1a1'
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
        name: 'avs1a1-${REGION_SUBFIX}-vm-disk0'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: avs1a1VmNic.id
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
