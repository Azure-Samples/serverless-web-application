using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Collections.Generic;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;
using MongoDB.Driver;
using AzninjaTodoFn.Models;
using AzninjaTodoFn.Helpers;
using Microsoft.OpenApi.Models;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Attributes;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Enums;

namespace AzninjaTodoFn
{
    public class TodoList
    {

        private readonly ILogger _logger;
        private readonly IConfiguration _config;
        private MongoClient _client;
        private readonly IMongoCollection<TodoItem> _todolist;
        private string _user;

        public TodoList(ILogger<TodoList> logger, IConfiguration config, MongoClient client, IHttpContextAccessor context)
        {
            _logger = logger;
            _config = config;
            _client = client;
            _user = context.HttpContext.User.Identity.Name ?? "*";
            var database = _client.GetDatabase(_config[Constants.databaseName]);
            _todolist = database.GetCollection<TodoItem>(_config[Constants.collectionName]);
        }

        [OpenApiOperation(operationId: "GetTodoItems")]
        [OpenApiSecurity("function_key", SecuritySchemeType.ApiKey, Name = "code", In = OpenApiSecurityLocationType.Query)]
        [OpenApiResponseWithBody(statusCode: HttpStatusCode.OK, contentType: "application/json", bodyType: typeof(TodoItem[]), Description = "A to do list")]
        [FunctionName("GetTodoItems")]
        public async Task<IActionResult> GetTodoItems(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "todos")]
            HttpRequest req)
        {
            IActionResult returnValue = null;

            try
            {
                var result = _todolist.Find(item => item.Owner == _user).ToList();

                if (result == null)
                {
                    _logger.LogInformation($"There are no items in the collection");
                    returnValue = new NotFoundResult();
                }
                else
                {
                    returnValue = new OkObjectResult(result);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Exception thrown: {ex.Message}");
                returnValue = new StatusCodeResult(StatusCodes.Status500InternalServerError);
            }

            return returnValue;
        }

        [OpenApiOperation(operationId: "GetTodoItem")]
        [OpenApiSecurity("function_key", SecuritySchemeType.ApiKey, Name = "code", In = OpenApiSecurityLocationType.Query)]
        [OpenApiParameter(name: "id", In = ParameterLocation.Path, Required = true, Type = typeof(string), Description = "To do item id")]
        [OpenApiResponseWithBody(statusCode: HttpStatusCode.OK, contentType: "application/json", bodyType: typeof(TodoItem), Description = "A to do item")]
        [FunctionName("GetTodoItem")]
        public async Task<IActionResult> GetTodoItem(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post", 
                Route = "todos/{id}")]HttpRequestMessage req, string id)
        {

            IActionResult returnValue = null;

            try
            {
                var result =_todolist.Find(item => item.Id == id && item.Owner == _user).FirstOrDefault();

                if (result == null)
                {
                    _logger.LogWarning("That item doesn't exist!");
                    returnValue = new NotFoundResult();
                }
                else
                {
                    returnValue = new OkObjectResult(result);
                }               
            }
            catch (Exception ex)
            {
                _logger.LogError($"Couldn't find item with id: {id}. Exception thrown: {ex.Message}");
                returnValue = new StatusCodeResult(StatusCodes.Status500InternalServerError);
            }

            return returnValue;
        }

        [OpenApiOperation(operationId: "PostTodoItem")]
        [OpenApiSecurity("function_key", SecuritySchemeType.ApiKey, Name = "code", In = OpenApiSecurityLocationType.Query)]
        [OpenApiRequestBody(contentType: "application/json", bodyType: typeof(TodoItem), Required = true, Description = "To do object that needs to be added to the list")]
        [OpenApiResponseWithBody(statusCode: HttpStatusCode.OK, contentType: "application/json", bodyType: typeof(TodoItem), Description = "A to do item")]
        [FunctionName("PostTodoItem")]
        public async Task<IActionResult> PostTodoItem(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "todos")] HttpRequest req)
        {
            IActionResult returnValue = null;

            try
            {
                string requestBody = await new StreamReader(req.Body).ReadToEndAsync();

                var input = JsonConvert.DeserializeObject<TodoItem>(requestBody);

                var todo = new TodoItem
                {
                    Id = Guid.NewGuid().ToString(),
                    Description = input.Description,
                    Owner = _user,
                    Status = false
                };

                _todolist.InsertOne(todo);

                _logger.LogInformation("Todo item inserted");
                returnValue = new OkObjectResult(todo);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Could not insert item. Exception thrown: {ex.Message}");
                returnValue = new StatusCodeResult(StatusCodes.Status500InternalServerError);
            }

            return returnValue;
        }

        [OpenApiOperation(operationId: "PutTodoItem")]
        [OpenApiSecurity("function_key", SecuritySchemeType.ApiKey, Name = "code", In = OpenApiSecurityLocationType.Query)]
        [OpenApiParameter(name: "id", In = ParameterLocation.Path, Required = true, Type = typeof(string), Description = "To do Id")]
        [OpenApiRequestBody(contentType: "application/json", bodyType: typeof(TodoItem), Required = true, Description = "To do object that needs to be updated to the list")]
        [OpenApiResponseWithBody(statusCode: HttpStatusCode.OK, contentType: "application/json", bodyType: typeof(TodoItem), Description = "A to do item")]
        [FunctionName("PutTodoItem")]
        public async Task<IActionResult> PutTodoItem(
            [HttpTrigger(AuthorizationLevel.Anonymous, "put", Route = "todos/{id}")] HttpRequest req,
            string id)
        {
            IActionResult returnValue = null;

            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();

            var updatedResult = JsonConvert.DeserializeObject<TodoItem>(requestBody);

            updatedResult.Id = id;

            try
            {
                var replacedItem = _todolist.ReplaceOne(item => item.Id == id && item.Owner == _user, updatedResult);

                if (replacedItem == null)
                {
                    returnValue = new NotFoundResult();
                }
                else
                {
                    returnValue = new OkObjectResult(updatedResult);
                }              
            }
            catch (Exception ex)
            {
                _logger.LogError($"Could not update Album with id: {id}. Exception thrown: {ex.Message}");
                returnValue = new StatusCodeResult(StatusCodes.Status500InternalServerError);
            }

            return returnValue;
        }

       
        [OpenApiOperation(operationId: "DeleteTodoItem")]
        [OpenApiSecurity("function_key", SecuritySchemeType.ApiKey, Name = "code", In = OpenApiSecurityLocationType.Query)]
        [OpenApiParameter(name: "id", In = ParameterLocation.Path, Required = true, Type = typeof(string), Description = "To do Id that needs to be removed from the list")]
        [OpenApiResponseWithBody(statusCode: HttpStatusCode.OK, contentType: "text/plain", bodyType: typeof(string), Description = "OK Response")]
        [FunctionName("DeleteTodoItem")]
        public async Task<IActionResult> DeleteTodoItem(
            [HttpTrigger(AuthorizationLevel.Anonymous, "delete",
            Route = "todos/{id}")]HttpRequestMessage req, string id)
        {

            IActionResult returnValue = null;

            try
            {
                var itemToDelete = _todolist.DeleteOne(item => item.Id == id && item.Owner == _user);

                if (itemToDelete == null)
                {
                    _logger.LogInformation($"Todo item with id: {id} does not exist. Delete failed");
                    returnValue = new StatusCodeResult(StatusCodes.Status404NotFound);
                }

                returnValue = new StatusCodeResult(StatusCodes.Status200OK);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Could not delete item. Exception thrown: {ex.Message}");
                returnValue = new StatusCodeResult(StatusCodes.Status500InternalServerError);
            }

            return returnValue;
        }

        [OpenApiOperation(operationId: "HealthCheck")]
        [OpenApiResponseWithoutBody(statusCode: HttpStatusCode.OK, Description = "Status code 200")]
        [FunctionName("HealthCheck")]
        public async Task<IActionResult> HealthCheck(
            [HttpTrigger(AuthorizationLevel.Anonymous, "head",
            Route = "todos")]HttpRequestMessage req)
        {

            IActionResult returnValue = null;

            returnValue = new StatusCodeResult(StatusCodes.Status200OK);

            return returnValue;
        }
    }
}
