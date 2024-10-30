from google.cloud import aiplatform
from google.cloud import pubsub_v1
import json
import os

# Define your Vertex AI pipeline job settings
PROJECT_ID = os.getenv("XXXXXX")
PIPELINE_NAME = "teamu_recsys_pipeline"
PIPELINE_LOCATION = "us-central1"
SERVICE_ACCOUNT = "XXXXX"

def start_vertex_ai_pipeline(event, context):
    """
    Triggered from a message on a Pub/Sub topic.
    Parses the Pub/Sub message, then starts the Vertex AI pipeline job.
    """
    # Decode the Pub/Sub message
    pubsub_message = json.loads(event['data'].decode('utf-8'))

    # Initialize Vertex AI
    aiplatform.init(project=PROJECT_ID, location=PIPELINE_LOCATION)

    # Trigger the pipeline
    job = aiplatform.PipelineJob(
        display_name="data_ingestion_pipeline_trigger",
        template_path=f"gs://your-gcs-bucket/pipeline-spec/{PIPELINE_NAME}.json",  # Specify your JSON pipeline spec path
        enable_caching=False,
    )

    job.submit(service_account=SERVICE_ACCOUNT)
