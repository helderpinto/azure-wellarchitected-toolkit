# Cost Optimization

[Docs](https://docs.microsoft.com/en-us/azure/architecture/framework/cost/)

* Capture requirements (compute, storage, traffic, security, high availability, business continuity, monitoring, management & automation)
    * Estimate costs
    * Review architecture
* Use cost management tools
    * Implement resource tagging policies for cost allocation with Azure Policy
    * Based on cost estimates, set up budgets and alerts (Cost Management)
    * Establish procedure for periodic Cost Management reporting and Azure Advisor reviews
        * Cost Management in Azure Portal
        * [Cost Management connector for Power BI](https://docs.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management)
        * [Cost Management App](https://appsource.microsoft.com/en-US/product/power-bi/costmanagement.azurecostmanagementapp)
    * Give costs visibility to teams with appropriate Azure RBAC
    * Identify custom cost optimization opportunities with the Azure Optimization Engine
* Use the right consumption model
    * Buy Reserved Instances
    * Leverage Azure Hybrid Benefit
    * Serverless/consumption-based vs. permanent compute allocation
    * Consolidate resources when possible (e.g., containerization, multiple databases in same engine/pool, multiple web apps in same App Service plan, etc.)
    * Implement auto-scaling or automated shutdown/startup
* Standardize resources usage
    * Implement resource consumption rules with Azure Policy
    * Automate resource provisioning with ARM templates and Azure DevOps or Azure Automation
