#!/usr/bin/env bash
set -e

BUCKET_NAME="nemo-dev-photos"

awslocal s3 mb s3://$BUCKET_NAME || true

awslocal s3api put-bucket-cors --bucket "$BUCKET_NAME" --cors-configuration '{
  "CORSRules": [{
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET","PUT","POST","HEAD"],
    "AllowedOrigins": ["*"],
    "ExposeHeaders": ["ETag"]
  }]
}'
