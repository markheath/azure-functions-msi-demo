# 1 - create a resource group
$resourceGroup = "AzureFunctionsArmDemo"
$location = "westeurope"
az group create -n $resourceGroup -l $location

$armTemplate = "functionapp.json"
$rand = Get-Random -Minimum 10000 -Maximum 99999
$functionAppName =  "funcsarm$rand"

az group deployment validate -g $resourceGroup --template-file $armTemplate `
    --parameters "appName=$functionAppName" 

# a dailyMemoryTimeQuota of 0 means disable quotas
# hmmm - quota doesn't appear to take on first deployment but does on subsequent deployments
az group deployment create -g $resourceGroup --template-file $armTemplate `
    --parameters "appName=$functionAppName" "dailyMemoryTimeQuota=10208"

# another way to set the quota
az functionapp show -g $resourceGroup -n $functionAppName --query dailyMemoryTimeQuota
az functionapp update -g $resourceGroup -n $functionAppName --set dailyMemoryTimeQuota=12460

az group delete -n $resourceGroup -y