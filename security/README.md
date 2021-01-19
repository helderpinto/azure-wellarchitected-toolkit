# Security

The questions and initiatives below are based on the [Security pillar of the Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework/security/overview), on the [Microsoft Security Best Practices](https://docs.microsoft.com/en-us/security/compass/compass) (formerly known as the Azure Security Compass or Microsoft Security Compass) and on the [Azure Security Benchmark](https://docs.microsoft.com/en-us/azure/security/benchmarks/overview). Reflect on each question and priorize/plan the initiatives of the Security playbook.

## Questions to make

* What design considerations did you make in your workload in regards to security?
* What considerations for compliance and governance do you need to take?
* How are you managing encryption for this workload?
* How are you managing identity for this workload?
* How have you secured the network of your workload?
* What tradeoffs do you need to make to meet your security goals?
* How are you ensuring your critical accounts are protected?

## Initiatives

### Validate security best practices are applied

* Review whether the most important [Azure Identity Management best practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/identity-management-best-practices) are put in place. Some examples:
    * Validate well-defined roles and responsibilities implemented as Azure RBAC (via Management Groups) and Azure AD roles, ideally with Azure AD PIM. For enterprise scenarios, you can find [here](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/enterprise-scale/identity-and-access-management) a good reference for a typical roles and responsibilities/permissions matrix.
    * Validate universal usage of Azure AD-based authentication into services (Storage Accounts and Azure SQL Server are some examples)
    * Validate identity lifecycle management (Access Reviews)
    * Enforce Conditional Access (at least for Azure administrators)
    * Promote usage of Managed Identities instead of Service Principals
    * Monitor identity risk with Identity Protection
    * Implement Azure AD break-glass accounts
    * Implement separate accounts for administrators
    * Ensure on-premises AD administrators are not synced to Azure AD
* Monitor security posture with Azure Security Center (ASC) and the Secure Score. Check ASC settings (default Log Analytics workspace, auto-provisioning or notification contacts). Ensure you periodically review and plan remediations for ASC recommendations.
* Review IaaS network security - network segmentation best practices, Network Security Groups applied to subnets with rules following best practices, correct usage of UDRs and Virtual Appliances such as Azure Firewall, or avoiding direct VM Internet connectivity are some examples. Other initiatives below provide useful pointers to specific actions that contribute to the overall network security health.
* Review IaaS compute security ([best practices overview](https://docs.microsoft.com/en-us/azure/virtual-machines/security-recommendations))
* Review PaaS native security controls. There are checklists for example for [Storage Accounts](https://docs.microsoft.com/en-us/azure/storage/blobs/security-recommendations) or [SQL Database](https://docs.microsoft.com/en-us/azure/azure-sql/database/security-best-practice), but all other PaaS services have their checklists as well.
* Enforce security best practices with Azure Policy. Besides the policies built into Azure Security Center, there are other built-in Policies or custom ones that you should also consider:
    * Microsoft IaaSAntimalware extension should be deployed on Windows servers (/providers/Microsoft.Authorization/policyDefinitions/9b597639-28e4-48eb-b506-56b05d366257)
    * Flow log should be configured for every network security group (/providers/Microsoft.Authorization/policyDefinitions/c251913d-7d24-4958-af87-478ed3b9ba41)
    * [CUSTOM - Network Interfaces must not have Public IPs directly attached](policy/network-nic-withpublicip-auditdeny.json) (audit/deny)
    * [CUSTOM - NSGs must not have Any to Any rules](policy/network-nsg-allowanytoany-auditdeny.json) (audit/deny)
    * [CUSTOM - NSGs must have a Deny All inbound rule](policy/network-nsg-inbound-denyall-auditifnotexists.json)
    * [CUSTOM - NSGs must have a Deny All outbound rule](policy/network-nsg-outbound-denyall-auditifnotexists.json)
    * [CUSTOM - NSGs must not have Inbound rules for Any/Internet sources](policy/network-nsg-inbound-unauthorizedsources-auditdeny.json) (audit/deny)
    * [CUSTOM - NSGs must not have Inbound rules allowing management ports for Any/Internet sources](policy/network-nsg-inbound-unauthorizedsourcesports-auditdeny.json) (audit/deny)
    * [CUSTOM - NSGs must not have Outbound rules for Any destination](policy/network-nsg-outbound-anydestination-auditdeny.json) (audit/deny)
    * [CUSTOM - Only Standard SKU Public IPs are allowed](policy/network-publicip-basic-auditdeny.json) (audit/deny)    
    * [CUSTOM - Subnets must be associated with a NSG](policy/network-subnet-withoutnsg-auditdeny.json) (audit/deny)    
* Implement threat protection with Azure Defender
* Implement SIEM/SOAR with Azure Sentinel
* Collect and centralize audit and security logs from Azure Activity, Azure AD (incl. Sign-in logs), PaaS services (SQL, Key Vault) or NSG (flow logs)
* Implement patch management with Azure Update Management
* Promote usage of Private Link for private network-only access to PaaS resources
* Assess the need for protecting public-facing web applications with a Web Application Firewall (WAF) for Azure Front Door or Application Gateway.
* Validate data encryption at rest and in transit ([see some best practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/data-encryption-best-practices)).

### Incorporate security in release engineering procedures

* AzSK
* Pen testing

## Tools

* NSG assessments (Subnets and VMs without NSGs, NSG rules - improve to include priority)
* AzGovViz
* Other assessment tools
* NSG Changes workbook (original from [Brad Watts](https://github.com/bwatts64/AzureMonitor/blob/master/Workbooks/NSGWorkbook.json))