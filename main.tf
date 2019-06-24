##############################################################################
# * HashiCorp Beginner's Guide to Using Terraform on Azure
# 
# This Terraform configuration will create the following to daploy a Reference Architecture:
# * Shared infrastructure resource
# * Web components to frontend layer
# * Backend components

##############################################################################
# * Shared infrastructure resources

# First we'll create a resource group. In Azure every resource belongs to a 
# resource group. Think of it as a container to hold all your resources. 
# This Resource will contain the following:
# * A Vnet and subnets
# * A Log Analytics
# * A Key Vault
resource "azurerm_resource_group" "tf_azure_provisioning" {
  name     = "${var.resource_group}"
  location = "${var.location}"
}

# The next resource is a Virtual Network.
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.virtual_network_name}"
  location            = "${azurerm_resource_group.tf_azure_provisioning.location}"
  address_space       = ["${var.address_space}"]
  resource_group_name = "${azurerm_resource_group.tf_azure_provisioning.name}"

  tags = {
    createdBy = "Terraform"
  }
}

# Next we'll build a subnet to run our AKS in.
resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}subnet"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${azurerm_resource_group.tf_azure_provisioning.name}"
  address_prefix       = "${var.subnet_prefix}"
}
# Next resource is a Log Analytics
resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "${var.prefix}loganalytics"
  location            = "${azurerm_resource_group.tf_azure_provisioning.location}"
  resource_group_name = "${azurerm_resource_group.tf_azure_provisioning.name}"
  sku                 = "standalone"
  retention_in_days   = 30

  tags = {
    createdBy = "Terraform"
  }
}
# Next resource is Key Vault
resource "azurerm_key_vault" "key_vault" {
  name                        = "${var.prefix}keyvault"
  location                    = "${azurerm_resource_group.tf_azure_provisioning.location}"
  resource_group_name         = "${azurerm_resource_group.tf_azure_provisioning.name}"
  enabled_for_disk_encryption = true
  tenant_id                   = "5d93ebcc-f769-4380-8b7e-289fc972da1b"

  sku {
    name = "standard"
  }

  access_policy {
    tenant_id = "5d93ebcc-f769-4380-8b7e-289fc972da1b"
    object_id = "b2473646-4b20-4c53-bc0c-1015dcd81e5c"
    
    key_permissions = [
      "get",
    ]

    secret_permissions = [
      "get",
    ]

    storage_permissions = [
      "get",
    ]
  }

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = {
    createdBy = "Terraform"
  }
}
# Next create workspace linked to KeyVault
resource "azurerm_log_analytics_workspace_linked_service" "key_vault_logan" {
  resource_group_name = "${azurerm_resource_group.tf_azure_provisioning.name}"
  workspace_name      = "${azurerm_log_analytics_workspace.log_analytics.name}"
  resource_id         = "${azurerm_key_vault.key_vault.id}"
}

##############################################################################
# * Web layer resources
# We going reuse and will contain the following:
# * CDN
# * WebApp for Container
# * Storage Account

# Next Resource is a CDN
resource "azurerm_cdn_profile" "cdn" {
  name                = "${var.prefix}cdn"
  location            = "${azurerm_resource_group.tf_azure_provisioning.location}"
  resource_group_name = "${azurerm_resource_group.tf_azure_provisioning.name}"
  sku                 = "Standard_Verizon"

  tags = {
    createdBy = "Terraform"
  }
}
# Next Resource is a Service Plan for webapp
resource "azurerm_app_service_plan" "service_plan" {
  name                = "${var.prefix}service-plan"
  location            = "${azurerm_resource_group.tf_azure_provisioning.location}"
  resource_group_name = "${azurerm_resource_group.tf_azure_provisioning.name}"

  sku {
    tier = "Standard"
    size = "S1"
  }

  tags = {
    createdBy = "Terraform"
  }
}

resource "azurerm_app_service" "webapp" {
  name                = "${var.prefix}webapp"
  location            = "${azurerm_resource_group.tf_azure_provisioning.location}"
  resource_group_name = "${azurerm_resource_group.tf_azure_provisioning.name}"
  app_service_plan_id = "${azurerm_app_service_plan.service_plan.id}"

  site_config {
    dotnet_framework_version = "v4.0"
    scm_type                 = "LocalGit"
  }

  tags = {
    createdBy = "Terraform"
  }
}
# Next resource is Storage Account
resource "azurerm_storage_account" "storage_account" {
  name                     = "${var.prefix}staccs"
  resource_group_name      = "${azurerm_resource_group.tf_azure_provisioning.name}"
  location                 = "${azurerm_resource_group.tf_azure_provisioning.location}"
  account_tier             = "${var.storage_account_tier}"
  account_replication_type = "${var.storage_replication_type}"

  tags = {
    createdBy = "Terraform"
  }
}

##############################################################################
# * Backend layer resources
# We going reuse and will contain the following:
# * AKS
# * Redis
# * SQL DB
# * Logic App

# First we going to create a ContainerInsights for AKS
resource "azurerm_log_analytics_solution" "container_insight" {
    solution_name         = "ContainerInsights"
    location              = "${azurerm_log_analytics_workspace.log_analytics.location}"
    resource_group_name   = "${azurerm_resource_group.tf_azure_provisioning.name}"
    workspace_resource_id = "${azurerm_log_analytics_workspace.log_analytics.id}"
    workspace_name        = "${azurerm_log_analytics_workspace.log_analytics.name}"

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}
# Next resource will be an AKS
resource "azurerm_kubernetes_cluster" "k8s" {
    name                = "${var.prefix}k8s"
    location            = "${azurerm_resource_group.tf_azure_provisioning.location}"
    resource_group_name = "${azurerm_resource_group.tf_azure_provisioning.name}"
    dns_prefix          = "${var.aks_dns_prefix}"

    agent_pool_profile {
        name            = "agentpool"
        count           = "${var.aks_agent_count}"
        vm_size         = "Standard_DS1_v2"
        os_type         = "Linux"
        os_disk_size_gb = 30

        # Required for advanced networking
        vnet_subnet_id = "${azurerm_subnet.subnet.id}"
    }

    service_principal {
        client_id     = "${var.aks_client_id}"
        client_secret = "${var.aks_client_secret}"
    }

    network_profile {
        network_plugin = "azure"
    }

    role_based_access_control {
        enabled = true
    }

    addon_profile {
        oms_agent {
        enabled                    = true
        log_analytics_workspace_id = "${azurerm_log_analytics_workspace.log_analytics.id}"
        }
    }

    tags {
        createdBy = "Terraform"
    }
}
# Next resource Redis Cache
resource "azurerm_redis_cache" "redis" {
  name                = "${var.prefix}redis"
  location            = "${azurerm_resource_group.tf_azure_provisioning.location}"
  resource_group_name = "${azurerm_resource_group.tf_azure_provisioning.name}"
  capacity            = 2
  family              = "C"
  sku_name            = "Standard"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {}
}

# Next resource is Log App
resource "azurerm_logic_app_workflow" "logic_app" {
  name                = "${var.prefix}logicapp"
  location            = "${azurerm_resource_group.tf_azure_provisioning.location}"
  resource_group_name = "${azurerm_resource_group.tf_azure_provisioning.name}"
}

# Next resource is SQL DB
resource "azurerm_sql_server" "sql_server" {
  name                         = "${var.prefix}-sqlsvr"
  resource_group_name          = "${azurerm_resource_group.tf_azure_provisioning.name}"
  location                     = "${azurerm_resource_group.tf_azure_provisioning.location}"
  version                      = "12.0"
  administrator_login          = "4dm1n157r470r"
  administrator_login_password = "4-v3ry-53cr37-p455w0rd"
}

resource "azurerm_sql_database" "sql_db" {
  name                             = "${var.prefix}-db"
  resource_group_name              = "${azurerm_resource_group.tf_azure_provisioning.name}"
  location                         = "${azurerm_resource_group.tf_azure_provisioning.location}"
  server_name                      = "${azurerm_sql_server.sql_server.name}"
  edition                          = "Basic"
  collation                        = "SQL_Latin1_General_CP1_CI_AS"
  create_mode                      = "Default"
  requested_service_objective_name = "Basic"
}

##############################################################################
# * Azure MySQL Database

# Terraform can build any type of infrastructure, not just virtual machines. 
# Azure offers managed MySQL database servers and a whole host of other 
# resources. Each resource is documented with all the available settings:
# https://www.terraform.io/docs/providers/azurerm/r/mysql_server.html

# Uncomment the code below to add a MySQL server to your resource group.

# resource "azurerm_mysql_server" "mysql" {
#   name                = "${var.mysql_hostname}"
#   location            = "${azurerm_resource_group.tf_azure_guide.location}"
#   resource_group_name = "${azurerm_resource_group.tf_azure_guide.name}"
#   ssl_enforcement     = "Disabled"

#   sku {
#     name     = "MYSQLB50"
#     capacity = 50
#     tier     = "Basic"
#   }

#   administrator_login          = "mysqladmin"
#   administrator_login_password = "Everything-is-bananas-010101"
#   version                      = "5.7"
#   storage_mb                   = "51200"
#   ssl_enforcement              = "Disabled"
# }

# # This is a sample database that we'll populate with the MySQL sample data
# # set provided here: https://github.com/datacharmer/test_db. With Terraform,
# # everything is Infrastructure as Code. No more manual steps, aging runbooks,
# # tribal knowledge or outdated wiki instructions. Terraform is your executable
# # documentation, and it will build infrastructure correctly every time.
# resource "azurerm_mysql_database" "employees" {
#   name                = "employees"
#   resource_group_name = "${azurerm_resource_group.tf_azure_guide.name}"
#   server_name         = "${azurerm_mysql_server.mysql.name}"
#   charset             = "utf8"
#   collation           = "utf8_unicode_ci"
# }

# # This firewall rule allows database connections from anywhere and is suited
# # for demo environments. Don't do this in production. 
# resource "azurerm_mysql_firewall_rule" "demo" {
#   name                = "tf-guide-demo"
#   resource_group_name = "${azurerm_resource_group.tf_azure_guide.name}"
#   server_name         = "${azurerm_mysql_server.mysql.name}"
#   start_ip_address    = "0.0.0.0"
#   end_ip_address      = "0.0.0.0"
# }
