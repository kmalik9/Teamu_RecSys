import kfp
from kfp.v2 import dsl
from kfp.v2.dsl import Dataset, Input, Output, Model
from google.cloud import aiplatform
from google.cloud.aiplatform import pipeline_jobs

# Initialize Vertex AI SDK
aiplatform.init(project="teamu-542ac", location="us-central1")

# Paths to GCS files
SQL_FILE = "gs://code_bucket/bigquery_feature_engineering.sql"
TRANSFORMATION_NOTEBOOK = "gs://code_bucket/transformation.ipynb"
TWO_TOWER_NOTEBOOK = "gs://code_bucket/two_tower_model.ipynb"
DLRM_NOTEBOOK = "gs://code_bucket/dlrm.ipynb"

@dsl.pipeline(
    name="recommender-system-pipeline",
    description="Pipeline to process data, transform features, and train models",
    pipeline_root="gs://code_bucket/pipeline_root"
)
def recommender_pipeline():
    # Task 1: BigQuery Feature Engineering
    bigquery_task = dsl.ContainerOp(
        name="bigquery_feature_engineering",
        image="gcr.io/deeplearning-platform-release/base-cpu",  # basic image for SQL execution
        command=[
            "bq", "query",
            "--use_legacy_sql=false",
            "--project_id=your_project_id",
            f"--file={SQL_FILE}"
        ]
    )

    # Task 2: Transformation Notebook Execution
    transform_task = dsl.ContainerOp(
        name="data_transformation",
        image="gcr.io/deeplearning-platform-release/base-cpu",
        command=[
            "papermill",
            TRANSFORMATION_NOTEBOOK,
            "/tmp/output.ipynb"
        ],
        file_outputs={"transformed_data": "/tmp/output.ipynb"}
    ).after(bigquery_task)

    # Task 3: Two-Tower Model Training
    two_tower_task = dsl.ContainerOp(
        name="two_tower_training",
        image="gcr.io/deeplearning-platform-release/tf2-cpu.2-6",  # TensorFlow image
        command=[
            "papermill",
            TWO_TOWER_NOTEBOOK,
            "/tmp/two_tower_output.ipynb"
        ],
        file_outputs={"model_output": "/tmp/two_tower_output.ipynb"}
    ).after(transform_task)

    # Task 4: DLRM Model Training
    dlrm_task = dsl.ContainerOp(
        name="dlrm_training",
        image="gcr.io/deeplearning-platform-release/tf2-cpu.2-6",  # TensorFlow image
        command=[
            "papermill",
            DLRM_NOTEBOOK,
            "/tmp/dlrm_output.ipynb"
        ],
        file_outputs={"model_output": "/tmp/dlrm_output.ipynb"}
    ).after(two_tower_task)

# Compile the pipeline
pipeline_filename = "recommender_system_pipeline.json"
kfp.v2.compiler.Compiler().compile(
    pipeline_func=recommender_pipeline, package_path=pipeline_filename
)
