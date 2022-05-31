# Secure website deployment on Azure - GAB 2022 edition

[![Deploy To Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fnianton%2Fgab2022-bicep%2Fmain%2Fazure.deploy.json)


This is a templated deployment of a secure Azure architecture for hosting a web application application, having all the related PaaS components deployed in a virtual network leveraging Private Endpoints.

The architecture of the solution is as depicted on the following diagram:

![Artitectural Diagram](./assets/azure-deployment-diagram.png?raw=true)

## The role of each component
* **Application Gateway** -acting as Web Application Firewall, the application publishing mechanism
* **Frontend Web App** -public facing website
* **Azure Container Registry** -the container registry, accessible only within the VNET through private endpoint
* **Azure Key Vault** responsible to securely store the secrets/credentials for the PaaS services to be access by the web applications
* **Application Insights** to provide monitoring and visibility for the health and performance of the application
* **Azure SQL Database** the Microsoft SQL Server database to be used by the applications
* **Data Storage Account** the Storage Account that will contain the application data / blob files
* **Jumphost VM** the virtual machine to have access to the resources in the virtual network

<br>

---
Based on the template repository (**[https://github.com/nianton/bicep-starter](https://github.com/nianton/azure-naming#bicep-azure-naming)**) to get started with an bicep infrastructure-as-code project, including the azure naming module to facilitate naming conventions. 

For the full reference of the supported naming for Azure resource types, head to the main module repository: **[https://github.com/nianton/azure-naming](https://github.com/nianton/azure-naming#bicep-azure-naming-module)**