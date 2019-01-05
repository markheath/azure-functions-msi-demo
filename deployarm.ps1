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

# nb doesn't appear to be a way to see/set that setting from here?
az functionapp config show -g $resourceGroup -n $functionAppName

az group delete -n $resourceGroup -y