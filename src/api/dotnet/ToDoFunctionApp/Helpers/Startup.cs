using Microsoft.Azure.Functions.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using System;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using MongoDB.Driver;
using Azure;

[assembly: FunctionsStartup(typeof(AzninjaTodoFn.Helpers.Startup))]
namespace AzninjaTodoFn.Helpers
{
    public class Startup : FunctionsStartup
    {
        public override void Configure(IFunctionsHostBuilder  builder)
        {
            builder.Services.AddLogging(loggingBuilder =>
            {
                loggingBuilder.AddFilter(level => true);
            });

            builder.Services.AddHttpContextAccessor();

            var config = new ConfigurationBuilder()
                .AddJsonFile("local.settings.json", optional: true, reloadOnChange: true)
                .AddEnvironmentVariables() 
                .Build();

            builder.Services.AddSingleton((s) =>
            {
                // Use System Managed Identity to get access to the Key Vault
                SecretClient kvClient = new SecretClient(new Uri(config[Constants.kvUri]), new DefaultAzureCredential());
                Response<KeyVaultSecret> secret = kvClient.GetSecret(config[Constants.kvSecretName]);
                MongoClient client = new MongoClient(secret.Value.Value);
                return client;
            });
        }
    }
}