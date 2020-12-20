# Security

## Questions to make

* What design considerations did you make in your workload in regards to security?
* What considerations for compliance and governance do you need to take?
* How are you managing encryption for this workload?
* How are you managing identity for this workload?
* How have you secured the network of your workload?
* What tradeoffs do you need to make to meet your security goals?
* How are you ensuring your critical accounts are protected?

## Actions

[Docs](https://docs.microsoft.com/en-us/azure/architecture/framework/security/overview)
[Security Compass](https://docs.microsoft.com/en-us/security/compass/compass)

* Review Azure Identity Management [best practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/identity-management-best-practices)
* Review PaaS native security controls
* Enforce security best practices with Azure Policy
* Monitor security posture with Azure Security Center and Secure Score
* Implement threat protection with Azure Defender
* Review network security (segmentation, NSGs, Firewall, WAF for Front Door/Application Gateway, direct VM Internet connectivity)
* Validate universal usage of Azure AD-based authentication into services
* Promote usage of Managed Identities vs. Service Principals
* Evaluate security using benchmarks
* Monitor identity risk with Identity Protection
* Validate well-defined roles and responsibilities implemented as Azure RBAC (via Management Groups) and Azure AD roles, ideally with Azure AD PIM
* Implement patch management with Azure Update Management
* Validate identity lifecycle management (Access Reviews)
* Configure central security log management
* Collect audit logs from Azure Activity, Azure AD (incl. Sign-in logs), PaaS services (SQL, Key Vault), NSG (flow logs)
* Implement SIEM with Azure Sentinel
* Implement admin workstation security
* Enforce Conditional Access for admins
* Promote usage of Private Link for network-only access to PaaS resources
* Validate data encryptin at rest and in transit

## Tools

* Policies
* NSG assessments (Subnets and VMs without NSGs, NSG rules - improve to include priority)