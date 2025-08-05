param storageAcctName string
param cosmosDbEndpoint string
param cosmosDbKey string
param apiKey string

var location = 'centralus'

// Managed identity for deployment script
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'resume-deployment-identity'
  location: location
}

// Role assignment for managed identity to access storage account
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(managedIdentity.id, storageAccount.id, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    ) // Storage Blob Data Contributor
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Static website config variables
var indexDocumentPath = 'Resume.html'
var indexDocumentContents = '<html><body><h1>Welcome to the Resume Site</h1></body></html>'
var errorDocument404Path = '404.html'
var errorDocument404Contents = '<html><body><h1>404 - Not Found</h1></body></html>'

// Storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAcctName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Enable static website using deployment script (PowerShell)
resource enableStaticWebsite 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'enable-static-website'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  dependsOn: [
    roleAssignment
  ]
  properties: {
    azPowerShellVersion: '11.0'
    scriptContent: loadTextContent('./scripts/enable-static-website.ps1')
    retentionInterval: 'PT4H'
    environmentVariables: [
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'StorageAccountName'
        value: storageAccount.name
      }
      {
        name: 'IndexDocumentPath'
        value: indexDocumentPath
      }
      {
        name: 'IndexDocumentContents'
        value: indexDocumentContents
      }
      {
        name: 'ErrorDocument404Path'
        value: errorDocument404Path
      }
      {
        name: 'ErrorDocument404Contents'
        value: errorDocument404Contents
      }
    ]
  }
}

resource cdnProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: 'resume-cdn-profile'
  location: 'centralus'
  sku: {
    name: 'Standard_Microsoft'
  }
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2023-05-01' = {
  name: 'resume-endpoint'
  parent: cdnProfile
  location: 'centralus'
  properties: {
    origins: [
      {
        name: 'storageOrigin'
        properties: {
          hostName: '${storageAcctName}.z13.web.core.${environment().suffixes.storage}'
        }
      }
    ]
    originHostHeader: '${storageAcctName}.z13.web.core.${environment().suffixes.storage}'
  }
}

resource cdnCustomDomain 'Microsoft.Cdn/profiles/endpoints/customDomains@2023-05-01' = {
  name: '${cdnProfile.name}/${cdnEndpoint.name}/resume-domain'
  properties: {
    hostName: 'resume.chase-meyer.space'
  }
}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: 'resume-cosmos-db'
  location: 'centralus'
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Eventual'
    }
    locations: [
      {
        locationName: 'centralus'
        failoverPriority: 0
      }
      {
        locationName: 'westus3'
        failoverPriority: 1
      }
    ]
    capabilities: [
      {
        name: 'EnableTable'
      }
      {
        name: 'EnableServerless'
      }
    ]
    databaseAccountOfferType: 'Standard'
  }
}

resource cosmosTable 'Microsoft.DocumentDB/databaseAccounts/tables@2023-04-15' = {
  name: 'resume-cosmos-table'
  parent: cosmosDbAccount
  properties: {
    resource: {
      id: 'resume-cosmos-table'
    }
  }
}

resource servicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'service-plan-resume'
  location: 'centralus'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'application-insights-resume'
  location: 'centralus'
  kind: 'other'
  properties: {
    Application_Type: 'other'
    RetentionInDays: 30
  }
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: 'chase-meyer-resume-api'
  location: 'centralus'
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: servicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'COSMOS_DB_ENDPOINT'
          value: cosmosDbEndpoint
        }
        {
          name: 'COSMOS_DB_KEY'
          value: cosmosDbKey
        }
        {
          name: 'API_KEY'
          value: apiKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: storageAccount.properties.primaryEndpoints.blob
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
      linuxFxVersion: 'Python|3.11'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [
    cosmosDbAccount
  ]
}
