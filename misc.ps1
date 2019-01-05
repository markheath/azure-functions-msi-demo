# here's how to use the Kudu API to set and get settings
# HOWEVER - Kudu settings are not actual web "appsettings" - more like environment variables
function getAppSettings([string]$appName, [string]$encodedCreds)
{
    $settings = Invoke-RestMethod -Uri "https://$appName.scm.azurewebsites.net/api/settings" -Headers @{Authorization=("Basic {0}" -f $encodedCreds)} -Method GET
    return $settings
}
getAppSettings $functionAppName $kuduCreds

$settings = @{
    Secret1='set via powershell'
    Secret3="@Microsoft.KeyVault(SecretUri=$secretId)"
}
$settingsJson = $settings | ConvertTo-Json
$response = Invoke-RestMethod "https://$functionAppName.scm.azurewebsites.net/api/settings" `
                -Headers @{Authorization=("Basic {0}" -f $kuduCreds)} `
                -Method Post -Body $settingsJson -ContentType 'application/json'
