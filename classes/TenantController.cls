/**
 * Endpoints for Tenant management.
 * assignPropertyToTenant is called by the propertyTenantAssign LWC.
 */
public with sharing class TenantController {

    @AuraEnabled
    public static Id assignPropertyToTenant(Id propertyId, Id tenantId) {
        if (propertyId == null || tenantId == null) {
            throw new AuraHandledException('Property and Tenant are required.');
        }
        Property_Tenant__c link = new Property_Tenant__c(
            Property__c = propertyId,
            Tenant__c = tenantId
        );
        insert link;
        return link.Id;
    }
}