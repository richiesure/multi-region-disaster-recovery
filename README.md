# Multi-Region Disaster Recovery

High-availability architecture with automatic data replication across AWS regions, health monitoring, and failover capabilities.

## What Was Built

### Infrastructure Components
- **Primary Region (eu-west-2 London)**: Main production environment
- **Secondary Region (eu-west-1 Ireland)**: Disaster recovery standby
- **S3 Cross-Region Replication**: Automatic data sync
- **Route53 Health Checks**: Monitors primary region availability
- **CloudWatch Alarms**: Alerts when primary becomes unhealthy
- **SNS Notifications**: Email alerts for DR events

## Architecture
```
                    NORMAL OPERATION
                    
    Users ──────────────▶ Primary Region (eu-west-2)
                              │
                              │ S3 Replication
                              ▼
                         Secondary Region (eu-west-1)
                         [Standby - Data Synced]


                    DURING DISASTER
                    
    Users ─────────X───▶ Primary Region (eu-west-2)
         │                    ❌ FAILED
         │
         └─────────────▶ Secondary Region (eu-west-1)
                              ✅ ACTIVE
```

## DR Metrics

| Metric | Target | Achieved |
|--------|--------|----------|
| RTO (Recovery Time) | < 15 min | ✅ Yes |
| RPO (Data Loss) | < 1 min | ✅ Yes |
| Health Check Interval | 30 sec | ✅ Configured |
| Replication Lag | Near real-time | ✅ Verified |

## Failover Process

### Automatic Detection
1. Route53 health check pings primary every 30 seconds
2. After 3 failures, CloudWatch alarm triggers
3. SNS sends email alert to team

### Manual Failover Steps
```bash
# 1. Verify primary is down
./dr-failover.sh

# 2. Update DNS to secondary region
# (In production: Route53 failover routing does this automatically)

# 3. Deploy application in secondary region
# Use existing Terraform/ECS configs with eu-west-1

# 4. Verify secondary is serving traffic
curl http://secondary-app-url/health
```

## Usage

### Check DR Status
```bash
./dr-failover.sh
```

### Test Replication
```bash
# Upload to primary
aws s3 cp testfile.txt s3://dr-primary-494376414941/ --region eu-west-2

# Verify in secondary (wait 30 seconds)
aws s3 ls s3://dr-secondary-494376414941/ --region eu-west-1
```

## Cost

| Resource | Monthly Cost |
|----------|-------------|
| S3 Storage (both regions) | ~$1 |
| S3 Replication | ~$0.50 |
| Route53 Health Check | $0.50 |
| CloudWatch Alarm | $0.10 |
| **Total** | **~$2/month** |

## Files
```
multi-region-disaster-recovery/
├── main.tf            # Multi-region infrastructure
├── outputs.tf         # Output values
├── dr-failover.sh     # DR status and failover script
└── README.md
```
