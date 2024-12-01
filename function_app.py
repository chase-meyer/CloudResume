import azure.functions as func
import logging
import os
import json
from azure.cosmos import CosmosClient, PartitionKey

# Initialize the Cosmos client
endpoint = os.environ['COSMOS_DB_ENDPOINT']
key = os.environ['COSMOS_DB_KEY']
client = CosmosClient(endpoint, key)

# Database and container names
database_name = 'ResumeDB'
container_name = 'ResumeContainer'

# Create database and container if they don't exist
database = client.create_database_if_not_exists(id=database_name)
container = database.create_container_if_not_exists(
    id=container_name,
    partition_key=PartitionKey(path="/id"),
    offer_throughput=400
)

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.route(route="logVisitorInfo")
def log_visitor_info(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    try:
        visitor_info = req.get_json()
    except ValueError:
        return func.HttpResponse("Invalid JSON", status_code=400)

    # Add a unique ID to the visitor info
    visitor_info['id'] = str(uuid.uuid4())

    # Insert the item into the Cosmos DB table
    try:
        container.create_item(body=visitor_info)
        return func.HttpResponse("Visitor information stored successfully.", status_code=200)
    except Exception as e:
        logging.error(f"Error storing item in Cosmos DB: {e}")
        return func.HttpResponse("Error storing item in Cosmos DB.", status_code=500)