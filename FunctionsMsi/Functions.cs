using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace FunctionsMsi
{
    public static class Functions
    {
        [FunctionName("GetAppSetting")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", Route = null)] HttpRequest req,
            ILogger log)
        {
            string settingName = req.Query["name"];
            if (string.IsNullOrEmpty(settingName))
                return new BadRequestObjectResult("Please pass a name on the query string");

            log.LogInformation($"Requesting setting {settingName}.");
            var value = Environment.GetEnvironmentVariable(settingName);
            return new OkObjectResult($"{settingName}={value}");
        }
    }
}
