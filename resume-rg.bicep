param storageAcctName string
param cosmosDbEndpoint string
param cosmosDbKey string
param apiKey string

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAcctName
  location: 'centralus'
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    staticWebsite: {
      indexDocument: 'Resume.html'
      error404Document: '404.html'
    }
    allowBlobPublicAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
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
  profileName: cdnProfile.name
  location: 'centralus'
  properties: {
    origins: [
      {
        name: 'storageOrigin'
        hostName: '${storageAcctName}.z13.web.core.windows.net'
      }
    ]
    originHostHeader: '${storageAcctName}.z13.web.core.windows.net'
  }
}

resource cdnCustomDomain 'Microsoft.Cdn/profiles/endpoints/customDomains@2023-05-01' = {
  name: 'resume-domain'
  endpointName: cdnEndpoint.name
  profileName: cdnProfile.name
  properties: {
    hostName: 'resume.chase-meyer.space'
    customHttpsConfiguration: {
      certificateSource: 'CdnManagedCertificate'
      protocolType: 'ServerNameIndication'
      minimumTlsVersion: 'TLS12'
    }
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

resource cosmosTable 'Microsoft.DocumentDB/databaseAccounts/apis/tables@2023-04-15' = {
  name: 'resume-cosmos-table'
  parent: cosmosDbAccount
  properties: {}
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
      ]
      linuxFxVersion: 'Python|3.11'
      applicationInsightsKey: appInsights.properties.InstrumentationKey
      applicationInsightsConnectionString: appInsights.properties.ConnectionString
    }
  }
}
