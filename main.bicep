// Name        : main.bicep
// Description : Implements template needed to provision a Wasm cloud lab using Ubuntu VMs on Azure
// Version     : 0.1.0
// Author      : github.com/rchaganti

// parameters
@description('Location for all resources.')
param location string = resourceGroup().location

@description('Number of Wasm cloud VMs.')
param numVM int = 3

@description('Username for the Linux VM')
param username string = 'ubuntu'

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
param authenticationType string = 'password'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param passwordOrKey string

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
param installRustLanguage bool = true

// variables
var vmNames = [for i in range(0, numVM): {
  name: 'wcloud${(i + 1)}'
}]

// Script content for Kubernetes cluster creation
var wasmCloudConfig = loadTextContent('scripts/wasmconfig.sh', 'utf-8')
var installRust = loadTextContent('scripts/installRust.sh', 'utf-8')

// Provision NSG and allow 22
module nsg 'modules/nsg.bicep' = {
  name: 'wasm-nsg'
  params: {
    nsgName: 'wasm-nsg'
    location: location
    nsgProperties: [
      {
        name: 'ssh'
        priority: 1001
        protocol: 'tcp'
        access: 'allow'
        direction: 'inbound'
        destinationPortRange: 22 
      }    
    ]
  }
}

// Provision virtual network
module vnet 'modules/vnet.bicep' = {
  name: 'wasm-vnet'
  params: {
   location: location
   subnetName: 'wasm-subnet'
   vNetName: 'wasm-vnet'
   vNetAddressPrefix: '10.0.0.0/16'
   subnetPrefix: '10.0.1.0/27'
  }
}

// Provision public IP resources for each virtual machine
module pip 'modules/pip.bicep' = [for vm in vmNames: {
  name: '${vm.name}pip'
  params: {
    vmName: vm.name
    location: location
  }
}]

// Provision network interface for each virtual machine
module nic 'modules/nic.bicep' = [for (vm, i) in vmNames: {
  name: '${vm.name}nic'
  params: {
    location: location
    subnetId: vnet.outputs.subnetId
    netInterfacePrefix: vm.name
    nsgId: nsg.outputs.id
    publicIPId: pip[i].outputs.pipInfo.id
  }
}]

// Provision VMs
module vms 'modules/linuxvm.bicep' = [for (vm, i) in vmNames: {
  name: vm.name
  params: {
    location: location
    passwordOrKey: passwordOrKey
    username: username
    vmName: vm.name
    authenticationType: authenticationType
    nicId: nic[i].outputs.id
    osOffer: '0001-com-ubuntu-server-focal'
    osPublisher: 'canonical'
    osVersion: '20_04-lts'
  }
}]

// Provision common config using custom script extension
resource cse 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = [for (vm, i) in vmNames: {
  name: '${vm.name}/commonfcse'
  dependsOn: vms
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      script: base64(wasmCloudConfig)
    }
  }
}]

// Perform Rust install init on wcloud1
module installRustLang 'modules/managedRunCmd.bicep' = if (installRustLanguage) {
  name: 'installRust'
  dependsOn: cse
  params: {
    configType: 'installRust'
    location: location
    vmName: 'wcloud1'
    scriptContent: installRust
  }
}

// Retrieve output
output vmInfo array = [for (vm, i) in vmNames: {
  name: vm.name
  connect: 'ssh ${username}@${pip[i].outputs.pipInfo.dnsFqdn}'
}]
