using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace AzninjaTodoFn.Models
{
    public class TodoItem
    {
        [BsonId]
        public string Id { get; set; }

        [BsonElement("owner")]
        public string Owner { get; set; }

        [BsonElement("description")]
        public string Description { get; set; }

        [BsonElement("status")]
        public bool Status { get; set; }
    }
}