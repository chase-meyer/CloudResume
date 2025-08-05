#!/bin/bash

# Deploy resource groups
az deployment sub create --location centralus --template-file main.bicep

# Deploy resume resources
az deployment group create --resource-group resume-resources --template-file resume-rg.bicep --parameters @resume-params.json

# Deploy domain resources
az deployment group create --resource-group domain-resources --template-file domain-rg.bicep --parameters dnsZoneName=chase-meyer.space