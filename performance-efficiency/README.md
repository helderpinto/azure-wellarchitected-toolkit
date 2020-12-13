# Performance Efficiency

## Questions to make

* How are you designing your workload to scale?
* How are you thinking about performance?
* How are you handling user load?
* How are you ensuring you have sufficient capacity?
* How are you managing your data to handle scale?
* How are you monitoring to ensure the workload is scaling appropriately?

## Actions

[Docs](https://docs.microsoft.com/en-us/azure/architecture/framework/scalability/overview)

* Review database technology and sizing, considering strategies such as sharding or eventual consistency
* Review VM sizing
* Review microservices strategy for scalability and performance efficiency
* Implement database connection pooling
* Implement data compression and caching (application cache, HTTP caching, CDN, etc.)
* Review locking strategy for data consistency while leveraging async calls and waits
* Process faster by implementing queues, batching requests, and background jobs
* Avoid sticky sessions and session affinity
* Implement auto-scaling or preemptive/scheduled scaling
* Identify performance bottlenecks and performance goals
* Implement load testing with Azure DevOps
* Prepare for large scale events, together with business and marketing teams
* Optimize database queries
* Implement overall monitoring strategy for scalability