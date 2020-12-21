# Cost Optimization

Making a cost-effective usage of Azure is a priority for all organizations running applications and services in the cloud. The questions and initiatives below are based on the [Cost Optimization pillar of the Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework/cost/). Reflect on each question and priorize/plan the initiatives of the Cost Optimization playbook.

## Questions to make 

* What actions are you taking to optimize cloud costs?
* How do you ensure that cloud resources are appropriately provisioned?
* How is your organization modeling cloud costs?
* How do you manage the storage footprint of your digital assets?
* How are you monitoring your costs?
* What trade-offs have you made to optimize for cost?

## Initiatives

### Capture requirements

The agility provided by the cloud and its pay-per-use consumption model is an opportunity for us to continuously question the requirements of our workloads and look for optimal resource usage according to our needs. No matter we are still in the conception stage of our solution or already managing it in production, evaluating the right Azure services architecture and sizing will determine how cheap or expensive our solution is.

Review your workload requirements in terms of compute, storage, traffic, security, high availability, business continuity, monitoring, management and automation:
* Estimate or measure its costs and ask yourself whether the relative weight or absolute value of each service is aligned with its importance for the solution.
* If necessary, make adjustments to the workload architecture to meet its requirements in a cost optimal manner.

Given its implications and effort required, this is for sure the most demanding initiative. The best and more natural way of incorporating it into your organization practices is bringing cost to all architectural discussions and making it an architectural perspective as important as security, user experience or performance. For a deeper discussion on workload requirements, visit the [Well-Architected guidance on the subject](https://docs.microsoft.com/en-us/azure/architecture/framework/cost/design-capture-requirements).

### Use cost management tools

Don't get it wrong, but using the cloud without visibility over how you spend your money nor how you can optimize your costs is a posture as irresponsible as overlooking security. Here are some actions that should be part of your todo list:

* Implement [resource tagging policies](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/tag-policies) for cost allocation with Azure Policy, enforcing (denying deployments without tags) and/or automating tag inheritance from resource group tags.
* Based on expected monthly or daily costs, set up [Cost Management budgets and alerts](https://docs.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets)
* Establish procedure for periodic Cost Management reporting and Azure Advisor reviews
    * [Cost Management](https://docs.microsoft.com/en-us/azure/cost-management-billing/costs/quick-acm-cost-analysis) in Azure Portal
        * Build shared reports that provide insights about how costs are distributed and evolve over time (e.g., daily costs per meter category or per resource group over the last 30 days, monthly costs per meter category over the last year, etc.)
        * Look for changes in the costs pattern that may be a sign of usage spill
    * [Cost Management connector for Power BI](https://docs.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management)
        * With this connector, you can build your own custom rich Cost Management reports in Power BI Desktop.
        * Recommended for scenarios not supported by Azure Cost Management in the Azure portal.
    * [Cost Management Power BI App](https://docs.microsoft.com/en-us/azure/cost-management-billing/costs/analyze-cost-data-azure-cost-management-power-bi-template-app)
        * Get insights about Azure Hybrid Benefit and Reserved Instances usage and savings
        * A Power BI Pro license is required to install and use the app.
        * To connect to data, you must use an Enterprise Administrator account. The Enterprise Administrator (read only) role is supported.
* Give costs visibility to teams with [appropriate Azure RBAC](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/track-costs#provide-the-right-level-of-cost-access). Remember: **if we don't know what we spend, we don't care about how much we spend**.
* Identify custom cost optimization opportunities with the [Azure Optimization Engine](https://github.com/helderpinto/AzureOptimizationEngine)
    * Deploy the engine in your environment and assess the initial results
    * Develop custom recommendations if needed
  
### Use the right consumption model

* Buy Reserved Instances
* Leverage Azure Hybrid Benefit
* Serverless/consumption-based vs. permanent compute allocation
* Consolidate resources when possible (e.g., containerization, multiple databases in same engine/pool, multiple web apps in same App Service plan, etc.)
* Implement auto-scaling or automated shutdown/startup

### Standardize resources usage

* Implement resource consumption rules with Azure Policy
* Automate resource provisioning with ARM templates and Azure DevOps or Azure Automation

### Eliminate waste

* Clean diagnostics logs