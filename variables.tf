##############################################################################
# Variables File
# 
# Here is where we store the default values for all the variables used in our
# Terraform code. If you create a variable with no default, the user will be
# prompted to enter it (or define it via config file or command line flags.)

variable "resource_group" {
  description = "The name of your Azure Resource Group."
  default     = "czela-terraform"
}

variable "prefix" {
  description = "This prefix will be included in the name of some resources."
  default     = "tfbcp"
}

variable "location" {
  description = "The region where the virtual network is created."
  default     = "eastus2"
}

variable "virtual_network_name" {
  description = "The name for your virtual network."
  default     = "vnet"
}

variable "address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = "10.0.0.0/16"
}

variable "subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.0.10.0/24"
}

variable "storage_account_tier" {
  description = "Defines the storage tier. Valid options are Standard and Premium."
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Defines the replication type to use for this storage account. Valid options include LRS, GRS etc."
  default     = "LRS"
}

variable "aks_dns_prefix" {
  description = "k8s cluster dns"
  default     = "k8sdns"
}

variable "aks_agent_count" {
  description = "Nodes number for k8s cluster."
  default     = "2"
}

variable "aks_client_id" {
  description = "Service Principal ClientId dedicated to AKS"
  default     = "412376c4-eacf-4a82-a2c0-a76be833f955"
}

variable "aks_client_secret" {
  description = "Service Principal ClientSecret dedicated to AKS"
  default     = "33e183b9-a65a-47e6-bce4-8f37bb6be1ca"
}