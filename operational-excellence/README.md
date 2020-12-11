# Operational Excellence

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