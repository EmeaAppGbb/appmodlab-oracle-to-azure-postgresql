// ---------------------------------------------------------------------------
// Azure Database for PostgreSQL Flexible Server + Database Migration Service
// SkyReward Airlines Loyalty Program — Oracle-to-PostgreSQL Migration
// ---------------------------------------------------------------------------

@description('Azure region for all resources.')
param location string

@description('PostgreSQL administrator login name.')
param administratorLogin string

@secure()
@description('PostgreSQL administrator password.')
param administratorPassword string

@description('PostgreSQL Flexible Server SKU name.')
param skuName string

@description('PostgreSQL Flexible Server SKU tier.')
@allowed(['Burstable', 'GeneralPurpose', 'MemoryOptimized'])
param skuTier string

@description('PostgreSQL major version.')
@allowed(['14', '15', '16'])
param postgresqlVersion string

@description('Storage size in GB for the PostgreSQL server.')
param storageSizeGB int

@description('Name of the application database to create.')
param databaseName string

@description('Client IP address to allow through the firewall (for local development).')
param clientIpAddress string

@description('Tags to apply to all resources.')
param tags object = {}

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------
var serverName = 'psql-skyreward-${uniqueString(resourceGroup().id)}'
var dmsName = 'dms-skyreward-${uniqueString(resourceGroup().id)}'

// PostgreSQL extensions required by the SkyReward schema migration
var requiredExtensions = [
  'pg_cron'
  'pgmq'
  'uuid-ossp'
  'pg_trgm'
]

// ---------------------------------------------------------------------------
// PostgreSQL Flexible Server
// ---------------------------------------------------------------------------
resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    version: postgresqlVersion
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    storage: {
      storageSizeGB: storageSizeGB
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

// ---------------------------------------------------------------------------
// PostgreSQL Server Configuration — enable required extensions
// ---------------------------------------------------------------------------
resource extensionsConfig 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-12-01-preview' = {
  parent: postgresqlServer
  name: 'azure.extensions'
  properties: {
    value: join(requiredExtensions, ',')
    source: 'user-override'
  }
}

resource sharedPreloadLibraries 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-12-01-preview' = {
  parent: postgresqlServer
  name: 'shared_preload_libraries'
  properties: {
    value: 'pg_cron,pg_stat_statements'
    source: 'user-override'
  }
}

// ---------------------------------------------------------------------------
// Application Database
// ---------------------------------------------------------------------------
resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: postgresqlServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// ---------------------------------------------------------------------------
// Firewall Rules
// ---------------------------------------------------------------------------

// Allow Azure services (e.g., DMS) to reach the server
resource firewallAllowAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = {
  parent: postgresqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Allow the developer's client IP for local development
resource firewallAllowClient 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = {
  parent: postgresqlServer
  name: 'AllowClientIP'
  properties: {
    startIpAddress: clientIpAddress
    endIpAddress: clientIpAddress
  }
}

// ---------------------------------------------------------------------------
// Azure Database Migration Service (Classic)
// ---------------------------------------------------------------------------
resource dms 'Microsoft.DataMigration/services@2022-03-30-preview' = {
  name: dmsName
  location: location
  tags: tags
  sku: {
    name: 'Standard_1vCores'
    tier: 'Standard'
    size: '1 vCores'
  }
  properties: {
    virtualSubnetId: '' // Provide a subnet ID if using VNet-integrated DMS
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output serverFqdn string = postgresqlServer.properties.fullyQualifiedDomainName
output serverName string = postgresqlServer.name
output databaseName string = database.name
output dmsName string = dms.name
