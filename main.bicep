resource resumeRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'resume-resources'
  location: 'centralus'
}

resource domRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'domain-resources'
  location: 'centralus'
}
