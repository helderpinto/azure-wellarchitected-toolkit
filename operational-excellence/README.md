# Operational Excellence

TODO: detail initiatives

## Questions to make 

* Have you defined key scenarios for your workload and how they relate to operational targets and non-functional requirements?
* How are you monitoring your resources?
* How do you interpret the collected data to inform about application health?
* How do you visualize workload data and then alert relevant teams when issues occur?
* How are you using Azure platform notifications and updates?
* What is your approach to recovery and failover?
* How are scale operations performed?
* How are you managing the configuration of your workload?
* What operational considerations are you making regarding the deployment of your workload?
* What operational considerations are you making regarding the deployment of your infrastructure?
* How are you testing and validating your workload?
* What processes and procedures have you adopted to optimize workload operability?

## Initiatives

[Docs](https://docs.microsoft.com/en-us/azure/architecture/framework/devops/overview)

* Establish a CI/CD pipeline
    * Source control with Azure DevOps or GitHub
    * Release management with Azure DevOps or GitHub Actions
* Implement Infrastructure as Code
    * Declare your Azure environment with ARM Templates
    * Declare your operating systems configuration with Azure Automation DSC
    * Declare your infrastructure conventions (e.g., naming) and policies (e.g., tagging, security, cost) with Azure Policy as code
* Monitor your workload performance and health
    * Application and platform monitoring with Azure Monitor Insights (Application, Virtual Machines, Containers, Network, etc.)
    * Network performance and patterns with Connection Monitor, Traffic Analytics
    * Export application and platform logs to Azure Log Analytics for monitoring and auditing purposes
    * Subscription and Management Group Activity Logs
        * Diagnostic Logs (for most PaaS resources)
        * Azure AD logs
        * DNS Analytics
        * SQL Analytics
    * Establish procedure for periodic Azure Advisor reviews
* Monitor Azure platform limits and issues
    * Implement Azure Service Health alerts
    * Build an inventory of your Azure environment with the Azure Optimization Engine
    * Monitor Azure resource quotas with the Azure Optimization Engine
* Automate operational tasks with Azure Automation, Azure Functions or Logic Apps
* Increase workload robustness with automated and manual testing
    * Test plans with Azure DevOps
    * Blue/green deployments, canary releases, A/B testing
    * Stress tests, business continuity drills, fault injection