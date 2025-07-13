param dnsZoneName string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: dnsZoneName
}

resource resumeCname 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: 'resume'
  zoneName: dnsZone.name
  properties: {
    TTL: 3600
    CNAMERecord: {
      cname: 'your-cdn-endpoint.azureedge.net'
    }
  }
}

resource functionCname 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: 'resume-functions'
  zoneName: dnsZone.name
  properties: {
    TTL: 3600
    CNAMERecord: {
      cname: 'your-function-app.azurewebsites.net'
    }
  }
}

resource functionTxt 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  name: 'asuid.resume-functions'
  zoneName: dnsZone.name
  properties: {
    TTL: 3600
    TXTRecords: [
      {
        value: ['FEBFBCB5250DFBF9BB75D782499872A15EF7126A1D096F4A949E4E1490BDA687']
      }
    ]
  }
}
