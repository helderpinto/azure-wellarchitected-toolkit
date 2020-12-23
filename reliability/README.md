# Reliability

TODO: detail initiatives

## Questions to make

* What reliability targets and metrics have you defined for your application?
* How have you ensured that your application architecture is resilient to failures?
* How have you ensured required capacity and services are available in targeted regions?
* How are you handling disaster recovery for this workload?
* What decisions have been taken to ensure the application platform meets your reliability requirements?
* What decisions have been taken to ensure the data platform meets your reliability requirements?
* How does your application logic handle exceptions and errors?
* What decisions have been taken to ensure networking and connectivity meets your reliability requirements?
* What reliability allowances for scalability and performance have you made?
* What reliability allowances for security have you made?
* What reliability allowances for operations have you made?
* How do you test the application to ensure it is fault tolerant?
* How do you monitor and measure application health?

## Initiatives

[Docs](https://docs.microsoft.com/en-us/azure/architecture/framework/resiliency/overview)

* Validate whether workload architecture (redundancy at both the application and infrastructure levels, dependencies, fault tolerance) meets availability targets (SLA, RTO, RPO) - Availability Sets with Managed Disks, Availability Zones, Geo-Redundancy, Data Replication, Azure Site Recovery.
* Test for common failure scenarios by triggering actual failures or by simulating them
* Design and automate release process to maximize availability, including rollback procedures
* Perform a failure mode analysis
* Validate data and keys/secrets backup strategy
* Validate disaster recovery strategy
* Validate hybrid networking reliability
* Protect public endpoints with DDoS protection
* Enforce reliability best practices with Azure Policy
