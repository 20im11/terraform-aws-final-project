```
                          Internet
                              │
        ┌─────────────────────┴──────────────────────┐
        │                                             │
  Tier 1: Frontend                            Tier 2: Backend
  S3 Static Website                           ALB (public subnets, :80)
  ┌──────────────┐   cross-region                   │ :5000
  │ primary (eu- │   replication            ECS Fargate service (2 tasks)
  │ central-1)   │ ───────────────▶         Python/Flask app (private subnets)
  └──────────────┘   ┌──────────────┐              │ :5432
                     │ replica (eu- │       Tier 3: RDS PostgreSQL
                     │ west-1)      │       (private DB subnets)
                     └──────────────┘
                                            Egress to internet via NAT Gateway
```
