# deploys the Azure Function app we'll be using for testing
# remember to select the correct subscription
#az account set -s "Microsoft Azure Sponsorship"

# 1 - create a resource group
$resourceGroup = "AzureFunctionsMsiDemo"
$location = "westeurope"
az group create -n $resourceGroup -l $location

# 2 - create a storage account
$rand = Get-Random -Minimum 10000 -Maximum 99999
$storageAccountName = "funcsmsi$rand"

az storage account create `
  -n $storageAccountName `
  -l $location `
  -g $resourceGroup `
  --sku Standard_LRS

# 3 - create a function app
$functionAppName = "funcs-msi-$rand"

az functionapp create `
  -n $functionAppName `
  --storage-account $storageAccountName `
  --consumption-plan-location $location `
  --runtime dotnet `
  -g $resourceGroup

# 4 - Assign a managed service identity
az functionapp identity assign -n $functionAppName -g $resourceGroup
# response will include principalId, tenantId and type=SystemAssigned

# get the principal and tenant ids (principal id is also the "objectId")
$principalId = az functionapp identity show -n $functionAppName -g $resourceGroup --query principalId -o tsv
$tenantId = az functionapp identity show -n $functionAppName -g $resourceGroup --query tenantId -o tsv

# find the service principal in AD:
az ad sp show --id $principalId
az ad sp list --display-name $functionAppName

# n.b. there are two new environment variables MSI_ENDPOINT, MSI_SECRET
# but they are not visible as appsettings
az functionapp config appsettings list -n $functionAppName -g $resourceGroup -o table

# 5 - Create a key vault
$keyvaultname = "funcsmsi$rand"
az keyvault create -n $keyvaultname -g $resourceGroup

# 6 - Save a secret in the key vault
$secretName = "MySecret"
az keyvault secret set -n $secretName --vault-name $keyvaultname --value "Super secret value!"

# view the secret
az keyvault secret show -n $secretName --vault-name $keyvaultname

$secretId = az keyvault secret show -n $secretName --vault-name $keyvaultname --query "id" -o tsv

# 7 - grant the function app permissions to access the key vault
az keyvault set-policy -n $keyvaultname -g $resourceGroup --object-id $principalId --secret-permissions get

# see the access policies added:
az keyvault show -n $keyvaultname -g $resourceGroup --query "properties.accessPolicies[?objectId == ``$principalId``]"

# 8 - deploy our function app


az group delete -n $resourceGroup