import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """
    Triggered by S3 ObjectCreated events.
    Logs the name of every uploaded file to CloudWatch Logs.
    """
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key    = record["s3"]["object"]["key"]
        logger.info(f"Image received: {key} (bucket: {bucket})")

    return {
        "statusCode": 200,
        "body": json.dumps("Processed successfully")
    }
