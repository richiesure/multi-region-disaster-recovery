#!/bin/bash
echo "=========================================="
echo "DISASTER RECOVERY STATUS CHECK"
echo "=========================================="
echo ""

PRIMARY_REGION="eu-west-2"
SECONDARY_REGION="eu-west-1"

echo "1. Primary Region Health Check:"
aws route53 get-health-check-status \
  --health-check-id $(terraform output -raw health_check_id) \
  --query 'HealthCheckObservations[0].StatusReport.Status' \
  --output text 2>/dev/null || echo "Checking..."
echo ""

echo "2. S3 Replication Status:"
PRIMARY_BUCKET=$(terraform output -raw primary_bucket)
SECONDARY_BUCKET=$(terraform output -raw secondary_bucket)

PRIMARY_COUNT=$(aws s3 ls s3://$PRIMARY_BUCKET --region $PRIMARY_REGION --recursive | wc -l)
SECONDARY_COUNT=$(aws s3 ls s3://$SECONDARY_BUCKET --region $SECONDARY_REGION --recursive | wc -l)

echo "   Primary bucket objects: $PRIMARY_COUNT"
echo "   Secondary bucket objects: $SECONDARY_COUNT"
echo ""

echo "3. Failover Instructions:"
echo "   If primary fails:"
echo "   - Update DNS to point to secondary region"
echo "   - Deploy application in eu-west-1"
echo "   - Use secondary S3 bucket for data"
echo ""

echo "4. Recovery Time Objective (RTO): < 15 minutes"
echo "5. Recovery Point Objective (RPO): < 1 minute (S3 replication)"
echo ""
echo "=========================================="
