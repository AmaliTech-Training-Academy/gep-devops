
# Event Planner Platform - DevOps Infrastructure Documentation

## Grafana Monitoring Usage Guidelines

**Author:** DevOps Team  
**Last Updated:** November 18, 2025  
**Version:** 1.0.0

This document provides practical guidance for using Grafana dashboards across different roles and responsibilities. Whether you're a DevOps engineer, developer, product manager, or business stakeholder, this guide helps you understand and interpret the available metrics.

**Access URL**: `https://api.sankofagrid.com/monitoring/`

**Default Credentials:**

- Username: `admin`
- Password: (provided separately via secure channel)

**Note**: Change your password immediately after first login.

---

## For All Users

### Getting Started with Grafana

#### 1. Logging In

1. Navigate to `https://api.sankofagrid.com/monitoring/`
2. Enter username and password
3. Click **Sign In**
4. (Optional) Set up two-factor authentication for enhanced security

#### 2. Navigating Grafana

**Main Menu** (click hamburger icon ☰ in top-left):

- **Home**: Dashboard overview and recent dashboards
- **Dashboards**: Browse and search all available dashboards
- **Explore**: Ad-hoc data exploration and queries
- **Alerts**: View and manage alert status
- **Configuration**: User settings, preferences, and password changes (Admin only)

**Search** (top-center):

- Use the search bar to quickly find dashboards
- Type partial dashboard names to filter results
- Press Enter to navigate

**User Menu** (profile icon, top-right):

- **Preferences**: Change theme, timezone, language
- **Change Password**: Update your login password
- **Sign Out**: Log out of Grafana

#### 3. Dashboard Navigation

**Time Range Selector** (top-right, usually shows "Last 6 hours"):

- Click to change the time range
- Options: Last 5 minutes, 15 minutes, 1 hour, 6 hours, 24 hours, 7 days, 30 days, or custom range
- Useful for analyzing trends over different periods

**Refresh Rate** (next to time range):

- Default: Auto-refresh every 30 seconds
- Click to change refresh frequency (off, 5s, 10s, 30s, 1m, 5m, 10m, 30m, 1h)
- Lower refresh rates = more frequent updates (affects Grafana performance)

**Timezone** (in dashboard):

- Defaults to UTC
- Change in your preferences to match your local timezone

#### 4. Reading Dashboard Panels

**Panel Types and Interpretation:**

| Panel Type | Purpose | How to Read |
|-----------|---------|------------|
| **Time Series** | Metrics over time | Look at trends, spikes, and baseline values. Higher = more activity/resources |
| **Gauge** | Current value progress | Single metric at current moment. Position on the scale indicates severity |
| **Stat** | Single metric value | Shows a single number. Compare to historical baseline or threshold |
| **Table** | Structured data | Read rows and columns like a spreadsheet. Sort by clicking column headers |
| **Pie Chart** | Proportion breakdown | Slice size = proportion of total. Useful for showing composition |
| **Bar Chart** | Comparison across categories | Bar height = value. Useful for comparing metrics across services/regions |
| **Heatmap** | Density over time | Color intensity = frequency. Yellow/red = high density, blue = low |

**Panel Interactions:**

- **Hover**: Move mouse over a panel to see tooltip with exact values
- **Click**: Some panels support drill-down for detailed data
- **Zoom**: In time series graphs, click and drag to zoom into a time range
- **Legend**: Click legend items to show/hide specific series

---

## For DevOps Engineers & SREs

### Infrastructure Dashboard

This dashboard monitors the health and performance of your infrastructure components.

#### Key Metrics to Monitor

**ECS Cluster Health:**

- **CPU Utilization**: Track if cluster is approaching resource limits (target: < 70%)
  - If trending high: Consider scaling up services or optimizing resource requests
  - If spiky: Investigate which services are consuming resources

- **Memory Utilization**: Similar to CPU (target: < 80%)
  - Memory leaks appear as steadily increasing memory usage
  - Action: Review application logs and restart affected services

- **Task Count (Running vs Desired)**:
  - Running < Desired: Some tasks failed to start or are restarting
  - Action: Check CloudWatch logs and task definitions for errors

- **Network I/O**: Inbound vs Outbound traffic
  - Unusual spikes: Could indicate DDoS attack or data exfiltration
  - Action: Review security logs and ALB access logs

**RDS Database Metrics:**

- **CPU Utilization**: Database processing load (target: < 60% baseline, < 80% peak)
  - Sustained high CPU: Slow queries or missing indexes
  - Action: Run EXPLAIN ANALYZE on slow queries; consider query optimization

- **Database Connections**: Active connection count
  - Approaching max connections: Application connection pooling issue
  - Action: Review application logs; check if connections are being properly closed

- **Read/Write IOPS**: Input/output operations per second
  - High sustained IOPS: Normal for heavy workloads
  - Sudden spikes: Could indicate batch jobs or runaway queries
  - Action: Check CloudWatch logs for long-running transactions

- **Storage Space**: Disk usage
  - Approaching limit: Database performance degrades
  - Action: Run VACUUM ANALYZE; archive old data; increase storage

- **Replication Lag**: (if read replicas exist)
  - > 1 second: Replication bottleneck
  - Action: Check network connectivity; review read replica resource usage

**ElastiCache/Redis Metrics:**

- **Cache Hit Rate**: Percentage of requests served from cache (target: > 80%)
  - Low hit rate: Application may not be caching effectively
  - Action: Review application caching strategy

- **Evictions**: Items removed to make room for new data
  - High evictions: Cache too small for working dataset
  - Action: Increase cache size or optimize cache key strategy

- **Connection Count**: Active Redis connections
  - Unusually high: Possible connection leak in applications
  - Action: Review application connection management

#### When to Alert

Create custom alerts in Grafana for:

| Metric | Threshold | Severity | Action |
|--------|-----------|----------|--------|
| ECS CPU | > 80% for 10 min | High | Scale service or optimize code |
| ECS Memory | > 85% for 10 min | High | Increase task memory or restart |
| RDS CPU | > 75% for 15 min | Medium | Optimize queries or scale up |
| RDS Connections | > 80% of max | Medium | Review connection pooling |
| Cache Hit Rate | < 70% for 30 min | Low | Review caching strategy |
| RDS Storage | > 90% full | High | Expand storage immediately |

#### Common Issues & Diagnostics

**High CPU, Low Network**:

- Likely: Compute-intensive processing (good)
- Action: Monitor and ensure scaling is adequate

**High Network, Low CPU**:

- Likely: Data transfer bottleneck or network I/O waiting
- Action: Review network configurations; check for large data transfers

**Increasing Memory with Stable CPU**:

- Likely: Memory leak in application
- Action: Restart affected services; review code changes

**Sudden Spikes in All Metrics**:

- Likely: Heavy batch job or traffic spike
- Action: Check for scheduled jobs; review auto-scaling policies

### Performance Dashboard

Monitors application response times, error rates, and system behavior.

#### Key Metrics

**API Response Times** (p50, p95, p99):

- **p50 (Median)**: 50% of requests complete within this time. Shows typical user experience
- **p95 (95th Percentile)**: 95% of requests within this time. Shows experience for most users
- **p99 (99th Percentile)**: 99% of requests within this time. Shows worst-case experience

**Targets:**

- p50: < 200ms
- p95: < 500ms
- p99: < 1000ms

**Interpretation:**

- All percentiles rising: System overload or degradation
- p99 rising but p50 stable: Occasional slow requests (investigate specific endpoints)
- p99 >> p95: Long-tail latency (cache misses, occasional slow queries)

**Error Rates by Service**:

- HTTP 4xx (Client Errors): Application issue or invalid requests
  - Spike: Check for deployment; review error logs
- HTTP 5xx (Server Errors): Server-side issues
  - **Action: Immediate investigation required**

**Request Volume**:

- Sudden drop: Service may be down or unreachable
- Sudden spike: DDoS attack or marketing campaign success (verify)

**Database Query Performance**:

- Slow query count: Number of queries exceeding threshold
  - Action: Identify slow queries; add indexes; optimize queries

---

## For Developers

### Application Monitoring Dashboard

Understand how your microservices are performing and interact with infrastructure.

#### Service-Specific Metrics

**For Your Service:**

1. **Request Rate** (requests per second):
   - Baseline: Know your typical traffic pattern
   - Spike: Indicates increased load or traffic burst
   - Drop: May indicate circuit breaker or upstream issue

2. **Error Rate** (percentage of failed requests):
   - 0% errors: Ideal state
   - > 1%: Investigate immediately
   - Action: Check service logs; search for exception messages

3. **Response Time** (p50, p95, p99):
   - Increasing trend: Could indicate resource exhaustion or algorithmic slowdown
   - Sudden jump: Likely caused by recent deployment or infrastructure change

4. **Throughput** (requests processed per second):
   - Directly related to server CPU and memory usage
   - If limited by infrastructure: Work with DevOps on scaling

#### Database Query Monitoring

**From Your Application's Perspective:**

- **Query Count**: How many queries your service is executing
  - Increasing without traffic increase: Possible N+1 query problem
  - Action: Review ORM/query execution; add caching

- **Query Duration**: How long queries take
  - > 100ms: Investigate if necessary (may indicate missing index)
  - Action: Work with DBA on query optimization

- **Connection Pool Usage**:
  - Trending upward: Connection leak possible
  - Maxed out: Application can't get new connections; requests fail

#### Debugging Workflow

**When errors spike:**

1. Check the **Error Rate** panel to confirm
2. Click on error rate time series to see which endpoints are failing
3. Search service logs in **CloudWatch Logs** for stack traces
4. Check **Infrastructure Dashboard** for resource exhaustion
5. Review recent code deployments to identify changes
6. If issue persists, check **dependency dashboards** (databases, caches, external services)

**When response time degrades:**

1. Check **p95 and p99 latency** to understand scope
2. Identify which endpoints are slow (drill into performance dashboard)
3. Check **Database Dashboard** for slow queries
4. Check **Cache Hit Rate** for cache misses
5. Review code changes deployed in last deployment
6. If widespread degradation: Check infrastructure CPU/memory/network

#### Useful Queries to Create

```sql
-- Find slow queries from your service
SELECT 
  query,
  COUNT(*) as execution_count,
  AVG(duration_ms) as avg_duration,
  MAX(duration_ms) as max_duration
FROM audit_schema.query_log
WHERE service = 'your-service'
  AND created_at > NOW() - INTERVAL '1 hour'
GROUP BY query
ORDER BY avg_duration DESC
LIMIT 10;

-- Track error rate trend
SELECT 
  DATE_TRUNC('minute', created_at) as minute,
  COUNT(*) as total_requests,
  SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END) as errors,
  ROUND(100.0 * SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END) / COUNT(*), 2) as error_rate_percent
FROM audit_schema.request_log
WHERE service = 'your-service'
  AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY minute
ORDER BY minute DESC;
```

---

## For Product Managers & Business Stakeholders

### Executive Dashboard

High-level business metrics to understand platform performance and user engagement.

#### Key Business Metrics

**User Engagement:**

- **Active Users**: Number of unique users active in the time period
  - Day-over-day: Increasing = growing user base (good)
  - Seasonal patterns: Expect variation based on time/date
  - Action: Track growth trends; correlate with marketing campaigns

- **New Users**: New user registrations
  - Declining trend: May indicate acquisition issue
  - Action: Review marketing efforts; check if sign-up flow is working

**Event Activity:**

- **Total Events Created**: Number of events posted to platform
  - Proxy for content creator activity
  - Increasing = healthy platform engagement
  - Seasonal: Expect peaks around weekends, holidays

- **Total Bookings**: Number of bookings made by users
  - Direct indicator of revenue potential
  - Booking Rate = Bookings / Events (conversion efficiency)
  - Action: Track daily/weekly/monthly trends

**Revenue Metrics:**

- **Total Revenue** (today, this month, this quarter):
  - Primary KPI for business health
  - Compare month-over-month growth
  - Seasonal considerations (holidays, events)

- **Average Order Value (AOV)**:
  - Revenue / Bookings
  - Increasing AOV = better monetization (premium bookings)
  - Decreasing AOV = customers choosing cheaper options

- **Payment Success Rate**:
  - Failed payments / Total payment attempts
  - Target: > 99%
  - Lower rate: Investigate payment processor issues

**Platform Health:**

- **Service Uptime**: Percentage of time platform was available
  - Target: > 99.9% (4.3 minutes downtime per month acceptable)
  - < 99%: Major issue affecting users
  - Action: Check infrastructure status; review recent deployments

- **Error Rate**: Percentage of user requests that resulted in errors
  - Target: < 0.1%
  - > 1%: Users experiencing issues; revenue impact possible
  - Action: Escalate to DevOps/Dev teams for investigation

#### Understanding Trends

**Day-over-Day Comparison:**

- Useful for: Identifying daily patterns, short-term changes
- Example: "Bookings increased 15% today vs yesterday"

**Week-over-Week Comparison:**

- Useful for: Identifying weekly cycles, temporary anomalies
- Example: "Bookings are 20% higher on weekends"

**Month-over-Month Comparison:**

- Useful for: Long-term trends, business growth
- Example: "Revenue grew 8% this month compared to last month"

**Year-over-Year Comparison:**

- Useful for: Seasonal patterns, annual growth
- Example: "December is 40% busier than average (holiday season)"

#### Setting Targets & Goals

**Historical Analysis Approach:**

1. Review past 3 months of data
2. Calculate average (baseline)
3. Identify trend (increasing, stable, decreasing)
4. Set target as 10-20% above baseline

**Example:**

- October bookings: 1,200
- November bookings: 1,340
- December bookings: 1,510
- Average: 1,350
- Target for January: 1,485 (10% above average)

#### Reporting to Executives

**Weekly Executive Summary Format:**

```text
Period: [Date Range]

KEY METRICS:
- Active Users: 12,500 (↑ 8% vs last week)
- Total Bookings: 3,240 (↓ 2% vs last week)
- Revenue: $485,600 (↑ 12% vs last week)
- Platform Uptime: 99.98% (healthy)
- Error Rate: 0.08% (healthy)

NOTABLE TRENDS:
- Weekend bookings 35% higher than weekdays
- Payment success rate at 99.8% (excellent)
- New user signups up 15% (likely from marketing campaign)

ACTIONS REQUIRED:
- None - all metrics healthy
- Continue current marketing strategy
```

#### Dashboard Drill-Down Guide

**When total bookings decline:**

1. Check **Active Users**: If users are down, engagement issue
2. Check **Booking Rate** (bookings per active user): If rate down, conversion issue
3. Check **Event Count**: If events down, fewer opportunities to book
4. Check **Platform Health**: If errors high, platform stability issue
5. Check **Payment Success Rate**: If down, payment processing issue

**When revenue increases but bookings don't:**

- Likely: Users booking more premium/expensive events
- Action: Celebrate! This means monetization is improving

**When revenue decreases despite stable bookings:**

- Likely: Users booking cheaper events
- Action: Review pricing strategy; consider value-added services

---

## For Finance & Operations

### Cost Analysis Dashboard

Monitor infrastructure costs and ROI.

#### Key Cost Metrics

**Infrastructure Costs:**

- **ECS Fargate Costs**: Task running costs
  - Varies based on vCPU and memory allocation
  - Optimization: Right-size task definitions; use autoscaling

- **RDS Costs**: Database instance costs
  - Largest cost component typically
  - Optimization: Use reserved instances for production

- **ElastiCache Costs**: Caching layer
  - Cost per node per hour
  - Optimization: Right-size cache based on hit rate

- **Data Transfer Costs**:
  - Egress from AWS (to internet): Most expensive
  - Cross-region: Less expensive but still significant
  - Optimization: Use CloudFront CDN for static assets

- **Daily/Monthly Spend Trend**:
  - Identify cost growth patterns
  - Anomalies indicate inefficiencies

#### Cost Optimization Opportunities

**High Priority:**

- Identify over-provisioned resources (CPU/memory not fully utilized)
- Review database queries for N+1 problems (cause unnecessary database calls)
- Use auto-scaling to match capacity to actual demand

**Medium Priority:**

- Implement caching to reduce database load
- Batch database operations to reduce transaction overhead
- Review data transfer patterns for optimization opportunities

**Low Priority:**

- Consolidate infrequently used services
- Use reserved instances for stable baseline costs

#### ROI Calculation

**Platform ROI Formula:**

```text
ROI = (Revenue - Costs) / Costs × 100%

Example:
- Monthly Revenue: $485,600
- Monthly Costs: $42,000
- Monthly Profit: $443,600
- ROI: 1,056% (very healthy)

Breakeven Point:
- Monthly Costs = $42,000
- Minimum bookings to cover costs: 42,000 / avg_booking_value
- Example: If average booking = $35, need 1,200 bookings/month to break even
```

#### Cost per User Metric

**Calculation:**

```text
Cost per Active User = Monthly Infrastructure Cost / Monthly Active Users

Example:
- Monthly Cost: $42,000
- Active Users: 12,500
- Cost per User: $3.36/month

Benchmark: 
- SaaS platforms typically target $1-5 per user per month (depending on service type)
- Event platform: $2-4 is healthy
```

---

## Alert Interpretation Guide

### Understanding Different Alert Severities

**Critical (Red)**:

- Service is down or severely degraded
- Users cannot perform key functions
- **Action**: Immediate investigation; escalate to on-call team
- **Examples**: Database unavailable, 50%+ error rate

**Warning (Yellow)**:

- Service is degraded but still functioning
- User experience affected but not completely broken
- **Action**: Investigate within next 15 minutes
- **Examples**: API latency > 1 second, 5% error rate

**Info (Blue)**:

- Informational alert; no action typically required
- Useful for tracking deployments, maintenance windows
- **Examples**: Deployment completed, maintenance window started

### Common Alert Scenarios

#### ECS Cluster CPU Exceeding Threshold

What it means: Cluster is approaching resource exhaustion
Why it matters: Services may start getting throttled or failing to deploy
Actions:

1. Check which services are consuming CPU (look at Infrastructure Dashboard)
2. Determine if temporary (spike) or sustained (growth)
3. If sustained: Scale service replicas or increase task CPU allocation
4. If spike: Wait for it to pass; update alerts if spikes are normal

#### RDS CPU High with Increasing Slow Query Count

What it means: Database is overloaded due to inefficient queries
Why it matters: Database will become unresponsive; application errors increase
Actions:

1. Find slow queries in Performance Dashboard
2. Add indexes to slow queries
3. Optimize application code to use fewer queries
4. Consider query caching
5. If urgent: Restart RDS (clears locks, often helps temporarily)

#### 5xx Error Rate Exceeds Threshold

What it means: Service is returning errors
Why it matters: Users cannot complete actions; potential revenue impact
Actions:

1. Check which service is erroring (Infrastructure Dashboard)
2. Review service logs for exception details
3. Check for recent deployments (rollback if necessary)
4. Check for resource exhaustion (CPU, memory, connections)
5. Check dependent services (database, cache, external APIs)

#### Cache Hit Rate Drops Below Target

What it means: Most cache requests are misses
Why it matters: Database is being hit harder; response times increase; costs increase
Actions:

1. Check if cache was recently cleared or restarted
2. Review cache key strategy in application code
3. Increase cache size if possible
4. Implement cache warming (pre-load frequently accessed data)

---

## Best Practices for Dashboard Use

### Daily Checks

**Every morning (takes ~5 minutes):**

1. Check **Executive Dashboard**:
   - Any overnight events (errors, spikes)?
   - Do metrics look normal compared to historical trend?

2. Check **Infrastructure Dashboard**:
   - All services green?
   - Any unusual CPU/memory usage?

3. Check **Platform Health** panel:
   - Error rate < 0.5%?
   - Uptime > 99%?

### Weekly Reviews

**Every Friday (takes ~30 minutes):**

1. Review **weekly trends** in Executive Dashboard
2. Compare to **last week** and **last month**
3. Identify any anomalies or concerning trends
4. Prepare summary for stakeholders

### Monthly Deep Dives

**First Monday of month (takes ~2 hours):**

1. Analyze **monthly performance** across all dashboards
2. Compare to budget/targets
3. Identify optimization opportunities
4. Plan infrastructure changes if needed
5. Update team on KPIs and trends

### When Something Goes Wrong

**Incident Response Checklist:**

- [ ] Confirm issue in Grafana
- [ ] Check which metric(s) are affected
- [ ] Check if it's a one-off spike or sustained problem
- [ ] Look at dependent services (did something upstream fail?)
- [ ] Check recent changes (deployments, config changes)
- [ ] Communicate status to stakeholders
- [ ] Document issue and resolution for future reference

---

## FAQ - Frequently Asked Questions

**Q: Why does my metric show a gap in data?**

A: Possible causes:

- Service was down during that period (check infrastructure dashboard)
- Data collection failed temporarily (check logs)
- Dashboard query timeout (try widening time range)

**Q: Can I create custom dashboards?**

A: Yes! (Admin/Editor role only)

- Click "Create" → "Dashboard"
- Add panels with queries from PostgreSQL or CloudWatch
- Contact your Grafana admin for assistance

**Q: How do I set up alerts for my team?**

A: (Admin role only)

- Go to Configuration → Alerting → Alert Rules
- Create rule with threshold and notification channel
- Notification options: Email, Slack, PagerDuty, etc.

**Q: Can I export dashboard data?**

A: Yes!

- Click dashboard → Share → Export
- Can download as JSON or CSV
- Useful for reports and archiving

**Q: How do I change the time range permanently?**

A: You can't globally, but you can:

- Save custom time range as a dashboard preference
- Default is "Last 6 hours" - change in your user preferences

**Q: What if I see conflicting information in different dashboards?**

A: Possible reasons:

- Dashboards query different data sources (CloudWatch vs PostgreSQL)
- Different time ranges selected
- Caching differences
- Metric aggregation differences (sum vs average)
- Contact DevOps team to clarify

---

## Support & Escalation

### Getting Help

**For Dashboard Questions:**

- Check this documentation first
- Search [Grafana official documentation](https://grafana.com/docs/grafana/latest/)
- Contact your team's Grafana admin

**For Data Accuracy Questions:**

- Confirm metric is from correct data source (CloudWatch vs PostgreSQL)
- Check data source configuration
- Verify query syntax
- Contact DevOps team

**For Metric/Alert Suggestions:**

- Document what metric would be useful
- Explain business value
- Submit to DevOps team for evaluation

**For Production Issues:**

- Report in incident channel
- Include affected metric and time range
- Include screenshots if helpful
- Escalate to on-call engineer immediately

### Contacting DevOps

**Slack Channels:**

- #incidents: Critical issues (service down)
- #devops-alerts: Non-critical infrastructure issues
- #monitoring: General monitoring and dashboard questions

**Email:**

- [devops-team@event-planner.internal](mailto:devops-team@event-planner.internal)

**On-Call:**

- Check #on-call channel for current on-call engineer
- For emergencies: Call on-call phone number (in team directory)

---

## Closing Notes

Grafana is a powerful monitoring tool that helps us understand platform health, performance, and business impact. The key to using it effectively is:

1. **Understand your baseline**: Know what "normal" looks like
2. **Set clear targets**: Have goals for key metrics
3. **Act on insights**: Use data to drive optimization
4. **Communicate findings**: Share insights with your team
5. **Iterate**: Use feedback to improve dashboards

Remember: **Monitoring without action is just numbers. Effective monitoring drives decisions.**

For questions or suggestions about this documentation, please contact the DevOps team.
