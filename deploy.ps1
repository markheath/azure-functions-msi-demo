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
dotnet publish -c Release
$publishFolder = "FunctionsMsi/bin/Release/netcoreapp2.1/publish"

# create the zip
$publishZip = "publish.zip"
if(Test-path $publishZip) {Remove-item $publishZip}
Add-Type -assembly "system.io.compression.filesystem"
[io.compression.zipfile]::CreateFromDirectory($publishFolder, $publishZip)

az functionapp deployment source config-zip `
 -g $resourceGroup -n $functionAppName --src $publishZip


az functionapp config show -n $functionAppName -g $resourceGroup

# 9 - get the credentials to call our API
# https://www.markheath.net/post/managing-azure-function-keys
function getKuduCreds($appName, $resourceGroup)
{
    $user = az webapp deployment list-publishing-profiles -n $appName -g $resourceGroup `
            --query "[?publishMethod=='MSDeploy'].userName" -o tsv

    $pass = az webapp deployment list-publishing-profiles -n $appName -g $resourceGroup `
            --query "[?publishMethod=='MSDeploy'].userPWD" -o tsv

    $pair = "$($user):$($pass)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    return $encodedCreds
}

function getFunctionKey([string]$appName, [string]$functionName, [string]$encodedCreds)
{
    $jwt = Invoke-RestMethod -Uri "https://$appName.scm.azurewebsites.net/api/functions/admin/token" -Headers @{Authorization=("Basic {0}" -f $encodedCreds)} -Method GET

    $keys = Invoke-RestMethod -Method GET -Headers @{Authorization=("Bearer {0}" -f $jwt)} `
            -Uri "https://$appName.azurewebsites.net/admin/functions/$functionName/keys" 

    $code = $keys.keys[0].value
    return $code
}

$kuduCreds = getKuduCreds $functionAppName $resourceGroup 
$functionName = "GetAppSetting"
$functionKey = getFunctionKey $functionAppName $functionName $kuduCreds


# 10 - add a new app setting referencing a secret
# really bizarre issue with setting this sort of secret. Need to use a special 
# ^^ escaping character - https://ss64.com/nt/syntax-esc.html
#
$secret2 = "Secret2=@Microsoft.KeyVault(SecretUri=$secretId^^)"
az functionapp config appsettings set -n $functionAppName -g $resourceGroup `
    --settings "Secret1=blah" $secret2

az functionapp config appsettings list -n $functionAppName -g $resourceGroup

# 11 - access the secrets with the function api
$funcUri = "https://$functionAppName.azurewebsites.net/api/$functionName" + "?code=$functionKey"

Invoke-RestMethod "$funcUri&name=Secret1"
Invoke-RestMethod "$funcUri&name=Secret2"
Invoke-RestMethod "$funcUri&name=MSI_ENDPOINT"

# 12 - Bonus - let's create app insights and get that set up as well
# in powershell its really hard to pass the json with correct syntax escaping, 
# so easier just to write to a temp file
$propsFile = "props.json"
'{"Application_Type":"web"}' | Out-File $propsFile
$appInsightsName = "funcsmsi$rand"
az resource create `
    -g $resourceGroup -n $appInsightsName `
    --resource-type "Microsoft.Insights/components" `
    --properties "@$propsFile"
Remove-Item $propsFile

$appInsightsKey = az resource show -g $resourceGroup -n $appInsightsName `
    --resource-type "Microsoft.Insights/components" `
    --query "properties.InstrumentationKey" -o tsv

az functionapp config appsettings set -n $functionAppName -g $resourceGroup `
    --settings "APPINSIGHTS_INSTRUMENTATIONKEY=$appInsightsKey"


# 13 - when we're done, clean up
az group delete -n $resourceGroup